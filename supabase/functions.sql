-- 용도: Postgres 함수(RPC). 입맛 유사도 계산 등. 프론트에서 supabase.rpc() 로 호출한다.
-- 규칙: 이 파일을 바꾸면 docs/erd.md 와 src/types/database.types.ts(npm run gen:types)도 같은 PR 에서 갱신한다.
--
-- 실행: schema.sql(또는 migrations/001_brand_structure.sql) → policies.sql 적용 후, 이 파일을 SQL Editor 에서 통째로 실행한다. 재실행 가능.
--       그 다음 seed_reference.sql(기준 데이터)을 실행한다.
--       실행 후 `npm run gen:types` 로 타입을 갱신한다.
--       반환 컬럼(returns table)을 바꾼 함수는 create or replace 로 덮어쓸 수 없으므로, 아래 "반환 컬럼이 바뀐 함수 정리" 블록이 먼저 drop 한다.
--
-- ---------------------------------------------------------------------
-- 조정 가능한 상수 (모두 calc_setting() 한 곳에서 바꾼다)
--   min_common         3    두 사용자의 유사도를 계산하려면 필요한 최소 공통 평가 메뉴 수 (미만이면 유사도 null)
--   mate_similarity    0.7  취향 메이트 / 협업 점수 이웃으로 인정하는 유사도 기준
--   collab_min_reviews 5    내 평가 수가 이 값 이상일 때부터 협업 점수를 섞는다 (미만이면 입맛 비율 × 메뉴 태그만 사용)
--   collab_weight      5    일치도 = (협업 점수 × collab_weight + 콘텐츠 점수 × content_weight) / (두 가중치 합)
--   content_weight     5    협업:콘텐츠 = 5:5
--
-- 계산식 요약
--   콘텐츠 점수  = 내 입맛 비율(ratio) 중 메뉴의 맛 태그에 포함된 것의 합 (0~100)
--   유사도       = 1 - (공통 평가 메뉴의 평균 |별점 차이| / 4)
--   협업 점수    = 유사도 기준 이상인 이웃들의 별점을 유사도로 가중평균한 값 → (예측 별점 - 1) / 4 × 100
--
-- 권한 정책
--   * 화면용 RPC(get_*, save_onboarding, update_my_allergens, update_my_tastes, upsert_review, delete_review): 로그인 사용자(authenticated)만 실행. anon 불가.
--   * 내부 함수(calc_*, 문자열 helper): 임의의 사용자 id 를 받으므로 anon/authenticated 모두 실행 불가.
--     화면용 RPC 가 security definer(owner 권한)로 실행되어 내부 함수를 호출한다.
--   * 모든 함수는 auth.uid() 가 null 이면 예외를 던진다. security definer 함수는 set search_path = '' 이므로 모든 객체에 public. 접두어를 쓴다.
-- ---------------------------------------------------------------------

-- =====================================================================
-- 1. 내부 함수
-- =====================================================================

-- 상수 조회 (위 "조정 가능한 상수"의 유일한 정의 위치)
create or replace function public.calc_setting(p_key text)
returns numeric
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_value numeric;
begin
  if auth.uid() is null then
    raise exception '로그인이 필요합니다.';
  end if;

  v_value := case p_key
    when 'min_common'         then 3
    when 'mate_similarity'    then 0.7
    when 'collab_min_reviews' then 5
    when 'collab_weight'      then 5
    when 'content_weight'     then 5
  end;

  if v_value is null then
    raise exception '알 수 없는 설정 값이에요: %', p_key;
  end if;
  return v_value;
end;
$$;

-- 맛 코드 → 짧은 이름. 맛 목록이 임시라 바뀔 수 있으므로 매핑은 이 함수에만 둔다.
create or replace function public.taste_short_name(p_code text, p_name text)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception '로그인이 필요합니다.';
  end if;

  return case p_code
    when 'spicy'  then '매콤'
    when 'sweet'  then '달콤'
    when 'salty'  then '짭짤'
    when 'sour'   then '새콤'
    when 'nutty'  then '고소'
    when 'mild'   then '담백'
    when 'rich'   then '느끼'
    when 'bitter' then '쌉싸름'
    when 'umami'  then '감칠'
    else regexp_replace(p_name, '함$', '')   -- 목록에 없으면 끝의 '함' 제거
  end;
end;
$$;

-- 마지막 글자가 한글이고 받침이 있으면 true
create or replace function public.has_batchim(p_text text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_code int;
begin
  if auth.uid() is null then
    raise exception '로그인이 필요합니다.';
  end if;

  if p_text is null or p_text = '' then
    return false;
  end if;

  v_code := ascii(right(p_text, 1));          -- UTF8 에서는 유니코드 코드포인트
  if v_code < 44032 or v_code > 55203 then     -- 한글 음절 범위(가~힣) 밖
    return false;
  end if;
  return (v_code - 44032) % 28 <> 0;
end;
$$;

-- p_text 뒤에 받침 여부에 맞는 조사를 붙여 반환. p_pair: '을/를', '과/와', '이/가'
create or replace function public.josa(p_text text, p_pair text)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_batchim boolean;
begin
  if auth.uid() is null then
    raise exception '로그인이 필요합니다.';
  end if;

  if p_pair is null or p_pair not in ('을/를', '과/와', '이/가') then
    raise exception '지원하지 않는 조사예요: %', p_pair;
  end if;

  v_batchim := public.has_batchim(p_text);
  return p_text || case p_pair
    when '을/를' then case when v_batchim then '을' else '를' end
    when '과/와' then case when v_batchim then '과' else '와' end
    when '이/가' then case when v_batchim then '이' else '가' end
  end;
end;
$$;

-- 콘텐츠 점수: 사용자의 맛 비율 중 메뉴 맛 태그에 포함된 것의 합 (메뉴 태그가 없으면 0)
create or replace function public.calc_content_match(p_user uuid, p_menu bigint)
returns int
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception '로그인이 필요합니다.';
  end if;

  return coalesce((
    select sum(utp.ratio)
    from public.user_taste_preferences utp
    join public.menu_taste_tags mtt on mtt.taste_tag_id = utp.taste_tag_id
    where utp.user_id = p_user
      and mtt.menu_id = p_menu
  ), 0)::int;
end;
$$;

-- 두 사용자의 유사도: 공통 평가 메뉴가 min_common 개 미만이면 null, 아니면 1 - (평균 |별점 차이| / 4)
create or replace function public.calc_user_similarity(p_a uuid, p_b uuid)
returns numeric
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_common int;
  v_avg_diff numeric;
begin
  if auth.uid() is null then
    raise exception '로그인이 필요합니다.';
  end if;

  select count(*), avg(abs(ra.rating - rb.rating))
  into v_common, v_avg_diff
  from public.reviews ra
  join public.reviews rb on rb.menu_id = ra.menu_id
  where ra.user_id = p_a
    and rb.user_id = p_b;

  if v_common < public.calc_setting('min_common') then
    return null;
  end if;
  return 1 - (v_avg_diff / 4);
end;
$$;

-- 메뉴 일치도 상세: (일치도 %, 이웃 수, 이웃 별점 평균)
--   내 평가 수 < collab_min_reviews 이거나 이웃이 없으면 콘텐츠 점수만 사용 (neighbor_count 0)
create or replace function public.calc_menu_match_detail(p_user uuid, p_menu bigint)
returns table (match int, neighbor_count int, neighbor_avg numeric)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_content int;
  v_my_reviews int;
  v_n int;
  v_avg numeric;
  v_pred numeric;
  v_collab numeric;
  v_w_collab numeric;
  v_w_content numeric;
begin
  if auth.uid() is null then
    raise exception '로그인이 필요합니다.';
  end if;

  v_content := public.calc_content_match(p_user, p_menu);

  select count(*) into v_my_reviews
  from public.reviews r
  where r.user_id = p_user;

  if v_my_reviews < public.calc_setting('collab_min_reviews') then
    return query select v_content, 0, null::numeric;
    return;
  end if;

  -- 유사도 기준 이상이면서 이 메뉴를 평가한 다른 사용자들
  select count(*),
         round(avg(r.rating), 1),
         sum(s.sim * r.rating) / sum(s.sim)      -- 유사도 가중평균 = 예측 별점
  into v_n, v_avg, v_pred
  from public.reviews r
  cross join lateral (select public.calc_user_similarity(p_user, r.user_id) as sim) s
  where r.menu_id = p_menu
    and r.user_id <> p_user
    and s.sim >= public.calc_setting('mate_similarity');

  if v_n = 0 then
    return query select v_content, 0, null::numeric;
    return;
  end if;

  v_collab := (v_pred - 1) / 4 * 100;
  v_w_collab := public.calc_setting('collab_weight');
  v_w_content := public.calc_setting('content_weight');

  return query select
    round((v_collab * v_w_collab + v_content * v_w_content) / (v_w_collab + v_w_content))::int,
    v_n,
    v_avg;
end;
$$;

-- 메뉴 일치도(%)만 반환하는 래퍼
create or replace function public.calc_menu_match(p_user uuid, p_menu bigint)
returns int
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception '로그인이 필요합니다.';
  end if;

  return (select d.match from public.calc_menu_match_detail(p_user, p_menu) d);
end;
$$;

-- 추천 이유 문장
--   이웃이 있으면 "입맛이 비슷한 n명이 평균 x점을 줬어요", 없으면 "{가장 높은 비율의 맛}을/를 좋아하는 입맛과 잘 맞아요"
create or replace function public.calc_menu_reason(p_user uuid, p_menu bigint)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_n int;
  v_avg numeric;
  v_top text;
begin
  if auth.uid() is null then
    raise exception '로그인이 필요합니다.';
  end if;

  select d.neighbor_count, d.neighbor_avg
  into v_n, v_avg
  from public.calc_menu_match_detail(p_user, p_menu) d;

  if v_n >= 1 then
    return format('입맛이 비슷한 %s명이 평균 %s점을 줬어요', v_n, v_avg);
  end if;

  select tt.name into v_top
  from public.user_taste_preferences utp
  join public.taste_tags tt on tt.id = utp.taste_tag_id
  where utp.user_id = p_user
  order by utp.ratio desc, tt.id
  limit 1;

  if v_top is null then
    return '입맛을 설정하면 추천 이유를 알려드려요';
  end if;
  return public.josa(v_top, '을/를') || ' 좋아하는 입맛과 잘 맞아요';
end;
$$;

-- 입맛 유형 이름·설명 (비율 상위 2개 기준). 맛이 없으면 둘 다 null
--   이름: 2개 이상 → 짧은 이름 이어 붙이기(매콤달콤), 1개 → "{짧은 이름}파"(매콤파)
create or replace function public.calc_taste_type(p_user uuid)
returns table (type_name text, type_desc text)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_names text[];
  v_shorts text[];
  v_count int;
begin
  if auth.uid() is null then
    raise exception '로그인이 필요합니다.';
  end if;

  select array_agg(tt.name order by utp.ratio desc, tt.id),
         array_agg(public.taste_short_name(tt.code, tt.name) order by utp.ratio desc, tt.id)
  into v_names, v_shorts
  from public.user_taste_preferences utp
  join public.taste_tags tt on tt.id = utp.taste_tag_id
  where utp.user_id = p_user;

  v_count := coalesce(array_length(v_names, 1), 0);

  if v_count = 0 then
    return query select null::text, null::text;
  elsif v_count = 1 then
    return query select
      v_shorts[1] || '파',
      public.josa(v_names[1], '을/를') || ' 가장 좋아하는 입맛이에요';
  elsif v_names[2] like '%함' then
    return query select
      v_shorts[1] || v_shorts[2],
      v_names[1] || ' 속 ' || regexp_replace(v_names[2], '함$', '한') || ' 반전을 좋아해요';
  else
    return query select
      v_shorts[1] || v_shorts[2],
      public.josa(v_names[1], '과/와') || ' ' || public.josa(v_names[2], '을/를') || ' 좋아하는 입맛이에요';
  end if;
end;
$$;

-- 내부 함수는 어떤 클라이언트도 직접 호출하지 못하게 막는다 (Supabase 는 새 함수에 anon/authenticated 실행 권한을 기본 부여)
revoke all on function public.calc_setting(text)                    from public, anon, authenticated;
revoke all on function public.taste_short_name(text, text)          from public, anon, authenticated;
revoke all on function public.has_batchim(text)                     from public, anon, authenticated;
revoke all on function public.josa(text, text)                      from public, anon, authenticated;
revoke all on function public.calc_content_match(uuid, bigint)      from public, anon, authenticated;
revoke all on function public.calc_user_similarity(uuid, uuid)      from public, anon, authenticated;
revoke all on function public.calc_menu_match_detail(uuid, bigint)  from public, anon, authenticated;
revoke all on function public.calc_menu_match(uuid, bigint)         from public, anon, authenticated;
revoke all on function public.calc_menu_reason(uuid, bigint)        from public, anon, authenticated;
revoke all on function public.calc_taste_type(uuid)                 from public, anon, authenticated;

-- =====================================================================
-- 반환 컬럼이 바뀐 함수 정리 (브랜드 구조 전환). 재실행해도 안전하다 — 아래에서 모두 다시 만들고 권한도 다시 준다.
-- =====================================================================
drop function if exists public.get_restaurants(text, int, text, int);
drop function if exists public.get_recommended_menus(text, int);
drop function if exists public.get_restaurant_detail(bigint);
drop function if exists public.get_restaurant_menus(bigint);
drop function if exists public.get_allergy_menus(bigint);
drop function if exists public.get_my_reviews();

-- =====================================================================
-- 2. 화면용 RPC
-- =====================================================================

-- 온보딩 저장: 입맛(1~3개, 비율 합계 100), 알레르기를 교체 저장하고 지역·온보딩 완료를 갱신
--   p_tastes 예: [{"taste_tag_id": 1, "ratio": 65}, {"taste_tag_id": 2, "ratio": 35}]
create or replace function public.save_onboarding(p_region text, p_tastes jsonb, p_allergens int[])
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_n int;
  v_distinct int;
  v_sum int;
  v_invalid int;
begin
  if v_uid is null then
    raise exception '로그인이 필요합니다.';
  end if;

  if p_region is null or not exists (select 1 from public.restaurants r where r.region = p_region) then
    raise exception '선택할 수 없는 지역이에요.';
  end if;

  if p_tastes is null or jsonb_typeof(p_tastes) <> 'array' then
    raise exception '입맛 정보 형식이 올바르지 않아요.';
  end if;

  v_n := jsonb_array_length(p_tastes);
  if v_n < 1 or v_n > 3 then
    raise exception '맛은 1~3개까지 선택할 수 있어요.';
  end if;

  select count(distinct x.taste_tag_id),
         coalesce(sum(x.ratio), 0),
         count(*) filter (where x.taste_tag_id is null or x.ratio is null or x.ratio < 1 or x.ratio > 100)
  into v_distinct, v_sum, v_invalid
  from jsonb_to_recordset(p_tastes) as x(taste_tag_id int, ratio int);

  if v_invalid > 0 then
    raise exception '각 맛의 비율은 1~100 사이로 입력해주세요.';
  end if;
  if v_distinct <> v_n then
    raise exception '같은 맛을 중복해서 선택할 수 없어요.';
  end if;
  if v_sum <> 100 then
    raise exception '맛 비율의 합계는 정확히 100이어야 해요.';
  end if;
  if exists (
    select 1
    from jsonb_to_recordset(p_tastes) as x(taste_tag_id int, ratio int)
    where not exists (select 1 from public.taste_tags tt where tt.id = x.taste_tag_id)
  ) then
    raise exception '존재하지 않는 맛이에요.';
  end if;
  if exists (
    select 1
    from (select distinct unnest(p_allergens) as allergen_id) u
    where not exists (select 1 from public.allergens a where a.id = u.allergen_id)
  ) then
    raise exception '존재하지 않는 알레르기 항목이에요.';
  end if;

  -- 교체 저장 (함수 전체가 한 트랜잭션이므로 중간에 실패하면 모두 되돌아간다)
  delete from public.user_taste_preferences where user_id = v_uid;
  insert into public.user_taste_preferences (user_id, taste_tag_id, ratio)
  select v_uid, x.taste_tag_id, x.ratio
  from jsonb_to_recordset(p_tastes) as x(taste_tag_id int, ratio int);

  delete from public.user_allergens where user_id = v_uid;
  insert into public.user_allergens (user_id, allergen_id)
  select distinct v_uid, u.allergen_id
  from unnest(coalesce(p_allergens, '{}'::int[])) as u(allergen_id);

  update public.profiles
  set region = p_region, onboarding_done = true
  where id = v_uid;
  if not found then
    raise exception '프로필을 찾을 수 없어요.';
  end if;
end;
$$;

-- 내 알레르기 교체 저장 (마이페이지 알레르기 수정). 빈 배열이면 모두 해제한다.
--   null·중복은 무시하고, 존재하지 않는 알레르기 id 가 있으면 예외. 함수 전체가 한 트랜잭션이라 삭제 후 삽입 중 실패하면 되돌아간다.
create or replace function public.update_my_allergens(p_allergen_ids int[])
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception '로그인이 필요합니다.';
  end if;

  if exists (
    select 1
    from (select distinct unnest(coalesce(p_allergen_ids, '{}'::int[])) as allergen_id) u
    where u.allergen_id is not null
      and not exists (select 1 from public.allergens a where a.id = u.allergen_id)
  ) then
    raise exception '존재하지 않는 알레르기 항목이에요.';
  end if;

  delete from public.user_allergens where user_id = v_uid;
  insert into public.user_allergens (user_id, allergen_id)
  select distinct v_uid, u.allergen_id
  from unnest(coalesce(p_allergen_ids, '{}'::int[])) as u(allergen_id)
  where u.allergen_id is not null;
end;
$$;

-- 내 입맛(맛 선택 + 비율) 교체 저장 (마이페이지 입맛 수정). 검증 규칙은 save_onboarding 의 맛 검증과 같다.
--   p_taste_ids 와 p_ratios 는 같은 순서의 짝이다. 예: p_taste_ids = {1, 2}, p_ratios = {65, 35}
--   바꾸는 것은 user_taste_preferences 의 내 행뿐이다 (region·onboarding_done·알레르기는 건드리지 않는다).
--   함수 전체가 한 트랜잭션이라 삭제 후 삽입 중 실패하면 되돌아간다.
create or replace function public.update_my_tastes(p_taste_ids int[], p_ratios int[])
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_n int;
  v_distinct int;
  v_sum int;
  v_invalid int;
begin
  if v_uid is null then
    raise exception '로그인이 필요합니다.';
  end if;

  if p_taste_ids is null or p_ratios is null then
    raise exception '입맛 정보 형식이 올바르지 않아요.';
  end if;

  v_n := coalesce(array_length(p_taste_ids, 1), 0);
  if v_n < 1 or v_n > 3 then
    raise exception '맛은 1~3개까지 선택할 수 있어요.';
  end if;
  if coalesce(array_length(p_ratios, 1), 0) <> v_n then
    raise exception '맛과 비율의 개수가 달라요.';
  end if;

  select count(distinct x.taste_tag_id),
         coalesce(sum(x.ratio), 0),
         count(*) filter (where x.taste_tag_id is null or x.ratio is null or x.ratio < 1 or x.ratio > 100)
  into v_distinct, v_sum, v_invalid
  from unnest(p_taste_ids, p_ratios) as x(taste_tag_id, ratio);

  if v_invalid > 0 then
    raise exception '각 맛의 비율은 1~100 사이로 입력해주세요.';
  end if;
  if v_distinct <> v_n then
    raise exception '같은 맛을 중복해서 선택할 수 없어요.';
  end if;
  if v_sum <> 100 then
    raise exception '맛 비율의 합계는 정확히 100이어야 해요.';
  end if;
  if exists (
    select 1
    from unnest(p_taste_ids) as x(taste_tag_id)
    where not exists (select 1 from public.taste_tags tt where tt.id = x.taste_tag_id)
  ) then
    raise exception '존재하지 않는 맛이에요.';
  end if;

  delete from public.user_taste_preferences where user_id = v_uid;
  insert into public.user_taste_preferences (user_id, taste_tag_id, ratio)
  select v_uid, x.taste_tag_id, x.ratio
  from unnest(p_taste_ids, p_ratios) as x(taste_tag_id, ratio);
end;
$$;

-- 가게 목록: 지역(필수)·카테고리·검색어(지점명·브랜드명·메뉴명) 필터, 취향 일치도 내림차순
--   평점·일치도·맛 태그는 소속 브랜드 기준이다 (같은 브랜드의 지점은 같은 값). 계산은 지점이 아니라 브랜드 단위로 한 번만 한다.
--   카테고리 필터는 brands.category_id. has_official_allergen: 브랜드에 verified/official_extract 메뉴가 있는지
create or replace function public.get_restaurants(
  p_region text,
  p_category_id int default null,
  p_query text default null,
  p_limit int default 20
)
returns table (
  restaurant_id bigint,
  name text,
  region text,
  image_url text,
  avg_rating numeric,
  review_count bigint,
  taste_tags text[],
  is_saved boolean,
  match_percent int,
  brand_id bigint,
  brand_name text,
  is_franchise boolean,
  has_official_allergen boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_uid uuid := auth.uid();
  v_pattern text;
  v_limit int;
begin
  if v_uid is null then
    raise exception '로그인이 필요합니다.';
  end if;

  v_limit := least(greatest(coalesce(p_limit, 20), 1), 100);

  -- 검색어의 LIKE 와일드카드(\, %, _)를 이스케이프한다
  if p_query is not null and btrim(p_query) <> '' then
    v_pattern := '%' || replace(replace(replace(btrim(p_query), '\', '\\'), '%', '\%'), '_', '\_') || '%';
  end if;

  return query
  with base as (
    select r.id as restaurant_id,
           r.name as name,
           r.region as region,
           r.image_url as image_url,
           b.id as brand_id,
           b.name as brand_name,
           b.is_franchise as is_franchise,
           b.image_url as brand_image_url
    from public.restaurants r
    join public.brands b on b.id = r.brand_id
    where (p_region is null or r.region = p_region)
      and (p_category_id is null or b.category_id = p_category_id)
      and (
        v_pattern is null
        or r.name ilike v_pattern escape '\'
        or b.name ilike v_pattern escape '\'
        or exists (
          select 1 from public.menus m
          where m.brand_id = b.id and m.name ilike v_pattern escape '\'
        )
      )
  ),
  brand_ids as (
    select distinct bb.brand_id from base bb
  ),
  brand_match as (
    select m.brand_id as brand_id, round(avg(d.match))::int as match_percent
    from public.menus m
    join brand_ids bi on bi.brand_id = m.brand_id
    cross join lateral public.calc_menu_match_detail(v_uid, m.id) d
    group by m.brand_id
  ),
  brand_info as (
    select bi.brand_id as brand_id,
           bs.avg_rating as avg_rating,
           coalesce(bs.review_count, 0) as review_count,
           coalesce((
             select array_agg(tt.name order by tt.id)
             from public.taste_tags tt
             where tt.id in (
               select mtt.taste_tag_id
               from public.menus m
               join public.menu_taste_tags mtt on mtt.menu_id = m.id
               where m.brand_id = bi.brand_id
             )
           ), '{}'::text[]) as taste_tags,
           exists (
             select 1 from public.menus m
             where m.brand_id = bi.brand_id and m.allergen_status in ('verified', 'official_extract')
           ) as has_official_allergen
    from brand_ids bi
    left join public.brand_stats bs on bs.brand_id = bi.brand_id
  )
  select x.restaurant_id, x.name, x.region, x.image_url, x.avg_rating, x.review_count,
         x.taste_tags, x.is_saved, x.match_percent,
         x.brand_id, x.brand_name, x.is_franchise, x.has_official_allergen
  from (
    select bb.restaurant_id as restaurant_id,
           bb.name as name,
           bb.region as region,
           coalesce(bb.image_url, bb.brand_image_url) as image_url,
           bi.avg_rating as avg_rating,
           bi.review_count as review_count,
           bi.taste_tags as taste_tags,
           exists (
             select 1 from public.saved_restaurants sr
             where sr.user_id = v_uid and sr.restaurant_id = bb.restaurant_id
           ) as is_saved,
           coalesce(bm.match_percent, 0) as match_percent,
           bb.brand_id as brand_id,
           bb.brand_name as brand_name,
           bb.is_franchise as is_franchise,
           bi.has_official_allergen as has_official_allergen
    from base bb
    join brand_info bi on bi.brand_id = bb.brand_id
    left join brand_match bm on bm.brand_id = bb.brand_id
  ) x
  order by x.match_percent desc, x.avg_rating desc nulls last, x.restaurant_id
  limit v_limit;
end;
$$;

-- 오늘의 추천 메뉴
--   * 메뉴는 브랜드 소속이라 브랜드당 한 번만 나온다. restaurant_id 는 링크용으로, 해당 지역의 대표 지점(최소 id)을 돌려준다.
--   * 이미 평가한 메뉴는 제외한다.
--   * 알레르기 안전 정책 (이 함수의 상수 같은 규칙):
--       - 사용자가 알레르기를 1개 이상 등록했으면: 내 알레르기가 겹치는 메뉴(level 무관)를 제외하고,
--         allergen_status 가 unknown/estimated(= 공식 확인이 안 된 메뉴)인 메뉴도 제외한다. (안전 우선)
--         → 남는 것은 verified/official_extract 이면서 겹치지 않는 메뉴뿐이다.
--       - 등록한 알레르기가 없으면: allergen_status 와 무관하게 포함한다.
create or replace function public.get_recommended_menus(p_region text, p_limit int default 6)
returns table (
  menu_id bigint,
  menu_name text,
  restaurant_id bigint,
  restaurant_name text,
  region text,
  image_url text,
  avg_rating numeric,
  match_percent int,
  reason text,
  brand_name text,
  allergen_status public.allergen_status
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_uid uuid := auth.uid();
  v_limit int;
  v_has_allergy boolean;
begin
  if v_uid is null then
    raise exception '로그인이 필요합니다.';
  end if;

  v_limit := least(greatest(coalesce(p_limit, 6), 1), 100);
  v_has_allergy := exists (select 1 from public.user_allergens ua where ua.user_id = v_uid);

  return query
  select x.menu_id, x.menu_name, x.restaurant_id, x.restaurant_name, x.region, x.image_url,
         x.avg_rating, x.match_percent,
         public.calc_menu_reason(v_uid, x.menu_id) as reason,
         x.brand_name, x.allergen_status
  from (
    select m.id as menu_id,
           m.name as menu_name,
           r.id as restaurant_id,
           r.name as restaurant_name,
           r.region as region,
           coalesce(m.image_url, b.image_url, r.image_url) as image_url,
           ms.avg_rating as avg_rating,
           d.match as match_percent,
           b.name as brand_name,
           m.allergen_status as allergen_status
    from (
      select rr.brand_id as brand_id, min(rr.id) as restaurant_id
      from public.restaurants rr
      where p_region is null or rr.region = p_region
      group by rr.brand_id
    ) rep
    join public.restaurants r on r.id = rep.restaurant_id
    join public.brands b on b.id = rep.brand_id
    join public.menus m on m.brand_id = b.id
    left join public.menu_stats ms on ms.menu_id = m.id
    cross join lateral public.calc_menu_match_detail(v_uid, m.id) d
    where not exists (
        select 1 from public.reviews rv
        where rv.user_id = v_uid and rv.menu_id = m.id
      )
      and not exists (
        select 1
        from public.menu_allergens ma
        join public.user_allergens ua on ua.allergen_id = ma.allergen_id
        where ma.menu_id = m.id and ua.user_id = v_uid
      )
      and (not v_has_allergy or m.allergen_status in ('verified', 'official_extract'))
  ) x
  order by x.match_percent desc, x.avg_rating desc nulls last, x.menu_id
  limit v_limit;
end;
$$;

-- 가게(지점) 상세: 평점·일치도는 소속 브랜드 메뉴 기준(일치도는 메뉴 일치도 평균), 추천 이유는 일치도가 가장 높은 메뉴의 이유. 없는 id 면 0행
create or replace function public.get_restaurant_detail(p_restaurant_id bigint)
returns table (
  restaurant_id bigint,
  name text,
  address text,
  region text,
  phone text,
  image_url text,
  avg_rating numeric,
  review_count bigint,
  match_percent int,
  reason text,
  is_saved boolean,
  brand_id bigint,
  brand_name text,
  is_franchise boolean,
  shared_notice text,
  allergen_source_url text,
  allergen_data_date date
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception '로그인이 필요합니다.';
  end if;

  return query
  with menu_match as (
    select m.id as menu_id, d.match as menu_match
    from public.restaurants rr
    join public.menus m on m.brand_id = rr.brand_id
    cross join lateral public.calc_menu_match_detail(v_uid, m.id) d
    where rr.id = p_restaurant_id
  )
  select r.id,
         r.name,
         r.address,
         r.region,
         r.phone,
         coalesce(r.image_url, b.image_url),
         bs.avg_rating,
         coalesce(bs.review_count, 0),
         coalesce((select round(avg(mm.menu_match))::int from menu_match mm), 0),
         (
           select public.calc_menu_reason(v_uid, t.menu_id)
           from (select mm.menu_id from menu_match mm order by mm.menu_match desc, mm.menu_id limit 1) t
         ),
         exists (
           select 1 from public.saved_restaurants sr
           where sr.user_id = v_uid and sr.restaurant_id = r.id
         ),
         b.id,
         b.name,
         b.is_franchise,
         b.shared_notice,
         b.allergen_source_url,
         b.allergen_data_date
  from public.restaurants r
  join public.brands b on b.id = r.brand_id
  left join public.brand_stats bs on bs.brand_id = b.id
  where r.id = p_restaurant_id;
end;
$$;

-- 지점의 메뉴 목록 (메뉴별 평가 탭): 지점이 속한 브랜드의 메뉴, 일치도 내림차순
create or replace function public.get_restaurant_menus(p_restaurant_id bigint)
returns table (
  menu_id bigint,
  name text,
  description text,
  image_url text,
  taste_tags text[],
  avg_rating numeric,
  match_percent int,
  is_saved boolean,
  my_rating int,
  allergen_status public.allergen_status,
  allergen_source_url text,
  allergen_checked_at timestamptz,
  menu_source_name text,
  menu_source_url text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception '로그인이 필요합니다.';
  end if;

  return query
  select x.menu_id, x.name, x.description, x.image_url, x.taste_tags,
         x.avg_rating, x.match_percent, x.is_saved, x.my_rating,
         x.allergen_status, x.allergen_source_url, x.allergen_checked_at, x.menu_source_name, x.menu_source_url
  from (
    select m.id as menu_id,
           m.name as name,
           m.description as description,
           coalesce(m.image_url, b.image_url) as image_url,
           coalesce((
             select array_agg(tt.name order by tt.id)
             from public.menu_taste_tags mtt
             join public.taste_tags tt on tt.id = mtt.taste_tag_id
             where mtt.menu_id = m.id
           ), '{}'::text[]) as taste_tags,
           ms.avg_rating as avg_rating,
           d.match as match_percent,
           exists (
             select 1 from public.saved_menus sm
             where sm.user_id = v_uid and sm.menu_id = m.id
           ) as is_saved,
           (
             select rv.rating::int from public.reviews rv
             where rv.user_id = v_uid and rv.menu_id = m.id
           ) as my_rating,
           m.allergen_status as allergen_status,
           m.allergen_source_url as allergen_source_url,
           m.allergen_checked_at as allergen_checked_at,
           m.menu_source_name as menu_source_name,
           m.menu_source_url as menu_source_url
    from public.restaurants rr
    join public.brands b on b.id = rr.brand_id
    join public.menus m on m.brand_id = rr.brand_id
    left join public.menu_stats ms on ms.menu_id = m.id
    cross join lateral public.calc_menu_match_detail(v_uid, m.id) d
    where rr.id = p_restaurant_id
  ) x
  order by x.match_percent desc, x.menu_id;
end;
$$;

-- 알레르기 정보 탭 (지점이 속한 브랜드의 메뉴 기준)
--   kind = 'conflict': 내 알레르기 재료가 들어간 메뉴. allergens 예: [{"name": "계란", "level": "danger", "original_text": "난류"}]
--   kind = 'unknown' : 알레르기를 1개 이상 등록한 경우에 한해, 공식 확인이 안 된 메뉴(allergen_status 가 unknown/estimated)
--                      (겹치는 알레르기가 확인된 메뉴는 conflict 로만 나온다). allergens 는 빈 배열
--   정렬: danger 충돌 → caution 충돌 → unknown
create or replace function public.get_allergy_menus(p_restaurant_id bigint)
returns table (
  menu_id bigint,
  name text,
  image_url text,
  allergens jsonb,
  allergen_status public.allergen_status,
  kind text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_uid uuid := auth.uid();
  v_has_allergy boolean;
begin
  if v_uid is null then
    raise exception '로그인이 필요합니다.';
  end if;

  v_has_allergy := exists (select 1 from public.user_allergens ua where ua.user_id = v_uid);

  return query
  with conflicts as (
    select m.id as menu_id,
           m.name as name,
           coalesce(m.image_url, b.image_url) as image_url,
           jsonb_agg(
             jsonb_build_object('name', a.display_name, 'level', ma.level, 'original_text', ma.original_text)
             order by (ma.level = 'danger') desc, a.id
           ) as allergens,
           bool_or(ma.level = 'danger') as has_danger,
           m.allergen_status as allergen_status
    from public.restaurants rr
    join public.brands b on b.id = rr.brand_id
    join public.menus m on m.brand_id = rr.brand_id
    join public.menu_allergens ma on ma.menu_id = m.id
    join public.user_allergens ua on ua.allergen_id = ma.allergen_id and ua.user_id = v_uid
    join public.allergens a on a.id = ma.allergen_id
    where rr.id = p_restaurant_id
    group by m.id, m.name, b.image_url, m.image_url, m.allergen_status
  ),
  unknowns as (
    select m.id as menu_id,
           m.name as name,
           coalesce(m.image_url, b.image_url) as image_url,
           m.allergen_status as allergen_status
    from public.restaurants rr
    join public.brands b on b.id = rr.brand_id
    join public.menus m on m.brand_id = rr.brand_id
    where rr.id = p_restaurant_id
      and v_has_allergy
      and m.allergen_status in ('unknown', 'estimated')
      and not exists (select 1 from conflicts c where c.menu_id = m.id)
  )
  select u.menu_id, u.name, u.image_url, u.allergens, u.allergen_status, u.kind
  from (
    select c.menu_id, c.name, c.image_url, c.allergens, c.allergen_status,
           'conflict'::text as kind,
           case when c.has_danger then 0 else 1 end as sort_key
    from conflicts c
    union all
    select k.menu_id, k.name, k.image_url, '[]'::jsonb, k.allergen_status,
           'unknown'::text,
           2
    from unknowns k
  ) u
  order by u.sort_key, u.menu_id;
end;
$$;

-- 마이페이지 요약
--   taste_ratios 예: [{"name": "매콤함", "ratio": 60}, ...] (ratio 내림차순)
create or replace function public.get_my_summary()
returns table (
  nickname text,
  region text,
  taste_ratios jsonb,
  taste_type_name text,
  taste_type_desc text,
  saved_restaurant_count int,
  review_count int,
  mate_count int
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception '로그인이 필요합니다.';
  end if;

  return query
  select p.nickname,
         p.region,
         coalesce((
           select jsonb_agg(jsonb_build_object('name', tt.name, 'ratio', utp.ratio) order by utp.ratio desc, tt.id)
           from public.user_taste_preferences utp
           join public.taste_tags tt on tt.id = utp.taste_tag_id
           where utp.user_id = v_uid
         ), '[]'::jsonb),
         t.type_name,
         t.type_desc,
         (select count(*) from public.saved_restaurants sr where sr.user_id = v_uid)::int,
         (select count(*) from public.reviews rv where rv.user_id = v_uid)::int,
         (
           select count(*)
           from public.profiles o
           where o.id <> v_uid
             and public.calc_user_similarity(v_uid, o.id) >= public.calc_setting('mate_similarity')
         )::int
  from public.profiles p
  cross join lateral public.calc_taste_type(v_uid) t
  where p.id = v_uid;
end;
$$;

-- 취향 메이트 목록: 유사도 기준 이상인 다른 사용자. 닉네임·유형·유사도·공통 메뉴 수만 반환한다
create or replace function public.get_taste_mates(p_limit int default 20)
returns table (
  nickname text,
  taste_type_name text,
  similarity_percent int,
  common_menu_count int
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_uid uuid := auth.uid();
  v_limit int;
begin
  if v_uid is null then
    raise exception '로그인이 필요합니다.';
  end if;

  v_limit := least(greatest(coalesce(p_limit, 20), 1), 100);

  return query
  with mates as (
    select o.id as user_id,
           o.nickname as nickname,
           public.calc_user_similarity(v_uid, o.id) as sim
    from public.profiles o
    where o.id <> v_uid
  )
  select m.nickname,
         (select t.type_name from public.calc_taste_type(m.user_id) t),
         round(m.sim * 100)::int,
         (
           select count(*)
           from public.reviews ra
           join public.reviews rb on rb.menu_id = ra.menu_id and rb.user_id = m.user_id
           where ra.user_id = v_uid
         )::int
  from mates m
  where m.sim >= public.calc_setting('mate_similarity')
  order by m.sim desc, m.nickname
  limit v_limit;
end;
$$;

-- 내가 평가한 메뉴 목록 (최신순). taste_tags 는 내가 평가에 붙인 맛 태그
--   메뉴는 브랜드 소속이므로 brand_id, brand_name 을 함께 돌려준다.
--   restaurant_id/restaurant_name 은 링크용: 내 지역의 대표 지점(최소 id), 내 지역에 지점이 없으면 브랜드의 최소 id 지점.
--   브랜드에 지점이 하나도 없으면 restaurant_id 는 null, restaurant_name 은 브랜드 이름.
create or replace function public.get_my_reviews()
returns table (
  menu_id bigint,
  menu_name text,
  restaurant_id bigint,
  restaurant_name text,
  image_url text,
  rating int,
  taste_tags text[],
  created_at timestamptz,
  brand_id bigint,
  brand_name text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_uid uuid := auth.uid();
  v_region text;
begin
  if v_uid is null then
    raise exception '로그인이 필요합니다.';
  end if;

  select p.region into v_region from public.profiles p where p.id = v_uid;

  return query
  select m.id,
         m.name,
         rep.restaurant_id,
         coalesce(rep.restaurant_name, b.name),
         coalesce(m.image_url, b.image_url, rep.image_url),
         rv.rating::int,
         coalesce((
           select array_agg(tt.name order by tt.id)
           from public.review_taste_tags rtt
           join public.taste_tags tt on tt.id = rtt.taste_tag_id
           where rtt.review_id = rv.id
         ), '{}'::text[]),
         rv.created_at,
         b.id,
         b.name
  from public.reviews rv
  join public.menus m on m.id = rv.menu_id
  join public.brands b on b.id = m.brand_id
  left join lateral (
    select r.id as restaurant_id, r.name as restaurant_name, r.image_url as image_url
    from public.restaurants r
    where r.brand_id = b.id
    order by (r.region is not distinct from v_region) desc, r.id
    limit 1
  ) rep on true
  where rv.user_id = v_uid
  order by rv.created_at desc, rv.id desc;
end;
$$;

-- 지점이 있는 지역 목록 (지역 선택 시트용). 프론트가 restaurants 를 직접 읽어 중복 제거하던 방식(1000행 제한)을 대체한다.
create or replace function public.get_regions()
returns table (
  region text,
  sido text,
  sigungu text,
  restaurant_count bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
begin
  if auth.uid() is null then
    raise exception '로그인이 필요합니다.';
  end if;

  return query
  select r.region as region,
         min(r.sido) as sido,
         min(r.sigungu) as sigungu,
         count(*) as restaurant_count
  from public.restaurants r
  group by r.region
  order by r.region;
end;
$$;

-- 평가 저장(신규/수정): 별점 1~5, 맛 태그는 교체 저장. 저장된 review id 반환
create or replace function public.upsert_review(p_menu_id bigint, p_rating int, p_tag_ids int[])
returns bigint
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_review_id bigint;
begin
  if v_uid is null then
    raise exception '로그인이 필요합니다.';
  end if;

  if p_rating is null or p_rating < 1 or p_rating > 5 then
    raise exception '별점은 1~5 사이로 선택해주세요.';
  end if;
  if not exists (select 1 from public.menus m where m.id = p_menu_id) then
    raise exception '존재하지 않는 메뉴예요.';
  end if;
  if exists (
    select 1
    from (select distinct unnest(p_tag_ids) as tag_id) u
    where not exists (select 1 from public.taste_tags tt where tt.id = u.tag_id)
  ) then
    raise exception '존재하지 않는 맛이에요.';
  end if;

  insert into public.reviews (user_id, menu_id, rating)
  values (v_uid, p_menu_id, p_rating)
  on conflict (user_id, menu_id)
  do update set rating = excluded.rating, updated_at = now()
  returning id into v_review_id;

  delete from public.review_taste_tags where review_id = v_review_id;
  insert into public.review_taste_tags (review_id, taste_tag_id)
  select distinct v_review_id, u.tag_id
  from unnest(coalesce(p_tag_ids, '{}'::int[])) as u(tag_id);

  return v_review_id;
end;
$$;

-- 내 평가 삭제 (review_taste_tags 는 cascade). 평가가 없어도 오류 없이 끝난다
create or replace function public.delete_review(p_menu_id bigint)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception '로그인이 필요합니다.';
  end if;

  delete from public.reviews
  where user_id = auth.uid() and menu_id = p_menu_id;
end;
$$;

-- 화면용 RPC: 로그인 사용자만 실행
revoke all on function public.save_onboarding(text, jsonb, int[])              from public, anon;
revoke all on function public.get_restaurants(text, int, text, int)            from public, anon;
revoke all on function public.get_recommended_menus(text, int)                 from public, anon;
revoke all on function public.get_restaurant_detail(bigint)                    from public, anon;
revoke all on function public.get_restaurant_menus(bigint)                     from public, anon;
revoke all on function public.get_allergy_menus(bigint)                        from public, anon;
revoke all on function public.get_my_summary()                                 from public, anon;
revoke all on function public.get_taste_mates(int)                             from public, anon;
revoke all on function public.get_my_reviews()                                 from public, anon;
revoke all on function public.get_regions()                                    from public, anon;
revoke all on function public.upsert_review(bigint, int, int[])                from public, anon;
revoke all on function public.delete_review(bigint)                            from public, anon;
revoke all on function public.update_my_allergens(int[])                       from public, anon;
revoke all on function public.update_my_tastes(int[], int[])                      from public, anon;

grant execute on function public.save_onboarding(text, jsonb, int[])           to authenticated;
grant execute on function public.get_restaurants(text, int, text, int)         to authenticated;
grant execute on function public.get_recommended_menus(text, int)              to authenticated;
grant execute on function public.get_restaurant_detail(bigint)                 to authenticated;
grant execute on function public.get_restaurant_menus(bigint)                  to authenticated;
grant execute on function public.get_allergy_menus(bigint)                     to authenticated;
grant execute on function public.get_my_summary()                              to authenticated;
grant execute on function public.get_taste_mates(int)                          to authenticated;
grant execute on function public.get_my_reviews()                              to authenticated;
grant execute on function public.get_regions()                                 to authenticated;
grant execute on function public.upsert_review(bigint, int, int[])             to authenticated;
grant execute on function public.delete_review(bigint)                         to authenticated;
grant execute on function public.update_my_allergens(int[])                    to authenticated;
grant execute on function public.update_my_tastes(int[], int[])                   to authenticated;

-- =====================================================================
-- 검증용 SQL. 각 블록은 /* 와 */ 두 줄만 지우면 begin ~ rollback 을 한 번에 실행할 수 있다.
-- SQL Editor 는 postgres 권한이라 auth.uid() 가 null 이므로, 사용자를 흉내 낸다.
-- 시드 사용자(seed_demo_users.sql): seed01 = 5eed0000-0000-4000-8000-000000000001 … seed12 = …0012
-- 브랜드·가게·메뉴·평가 데이터는 실제 데이터가 들어온 뒤 확인한다.
-- =====================================================================

-- [검증 1] 내부 함수를 직접 호출하면 권한 오류가 나야 한다: ERROR: permission denied for function calc_menu_match
/*
begin;
  set local role authenticated;
  select set_config('request.jwt.claims', '{"sub":"5eed0000-0000-4000-8000-000000000001","role":"authenticated"}', true);

  select public.calc_menu_match('5eed0000-0000-4000-8000-000000000001', 1);
rollback;
*/

-- [검증 2] 알레르기를 등록한 사용자(seed02: 알류)의 추천에는 공식 확인된(verified/official_extract) 메뉴만, 겹치는 알레르기 메뉴는 없어야 한다
/*
begin;
  set local role authenticated;
  select set_config('request.jwt.claims', '{"sub":"5eed0000-0000-4000-8000-000000000002","role":"authenticated"}', true);

  select menu_name, brand_name, allergen_status, match_percent from public.get_recommended_menus('서울시 구로구', 100);
rollback;
*/

-- [검증 3] 지역 목록과 지점 수
/*
begin;
  set local role authenticated;
  select set_config('request.jwt.claims', '{"sub":"5eed0000-0000-4000-8000-000000000001","role":"authenticated"}', true);

  select * from public.get_regions();
rollback;
*/
