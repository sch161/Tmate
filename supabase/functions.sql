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
--   taste_learn_per_review 0.07  평가 1개마다 "평가로 본 입맛"을 섞는 비중 (7%)
--   taste_learn_max        0.7   평가로 본 입맛을 섞는 비중의 상한 (평가 10개부터 70%)
--   match_room_max       2  궁합 검사: 한 방에 들어갈 수 있는 최대 인원 (둘만의 궁합)
--   match_food_count     5  궁합 검사: 방마다 무작위로 뽑는 음식 수 (PART 2)
--   match_room_keep_days 7  궁합 검사: 이 일수가 지난 방은 새 방을 만들 때 지운다 (4자리 방 번호 재사용)
--   store_add_daily_max   3   가게 추가: 한 사람이 24시간 동안 추가할 수 있는 가게 수
--   store_add_attempt_max 10  가게 추가: 한 사람이 24시간 동안 AI 추정을 요청할 수 있는 횟수 (실패한 요청 포함)
--   store_menu_max        8   가게 추가: 한 번에 넣을 수 있는 메뉴 수
--   store_menu_total_max  30  가게 추가: 한 가게에 넣을 수 있는 메뉴 수 (나중에 더 넣는 것 포함)
--
-- 계산식 요약
--   지금 입맛    = 고른 입맛 비율 × (1 - w) + 평가로 본 입맛 × w,  w = min(평가 수 × taste_learn_per_review, taste_learn_max)
--                  평가로 본 입맛 = 평가한 메뉴의 맛마다 (별점 - 3)을 더한 값(5점 +2, 4점 +1, 3점 0, 2점 -1, 1점 -2). 음수는 0 으로 보고 합계 100 으로 맞춘다
--                  (평가에 고른 맛을 쓰고, 고른 맛이 없는 평가는 그 메뉴의 맛을 쓴다. 양수인 맛이 하나도 없으면 w = 0)
--   콘텐츠 점수  = 지금 입맛 비율 중 메뉴의 맛 태그에 포함된 것의 합 (0~100)
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
    when 'taste_learn_per_review' then 0.07
    when 'taste_learn_max'        then 0.7
    when 'match_room_max'       then 2
    when 'match_food_count'     then 5
    when 'match_room_keep_days' then 7
    when 'store_add_daily_max'   then 3
    when 'store_add_attempt_max' then 10
    when 'store_menu_max'        then 8
    when 'store_menu_total_max'  then 30
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

-- 지금 입맛(평가로 보정한 입맛 비율). 맛마다 한 행: 고른 비율(declared), 평가로 본 비율(learned), 둘을 섞은 지금 비율(ratio, 합계 100)
--   learn_percent 는 평가로 본 입맛을 섞은 비중(%)으로 모든 행이 같다. 계산식은 파일 머리말의 "지금 입맛" 참고.
--   고른 입맛이 없으면(온보딩 전) 행이 없다 → 화면은 입맛 등록 안내를 그대로 보여준다.
create or replace function public.calc_taste_profile(p_user uuid)
returns table (taste_tag_id int, declared int, learned int, ratio int, learn_percent int)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_reviews int;
  v_weight numeric;
begin
  if auth.uid() is null then
    raise exception '로그인이 필요합니다.';
  end if;

  if not exists (select 1 from public.user_taste_preferences utp where utp.user_id = p_user) then
    return;
  end if;

  select count(*) into v_reviews
  from public.reviews r
  where r.user_id = p_user;
  v_weight := least(v_reviews * public.calc_setting('taste_learn_per_review'), public.calc_setting('taste_learn_max'));

  return query
  with tagged as (
    -- 평가에 고른 맛
    select r.rating as rating, rt.taste_tag_id as taste_tag_id
    from public.reviews r
    join public.review_taste_tags rt on rt.review_id = r.id
    where r.user_id = p_user
    union all
    -- 고른 맛이 없는 평가는 그 메뉴의 맛
    select r.rating, mt.taste_tag_id
    from public.reviews r
    join public.menu_taste_tags mt on mt.menu_id = r.menu_id
    where r.user_id = p_user
      and not exists (select 1 from public.review_taste_tags rt where rt.review_id = r.id)
  ),
  scores as (
    select t.taste_tag_id as taste_tag_id, greatest(sum(t.rating - 3), 0)::numeric as score
    from tagged t
    group by t.taste_tag_id
  ),
  total as (
    select coalesce(sum(sc.score), 0) as total from scores sc
  ),
  merged as (
    select tt.id as taste_tag_id,
           coalesce(utp.ratio, 0)::numeric as declared,
           case when tot.total > 0 then coalesce(sc.score, 0) * 100 / tot.total else 0 end as learned,
           case when tot.total > 0 then v_weight else 0 end as weight
    from public.taste_tags tt
    cross join total tot
    left join public.user_taste_preferences utp on utp.user_id = p_user and utp.taste_tag_id = tt.id
    left join scores sc on sc.taste_tag_id = tt.id
    where utp.taste_tag_id is not null
       or coalesce(sc.score, 0) > 0
  ),
  mixed as (
    select m.taste_tag_id as taste_tag_id, m.declared as declared, m.learned as learned, m.weight as weight,
           (1 - m.weight) * m.declared + m.weight * m.learned as value
    from merged m
  ),
  rounded as (
    select x.taste_tag_id as taste_tag_id, x.declared as declared, x.learned as learned, x.weight as weight,
           round(x.value)::int as ratio,
           row_number() over (order by x.value desc, x.taste_tag_id) as rn,
           -- 반올림 때문에 합계가 어긋난 만큼(보통 ±1)을 가장 큰 맛에 더해 합계를 맞춘다
           (round(sum(x.value) over ()) - sum(round(x.value)) over ())::int as gap
    from mixed x
  )
  select z.taste_tag_id::int,
         round(z.declared)::int,
         round(z.learned)::int,
         z.ratio + case when z.rn = 1 then z.gap else 0 end,
         round(z.weight * 100)::int
  from rounded z;
end;
$$;

-- 콘텐츠 점수: 사용자의 지금 입맛 비율 중 메뉴 맛 태그에 포함된 것의 합 (메뉴 태그가 없으면 0)
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
    select sum(tp.ratio)
    from public.calc_taste_profile(p_user) tp
    join public.menu_taste_tags mtt on mtt.taste_tag_id = tp.taste_tag_id
    where mtt.menu_id = p_menu
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
--   이웃이 있으면 "입맛이 비슷한 n명이 평균 x점을 줬어요", 없으면 "{지금 입맛에서 가장 높은 비율의 맛}을/를 좋아하는 입맛과 잘 맞아요"
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
  from public.calc_taste_profile(p_user) tp
  join public.taste_tags tt on tt.id = tp.taste_tag_id
  where tp.ratio > 0
  order by tp.ratio desc, tt.id
  limit 1;

  if v_top is null then
    return '입맛을 설정하면 추천 이유를 알려드려요';
  end if;
  return public.josa(v_top, '을/를') || ' 좋아하는 입맛과 잘 맞아요';
end;
$$;

-- 입맛 유형 이름·설명 (지금 입맛의 비율 상위 2개 기준). 맛이 없으면 둘 다 null
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

  select array_agg(tt.name order by tp.ratio desc, tt.id),
         array_agg(public.taste_short_name(tt.code, tt.name) order by tp.ratio desc, tt.id)
  into v_names, v_shorts
  from public.calc_taste_profile(p_user) tp
  join public.taste_tags tt on tt.id = tp.taste_tag_id
  where tp.ratio > 0;

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
revoke all on function public.calc_taste_profile(uuid)              from public, anon, authenticated;
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
  has_official_allergen boolean,
  category_name text
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
           b.image_url as brand_image_url,
           fc.name as category_name
    from public.restaurants r
    join public.brands b on b.id = r.brand_id
    left join public.food_categories fc on fc.id = b.category_id
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
         x.brand_id, x.brand_name, x.is_franchise, x.has_official_allergen, x.category_name
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
           bi.has_official_allergen as has_official_allergen,
           bb.category_name as category_name
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
  allergen_status public.allergen_status,
  category_name text
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
         x.brand_name, x.allergen_status, x.category_name
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
           m.allergen_status as allergen_status,
           fc.name as category_name
    from (
      select rr.brand_id as brand_id, min(rr.id) as restaurant_id
      from public.restaurants rr
      where p_region is null or rr.region = p_region
      group by rr.brand_id
    ) rep
    join public.restaurants r on r.id = rep.restaurant_id
    join public.brands b on b.id = rep.brand_id
    left join public.food_categories fc on fc.id = b.category_id
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
  allergen_data_date date,
  category_name text
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
         b.allergen_data_date,
         fc.name
  from public.restaurants r
  join public.brands b on b.id = r.brand_id
  left join public.food_categories fc on fc.id = b.category_id
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
--   taste_ratios 예: [{"name": "매콤함", "ratio": 60}, ...] (ratio 내림차순). 평가로 보정한 지금 입맛이다 (고른 비율은 get_my_taste_profile)
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
           select jsonb_agg(jsonb_build_object('name', tt.name, 'ratio', tp.ratio) order by tp.ratio desc, tt.id)
           from public.calc_taste_profile(v_uid) tp
           join public.taste_tags tt on tt.id = tp.taste_tag_id
           where tp.ratio > 0
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

-- 내 입맛 자세히: 맛마다 고른 비율(declared)·평가로 본 비율(learned)·지금 비율(ratio). ratio 내림차순
--   learn_percent(평가를 섞은 비중 %)와 review_count(내 평가 수)는 모든 행이 같다. 고른 입맛이 없으면 행이 없다.
create or replace function public.get_my_taste_profile()
returns table (
  name text,
  declared int,
  learned int,
  ratio int,
  learn_percent int,
  review_count int
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
  select tt.name, tp.declared, tp.learned, tp.ratio, tp.learn_percent,
         (select count(*) from public.reviews rv where rv.user_id = v_uid)::int
  from public.calc_taste_profile(v_uid) tp
  join public.taste_tags tt on tt.id = tp.taste_tag_id
  order by tp.ratio desc, tt.id;
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
  brand_name text,
  category_name text
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
         b.name,
         fc.name
  from public.reviews rv
  join public.menus m on m.id = rv.menu_id
  join public.brands b on b.id = m.brand_id
  left join public.food_categories fc on fc.id = b.category_id
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
revoke all on function public.get_my_taste_profile()                           from public, anon;
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
grant execute on function public.get_my_taste_profile()                        to authenticated;
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

-- =====================================================================
-- 친구랑 궁합 검사 (행사 체험용)
--   흐름: 방 만들기/들어가기 → 검사(PART 1 둘 중 하나 문항 + PART 2 그 방의 음식) → 방 사람들과의 궁합
--   궁합(%) = 두 사람이 같은 답을 고른 PART 1 문항 수 / 둘 다 답한 문항 수 × 100  (문항이 10개면 10% 단위)
--   PART 2(음식)는 점수에 넣지 않는다. 결과 카드(둘 다 좋아하는 음식 등)와 랭킹 동점 처리에만 쓴다.
--   다른 사람의 정보는 같은 방 사람의 닉네임·궁합 점수·그 방 음식에 대한 답만 돌려준다.
--   예외(부스 진행자용 영수증 인쇄): get_match_room_pairs · get_match_pair_foods 는 방 멤버가 아니어도 방 번호로 같은 범위(닉네임·점수·그 방 음식 답)를 읽는다.
-- =====================================================================

-- 내부: p_code 방에서 로그인한 사용자가 멤버이면 방 id, 아니면 예외
create or replace function public.calc_match_room_id(p_code text)
returns bigint
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_room bigint;
begin
  if v_uid is null then
    raise exception '로그인이 필요합니다.';
  end if;

  select r.id into v_room
  from public.match_rooms r
  join public.match_room_members m on m.room_id = r.id and m.user_id = v_uid
  where r.code = p_code;

  if v_room is null then
    raise exception '들어가 있지 않은 방이에요. 방 번호를 다시 확인해주세요.';
  end if;
  return v_room;
end;
$$;

-- 내부: 같은 방 두 사람의 궁합 점수 (0~100). 둘 중 하나라도 검사를 마치지 않았으면 null
create or replace function public.calc_match_score(p_room bigint, p_a uuid, p_b uuid)
returns int
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_common int;
  v_same int;
begin
  if auth.uid() is null then
    raise exception '로그인이 필요합니다.';
  end if;

  select count(*), count(*) filter (where a.choice = b.choice)
  into v_common, v_same
  from public.match_answers a
  join public.match_answers b on b.room_id = a.room_id and b.question_id = a.question_id
  where a.room_id = p_room
    and a.user_id = p_a
    and b.user_id = p_b;

  if v_common = 0 then
    return null;
  end if;
  return round(v_same * 100.0 / v_common)::int;
end;
$$;

-- 방을 만들고 들어간다. 반환: 4자리 방 번호.
--   그 방에서 나올 음식을 match_food_count 개 무작위로 뽑아 고정한다 → 같은 방 친구에게 같은 음식이 나온다.
--   방 번호를 다시 쓸 수 있도록 match_room_keep_days 일이 지난 방은 이때 지운다(답도 함께 지워진다).
create or replace function public.create_match_room()
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_code text;
  v_room bigint;
  v_try int := 0;
begin
  if v_uid is null then
    raise exception '로그인이 필요합니다.';
  end if;
  if not exists (select 1 from public.match_questions q where q.is_active) then
    raise exception '검사 문항이 아직 준비되지 않았어요.';
  end if;

  delete from public.match_rooms r
  where r.created_at < now() - make_interval(days => public.calc_setting('match_room_keep_days')::int);

  loop
    v_code := lpad(floor(random() * 10000)::int::text, 4, '0');
    begin
      insert into public.match_rooms (code, created_by) values (v_code, v_uid) returning id into v_room;
      exit;
    exception when unique_violation then
      v_try := v_try + 1;
      if v_try >= 20 then
        raise exception '방을 만들지 못했어요. 잠시 후 다시 시도해주세요.';
      end if;
    end;
  end loop;

  insert into public.match_room_foods (room_id, food_id, sort_order)
  select v_room, x.id, row_number() over ()
  from (
    select f.id from public.match_foods f
    where f.is_active
    order by random()
    limit public.calc_setting('match_food_count')::int
  ) x;

  insert into public.match_room_members (room_id, user_id, member_no) values (v_room, v_uid, 1);
  return v_code;
end;
$$;

-- 방 번호로 들어간다. 이미 들어가 있으면 아무 일도 하지 않는다.
create or replace function public.join_match_room(p_code text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_room bigint;
  v_members int;
  v_next int;
begin
  if v_uid is null then
    raise exception '로그인이 필요합니다.';
  end if;
  if p_code is null or p_code !~ '^[0-9]{4}$' then
    raise exception '방 번호는 숫자 4자리예요.';
  end if;

  -- 같은 방에 동시에 들어와도 member_no 가 겹치지 않도록 방 행을 잠근다
  select r.id into v_room from public.match_rooms r where r.code = p_code for update;
  if v_room is null then
    raise exception '없는 방 번호예요. 번호를 다시 확인해주세요.';
  end if;
  if exists (select 1 from public.match_room_members m where m.room_id = v_room and m.user_id = v_uid) then
    return;
  end if;

  select count(*), coalesce(max(m.member_no), 0) + 1
  into v_members, v_next
  from public.match_room_members m
  where m.room_id = v_room;
  if v_members >= public.calc_setting('match_room_max') then
    raise exception '이미 두 명이 들어온 방이에요. 새 방을 만들어주세요.';
  end if;

  insert into public.match_room_members (room_id, user_id, member_no) values (v_room, v_uid, v_next);
end;
$$;

-- 내가 가장 최근에 들어간 방 번호 (없으면 null)
create or replace function public.get_my_match_room()
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception '로그인이 필요합니다.';
  end if;

  return (
    select r.code
    from public.match_room_members m
    join public.match_rooms r on r.id = m.room_id
    where m.user_id = v_uid
    order by m.joined_at desc
    limit 1
  );
end;
$$;

-- PART 1 문항과 이 방에서 내가 고른 답 (my_choice: 1=A, 2=B, null=아직)
create or replace function public.get_match_questions(p_code text)
returns table (
  question_id smallint,
  body text,
  option_a text,
  option_b text,
  my_choice smallint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_uid uuid := auth.uid();
  v_room bigint := public.calc_match_room_id(p_code);
begin
  return query
  select q.id, q.body, q.option_a, q.option_b, a.choice
  from public.match_questions q
  left join public.match_answers a on a.question_id = q.id and a.room_id = v_room and a.user_id = v_uid
  where q.is_active
  order by q.sort_order, q.id;
end;
$$;

-- PART 2: 이 방의 음식과 내가 고른 답
create or replace function public.get_match_foods(p_code text)
returns table (
  food_id smallint,
  name text,
  my_eaten boolean,
  my_rating smallint,
  my_want_try boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_uid uuid := auth.uid();
  v_room bigint := public.calc_match_room_id(p_code);
begin
  return query
  select f.id, f.name, a.eaten, a.rating, a.want_try
  from public.match_room_foods rf
  join public.match_foods f on f.id = rf.food_id
  left join public.match_food_answers a on a.food_id = f.id and a.room_id = v_room and a.user_id = v_uid
  where rf.room_id = v_room
  order by rf.sort_order;
end;
$$;

-- 이 방에서의 내 검사 결과를 통째로 저장한다 (다시 저장하면 바꿔 쓴다).
--   p_choices 예: [{"question_id": 1, "choice": 1}, ...]   모든 문항에 답해야 한다 (1=A, 2=B)
--   p_foods   예: [{"food_id": 3, "eaten": true, "rating": 5}, {"food_id": 7, "eaten": false, "want_try": true}]   이 방의 모든 음식에 답해야 한다
create or replace function public.save_match_test(p_code text, p_choices jsonb, p_foods jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_room bigint := public.calc_match_room_id(p_code);
  v_saved int;
begin
  if p_choices is null or jsonb_typeof(p_choices) <> 'array' or p_foods is null or jsonb_typeof(p_foods) <> 'array' then
    raise exception '답변 형식이 올바르지 않아요.';
  end if;

  delete from public.match_answers where room_id = v_room and user_id = v_uid;
  delete from public.match_food_answers where room_id = v_room and user_id = v_uid;

  insert into public.match_answers (room_id, user_id, question_id, choice)
  select distinct on (q.id) v_room, v_uid, q.id, x.choice
  from jsonb_to_recordset(p_choices) as x(question_id smallint, choice smallint)
  join public.match_questions q on q.id = x.question_id and q.is_active
  where x.choice in (1, 2)
  order by q.id;
  get diagnostics v_saved = row_count;
  if v_saved <> jsonb_array_length(p_choices)
     or v_saved <> (select count(*) from public.match_questions q where q.is_active) then
    raise exception '모든 문항에 답해주세요.';
  end if;

  insert into public.match_food_answers (room_id, user_id, food_id, eaten, rating, want_try)
  select distinct on (rf.food_id) v_room, v_uid, rf.food_id, x.eaten,
         case when x.eaten then x.rating end,
         case when not x.eaten then x.want_try end
  from jsonb_to_recordset(p_foods) as x(food_id smallint, eaten boolean, rating smallint, want_try boolean)
  join public.match_room_foods rf on rf.room_id = v_room and rf.food_id = x.food_id
  where x.eaten is not null
    and ((x.eaten and x.rating between 1 and 5) or (not x.eaten and x.want_try is not null))
  order by rf.food_id;
  get diagnostics v_saved = row_count;
  if v_saved <> jsonb_array_length(p_foods)
     or v_saved <> (select count(*) from public.match_room_foods rf where rf.room_id = v_room) then
    raise exception '모든 음식에 답해주세요.';
  end if;

  update public.match_room_members
  set completed_at = now()
  where room_id = v_room and user_id = v_uid;
end;
$$;

-- 방 사람들과 나의 궁합. completed: 검사를 마쳤는지 / score: 나와의 궁합(%), 나 자신이거나 둘 중 하나가 아직이면 null
create or replace function public.get_match_room(p_code text)
returns table (
  member_no smallint,
  nickname text,
  is_me boolean,
  completed boolean,
  score int
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_uid uuid := auth.uid();
  v_room bigint := public.calc_match_room_id(p_code);
begin
  return query
  select m.member_no,
         p.nickname,
         (m.user_id = v_uid),
         (m.completed_at is not null),
         case when m.user_id = v_uid then null else public.calc_match_score(v_room, v_uid, m.user_id) end
  from public.match_room_members m
  join public.profiles p on p.id = m.user_id
  where m.room_id = v_room
  order by (m.user_id = v_uid) desc, m.member_no;
end;
$$;

-- 결과 카드용: 이 방의 음식에 대한 나와 친구(p_member_no)의 답을 나란히 돌려준다. 둘 다 검사를 마쳐야 한다.
create or replace function public.get_match_compare(p_code text, p_member_no int)
returns table (
  food_name text,
  my_eaten boolean,
  my_rating smallint,
  my_want_try boolean,
  friend_eaten boolean,
  friend_rating smallint,
  friend_want_try boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_uid uuid := auth.uid();
  v_room bigint := public.calc_match_room_id(p_code);
  v_friend uuid;
begin
  select m.user_id into v_friend
  from public.match_room_members m
  where m.room_id = v_room and m.member_no = p_member_no and m.user_id <> v_uid and m.completed_at is not null;
  if v_friend is null
     or not exists (select 1 from public.match_room_members m where m.room_id = v_room and m.user_id = v_uid and m.completed_at is not null) then
    raise exception '두 사람 모두 검사를 마쳐야 결과를 볼 수 있어요.';
  end if;

  return query
  select f.name, a.eaten, a.rating, a.want_try, b.eaten, b.rating, b.want_try
  from public.match_room_foods rf
  join public.match_foods f on f.id = rf.food_id
  join public.match_food_answers a on a.room_id = v_room and a.user_id = v_uid and a.food_id = rf.food_id
  join public.match_food_answers b on b.room_id = v_room and b.user_id = v_friend and b.food_id = rf.food_id
  where rf.room_id = v_room
  order by rf.sort_order;
end;
$$;

-- 궁합 랭킹 (부스 화면용): 최근 p_hours 시간 안에 만든 방에서, 같은 방 두 사람의 궁합이 높은 순.
--   동점이면 둘 다 먹어본 음식의 별점이 더 비슷한 쪽, 그다음 먼저 검사를 마친 쪽이 위다.
create or replace function public.get_match_ranking(p_limit int default 10, p_hours int default 24)
returns table (
  rank int,
  nickname_a text,
  nickname_b text,
  score int
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_limit int;
  v_hours int;
begin
  if auth.uid() is null then
    raise exception '로그인이 필요합니다.';
  end if;

  v_limit := least(greatest(coalesce(p_limit, 10), 1), 50);
  v_hours := least(greatest(coalesce(p_hours, 24), 1), 720);

  return query
  with pairs as (
    select a.room_id,
           a.user_id as user_a,
           b.user_id as user_b,
           public.calc_match_score(a.room_id, a.user_id, b.user_id) as score,
           greatest(a.completed_at, b.completed_at) as done_at
    from public.match_room_members a
    join public.match_room_members b on b.room_id = a.room_id and b.member_no > a.member_no
    join public.match_rooms r on r.id = a.room_id
    where r.created_at >= now() - make_interval(hours => v_hours)
      and a.completed_at is not null
      and b.completed_at is not null
  ),
  ranked as (
    select x.*,
           (
             select avg(abs(fa.rating - fb.rating))
             from public.match_food_answers fa
             join public.match_food_answers fb on fb.room_id = fa.room_id and fb.food_id = fa.food_id and fb.user_id = x.user_b
             where fa.room_id = x.room_id and fa.user_id = x.user_a and fa.eaten and fb.eaten
           ) as food_diff
    from pairs x
    where x.score is not null
  )
  select row_number() over (order by y.score desc, y.food_diff asc nulls last, y.done_at)::int,
         pa.nickname,
         pb.nickname,
         y.score
  from ranked y
  join public.profiles pa on pa.id = y.user_a
  join public.profiles pb on pb.id = y.user_b
  order by y.score desc, y.food_diff asc nulls last, y.done_at
  limit v_limit;
end;
$$;

-- 영수증 인쇄(부스 진행자용): 방 번호로 그 방에서 둘 다 검사를 마친 두 사람 조합과 궁합 점수.
--   진행자는 방 멤버가 아니므로 calc_match_room_id(멤버 확인)를 쓰지 않는다. 로그인만 확인한다.
--   돌려주는 것은 닉네임·방 안 번호(member_no)·궁합 점수뿐이다 (get_match_ranking 과 같은 수준).
create or replace function public.get_match_room_pairs(p_code text)
returns table (
  member_no_a smallint,
  member_no_b smallint,
  nickname_a text,
  nickname_b text,
  score int
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_room bigint;
begin
  if auth.uid() is null then
    raise exception '로그인이 필요합니다.';
  end if;
  if p_code is null or p_code !~ '^[0-9]{4}$' then
    raise exception '방 번호는 숫자 4자리예요.';
  end if;

  select r.id into v_room from public.match_rooms r where r.code = p_code;
  if v_room is null then
    raise exception '없는 방 번호예요. 번호를 다시 확인해주세요.';
  end if;

  return query
  select x.member_no_a, x.member_no_b, pa.nickname, pb.nickname, x.score
  from (
    select a.member_no as member_no_a,
           b.member_no as member_no_b,
           a.user_id as user_a,
           b.user_id as user_b,
           public.calc_match_score(v_room, a.user_id, b.user_id) as score
    from public.match_room_members a
    join public.match_room_members b on b.room_id = a.room_id and b.member_no > a.member_no
    where a.room_id = v_room
      and a.completed_at is not null
      and b.completed_at is not null
  ) x
  join public.profiles pa on pa.id = x.user_a
  join public.profiles pb on pb.id = x.user_b
  where x.score is not null
  order by x.member_no_a, x.member_no_b;
end;
$$;

-- 영수증 인쇄(부스 진행자용): 그 방의 음식에 대한 두 사람(p_member_no_a, p_member_no_b)의 답을 나란히 돌려준다.
--   get_match_compare 의 진행자용이다(호출자가 방 멤버가 아니어도 된다). 둘 다 검사를 마쳐야 한다.
create or replace function public.get_match_pair_foods(p_code text, p_member_no_a int, p_member_no_b int)
returns table (
  food_name text,
  a_eaten boolean,
  a_rating smallint,
  a_want_try boolean,
  b_eaten boolean,
  b_rating smallint,
  b_want_try boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_room bigint;
  v_a uuid;
  v_b uuid;
begin
  if auth.uid() is null then
    raise exception '로그인이 필요합니다.';
  end if;
  if p_code is null or p_code !~ '^[0-9]{4}$' then
    raise exception '방 번호는 숫자 4자리예요.';
  end if;

  select r.id into v_room from public.match_rooms r where r.code = p_code;
  if v_room is null then
    raise exception '없는 방 번호예요. 번호를 다시 확인해주세요.';
  end if;

  select m.user_id into v_a
  from public.match_room_members m
  where m.room_id = v_room and m.member_no = p_member_no_a and m.completed_at is not null;
  select m.user_id into v_b
  from public.match_room_members m
  where m.room_id = v_room and m.member_no = p_member_no_b and m.completed_at is not null;
  if v_a is null or v_b is null or v_a = v_b then
    raise exception '두 사람 모두 검사를 마쳐야 결과를 볼 수 있어요.';
  end if;

  return query
  select f.name, a.eaten, a.rating, a.want_try, b.eaten, b.rating, b.want_try
  from public.match_room_foods rf
  join public.match_foods f on f.id = rf.food_id
  join public.match_food_answers a on a.room_id = v_room and a.user_id = v_a and a.food_id = rf.food_id
  join public.match_food_answers b on b.room_id = v_room and b.user_id = v_b and b.food_id = rf.food_id
  where rf.room_id = v_room
  order by rf.sort_order;
end;
$$;

revoke all on function public.calc_match_room_id(text)                  from public, anon, authenticated;
revoke all on function public.calc_match_score(bigint, uuid, uuid)      from public, anon, authenticated;
revoke all on function public.create_match_room()                       from public, anon;
revoke all on function public.join_match_room(text)                     from public, anon;
revoke all on function public.get_my_match_room()                       from public, anon;
revoke all on function public.get_match_questions(text)                 from public, anon;
revoke all on function public.get_match_foods(text)                     from public, anon;
revoke all on function public.save_match_test(text, jsonb, jsonb)       from public, anon;
revoke all on function public.get_match_room(text)                      from public, anon;
revoke all on function public.get_match_compare(text, int)              from public, anon;
revoke all on function public.get_match_ranking(int, int)               from public, anon;
revoke all on function public.get_match_room_pairs(text)                from public, anon;
revoke all on function public.get_match_pair_foods(text, int, int)      from public, anon;
grant execute on function public.create_match_room()                    to authenticated;
grant execute on function public.join_match_room(text)                  to authenticated;
grant execute on function public.get_my_match_room()                    to authenticated;
grant execute on function public.get_match_questions(text)              to authenticated;
grant execute on function public.get_match_foods(text)                  to authenticated;
grant execute on function public.save_match_test(text, jsonb, jsonb)    to authenticated;
grant execute on function public.get_match_room(text)                   to authenticated;
grant execute on function public.get_match_compare(text, int)           to authenticated;
grant execute on function public.get_match_ranking(int, int)            to authenticated;
grant execute on function public.get_match_room_pairs(text)             to authenticated;
grant execute on function public.get_match_pair_foods(text, int, int)   to authenticated;

-- =====================================================================
-- 가게 추가 (사용자가 직접 추가하는 개인 식당)
--   흐름: 화면 → Edge Function(add-store) → begin_store_add(확인·요청 기록) → AI 가 메뉴 이름으로 알레르기·맛 추정 → add_user_store(저장)
--   * 가게 1개 = 브랜드 1개(is_franchise = false, created_by = 추가한 사람).
--   * 알레르기는 AI 추정이라 메뉴의 allergen_status 는 언제나 estimated(추정) 또는 unknown(정보 없음)이다. 공식 확인(verified) 으로는 저장하지 않는다.
--     → 알레르기를 등록한 사용자에게는 추천에서 빠지고 알레르기 탭에서 "정보 없음"으로 보인다 (안전 우선 규칙 그대로).
--   * add_user_store 는 로그인 사용자가 직접 불러도 같은 규칙(추정 표시, 하루 한도, 중복 확인)이 적용된다.
-- =====================================================================

-- 내부: 가게 추가 입력 확인 (이름·지역·하루 한도·중복). 문제가 있으면 예외
create or replace function public.calc_store_add_check(p_name text, p_region text)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_name text := btrim(regexp_replace(coalesce(p_name, ''), '\s+', ' ', 'g'));
begin
  if v_uid is null then
    raise exception '로그인이 필요합니다.';
  end if;
  if char_length(v_name) < 2 or char_length(v_name) > 40 then
    raise exception '가게 이름은 2~40자로 입력해주세요.';
  end if;
  if p_region is null or not exists (select 1 from public.restaurants r where r.region = p_region) then
    raise exception '지역을 다시 선택해주세요.';
  end if;
  if (
    select count(*) from public.brands b
    where b.created_by = v_uid and b.created_at > now() - interval '24 hours'
  ) >= public.calc_setting('store_add_daily_max') then
    raise exception '가게는 하루에 %곳까지 추가할 수 있어요.', public.calc_setting('store_add_daily_max')::int;
  end if;
  if exists (
    select 1 from public.restaurants r
    where r.region = p_region
      and lower(replace(r.name, ' ', '')) = lower(replace(v_name, ' ', ''))
  ) then
    raise exception '이미 등록된 가게예요.';
  end if;
end;
$$;

-- 가게 추가 시작: 입력을 확인하고 AI 추정 요청 1회를 기록한다 (하루 요청 한도). Edge Function 이 AI 를 부르기 전에 호출한다
create or replace function public.begin_store_add(p_name text, p_region text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  perform public.calc_store_add_check(p_name, p_region);

  if (
    select count(*) from public.store_add_attempts a
    where a.user_id = v_uid and a.created_at > now() - interval '24 hours'
  ) >= public.calc_setting('store_add_attempt_max') then
    raise exception '오늘은 가게 추가를 너무 많이 시도했어요. 내일 다시 해주세요.';
  end if;
  insert into public.store_add_attempts (user_id) values (v_uid);
end;
$$;

-- 내부: 사용자가 넣은 메뉴들을 브랜드에 저장한다 (add_user_store · add_user_store_menus 가 같이 쓴다). p_menus 형식은 add_user_store 설명 참고
create or replace function public.calc_insert_user_menus(p_brand bigint, p_menus jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_menu_id bigint;
  v_menu jsonb;
  v_menu_name text;
  v_inferred boolean;
begin
  if auth.uid() is null then
    raise exception '로그인이 필요합니다.';
  end if;

  for v_menu in select m from jsonb_array_elements(p_menus) m loop
    v_menu_name := btrim(v_menu ->> 'name');
    v_inferred := coalesce((v_menu ->> 'inferred')::boolean, false);

    insert into public.menus (brand_id, name, description, allergen_status, allergen_checked_at, allergen_note, menu_source_name)
    values (
      p_brand,
      v_menu_name,
      nullif(left(btrim(coalesce(v_menu ->> 'description', '')), 100), ''),
      case when v_inferred then 'estimated'::public.allergen_status else 'unknown'::public.allergen_status end,
      case when v_inferred then now() end,
      case when v_inferred then 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요' end,
      '사용자 등록'
    )
    returning id into v_menu_id;

    -- 맛 태그: 있는 맛만, 최대 3개
    insert into public.menu_taste_tags (menu_id, taste_tag_id)
    select v_menu_id, t.id
    from (
      select distinct tt.id
      from jsonb_array_elements_text(case when jsonb_typeof(v_menu -> 'taste_tag_ids') = 'array' then v_menu -> 'taste_tag_ids' else '[]'::jsonb end) e(value)
      join public.taste_tags tt on tt.id::text = e.value
      order by tt.id
      limit 3
    ) t;

    -- 알레르기: 추정한 메뉴만. 같은 알레르기가 두 번 오면 위험(danger)을 남긴다
    if v_inferred then
      insert into public.menu_allergens (menu_id, allergen_id, level, original_text)
      select v_menu_id, x.allergen_id,
             case when bool_or(x.level = 'danger') then 'danger'::public.allergen_level else 'caution'::public.allergen_level end,
             'AI 추정'
      from (
        select al.id as allergen_id, a ->> 'level' as level
        from jsonb_array_elements(case when jsonb_typeof(v_menu -> 'allergens') = 'array' then v_menu -> 'allergens' else '[]'::jsonb end) a
        join public.allergens al on al.id::text = a ->> 'allergen_id'
        where a ->> 'level' in ('danger', 'caution')
      ) x
      group by x.allergen_id;
    end if;
  end loop;
end;
$$;

-- 가게와 메뉴 저장. 가게 id(restaurants.id)를 돌려준다
--   p_menus 예: [{"name": "김치찌개", "description": "돼지고기", "inferred": true,
--                 "taste_tag_ids": [1, 9], "allergens": [{"allergen_id": 5, "level": "danger"}, {"allergen_id": 3, "level": "caution"}]}]
--   inferred = true 이면 estimated(추정), 아니면 unknown(정보 없음)으로 저장하고 알레르기 행을 만들지 않는다.
create or replace function public.add_user_store(p_name text, p_region text, p_address text, p_category_id int, p_menus jsonb)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_name text := btrim(regexp_replace(coalesce(p_name, ''), '\s+', ' ', 'g'));
  v_address text := left(btrim(coalesce(p_address, '')), 100);
  v_brand bigint;
  v_restaurant bigint;
  v_count int;
begin
  perform public.calc_store_add_check(p_name, p_region);

  if p_category_id is null or not exists (select 1 from public.food_categories c where c.id = p_category_id) then
    raise exception '음식 종류를 선택해주세요.';
  end if;
  if p_menus is null or jsonb_typeof(p_menus) <> 'array' then
    raise exception '메뉴를 1개 이상 입력해주세요.';
  end if;
  v_count := jsonb_array_length(p_menus);
  if v_count < 1 or v_count > public.calc_setting('store_menu_max') then
    raise exception '메뉴는 1~%개까지 입력할 수 있어요.', public.calc_setting('store_menu_max')::int;
  end if;
  if exists (
    select 1 from jsonb_array_elements(p_menus) m
    where char_length(btrim(coalesce(m ->> 'name', ''))) < 1 or char_length(btrim(m ->> 'name')) > 40
  ) then
    raise exception '메뉴 이름은 1~40자로 입력해주세요.';
  end if;
  if (select count(distinct lower(replace(btrim(m ->> 'name'), ' ', ''))) from jsonb_array_elements(p_menus) m) <> v_count then
    raise exception '같은 메뉴가 두 번 들어 있어요.';
  end if;

  insert into public.brands (name, is_franchise, category_id, research_status, researched_at, created_by)
  values (v_name, false, p_category_id, 'done', now(), v_uid)
  returning id into v_brand;

  insert into public.restaurants (brand_id, name, address, region, sido, sigungu)
  select v_brand, v_name, case when v_address = '' then p_region else v_address end, p_region, x.sido, x.sigungu
  from (select r.sido, r.sigungu from public.restaurants r where r.region = p_region order by r.id limit 1) x
  returning id into v_restaurant;

  perform public.calc_insert_user_menus(v_brand, p_menus);

  return v_restaurant;
end;
$$;

revoke all on function public.calc_store_add_check(text, text)                from public, anon, authenticated;
revoke all on function public.begin_store_add(text, text)                     from public, anon;
revoke all on function public.add_user_store(text, text, text, int, jsonb)    from public, anon;
grant execute on function public.begin_store_add(text, text)                  to authenticated;
grant execute on function public.add_user_store(text, text, text, int, jsonb) to authenticated;

-- 내가 추가한 가게인지 (가게 상세에서 "메뉴 추가" 버튼을 보여줄지 정한다)
create or replace function public.is_my_store(p_restaurant_id bigint)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception '로그인이 필요합니다.';
  end if;
  return exists (
    select 1 from public.restaurants r join public.brands b on b.id = r.brand_id
    where r.id = p_restaurant_id and b.created_by = auth.uid() and not b.is_franchise
  );
end;
$$;

-- 내부: 내가 추가한 가게면 브랜드 id, 아니면 예외
create or replace function public.calc_my_store_brand(p_restaurant_id bigint)
returns bigint
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_brand bigint;
begin
  if auth.uid() is null then
    raise exception '로그인이 필요합니다.';
  end if;
  select b.id into v_brand
  from public.restaurants r join public.brands b on b.id = r.brand_id
  where r.id = p_restaurant_id and b.created_by = auth.uid() and not b.is_franchise;
  if v_brand is null then
    raise exception '내가 추가한 가게에만 메뉴를 넣을 수 있어요.';
  end if;
  return v_brand;
end;
$$;

-- 메뉴 추가 시작: 내 가게인지 확인하고 AI 추정 요청 1회를 기록한다 (하루 요청 한도는 가게 추가와 같이 센다)
create or replace function public.begin_store_menu_add(p_restaurant_id bigint)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  perform public.calc_my_store_brand(p_restaurant_id);
  if (
    select count(*) from public.store_add_attempts a
    where a.user_id = v_uid and a.created_at > now() - interval '24 hours'
  ) >= public.calc_setting('store_add_attempt_max') then
    raise exception '오늘은 너무 많이 시도했어요. 내일 다시 해주세요.';
  end if;
  insert into public.store_add_attempts (user_id) values (v_uid);
end;
$$;

-- 내가 추가한 가게에 메뉴를 더 넣는다. 한 번에 store_menu_max 개, 가게 전체로 store_menu_total_max 개까지
create or replace function public.add_user_store_menus(p_restaurant_id bigint, p_menus jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_brand bigint := public.calc_my_store_brand(p_restaurant_id);
  v_count int;
  v_existing int;
begin
  if p_menus is null or jsonb_typeof(p_menus) <> 'array' then
    raise exception '메뉴를 1개 이상 입력해주세요.';
  end if;
  v_count := jsonb_array_length(p_menus);
  if v_count < 1 or v_count > public.calc_setting('store_menu_max') then
    raise exception '메뉴는 한 번에 1~%개까지 넣을 수 있어요.', public.calc_setting('store_menu_max')::int;
  end if;
  select count(*) into v_existing from public.menus m where m.brand_id = v_brand;
  if v_existing + v_count > public.calc_setting('store_menu_total_max') then
    raise exception '한 가게에는 메뉴를 %개까지 넣을 수 있어요.', public.calc_setting('store_menu_total_max')::int;
  end if;
  if exists (
    select 1 from jsonb_array_elements(p_menus) m
    where char_length(btrim(coalesce(m ->> 'name', ''))) < 1 or char_length(btrim(m ->> 'name')) > 40
  ) then
    raise exception '메뉴 이름은 1~40자로 입력해주세요.';
  end if;
  if (select count(distinct lower(replace(btrim(m ->> 'name'), ' ', ''))) from jsonb_array_elements(p_menus) m) <> v_count
     or exists (
       select 1 from jsonb_array_elements(p_menus) m
       join public.menus e on e.brand_id = v_brand and lower(replace(e.name, ' ', '')) = lower(replace(btrim(m ->> 'name'), ' ', ''))
     ) then
    raise exception '이미 있는 메뉴가 들어 있어요.';
  end if;

  perform public.calc_insert_user_menus(v_brand, p_menus);
end;
$$;

revoke all on function public.calc_insert_user_menus(bigint, jsonb)    from public, anon, authenticated;
revoke all on function public.calc_my_store_brand(bigint)              from public, anon, authenticated;
revoke all on function public.is_my_store(bigint)                      from public, anon;
revoke all on function public.begin_store_menu_add(bigint)             from public, anon;
revoke all on function public.add_user_store_menus(bigint, jsonb)      from public, anon;
grant execute on function public.is_my_store(bigint)                   to authenticated;
grant execute on function public.begin_store_menu_add(bigint)          to authenticated;
grant execute on function public.add_user_store_menus(bigint, jsonb)   to authenticated;

-- =====================================================================
-- 궁합 영수증 사진 올리기 (손님 폰 → 진행자 인쇄 화면)
--   손님: request_match_print(방 번호, 사진) — 그 방에서 검사를 마친 두 사람만 올릴 수 있다. 방마다 1건(다시 올리면 바뀐다)
--   진행자: get_match_print_queue · get_match_print_photo · mark_match_printed — 진행자 번호(match_print_settings.passcode)가 맞아야 한다
--   사진은 얼굴이 나오므로 진행자 번호 없이는 읽을 수 없고, 하루가 지나면 지운다.
-- =====================================================================

-- 내부: 진행자 번호 확인. 틀리면 예외
create or replace function public.calc_match_print_staff(p_passcode text)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception '로그인이 필요합니다.';
  end if;
  if p_passcode is null or not exists (select 1 from public.match_print_settings s where s.passcode = p_passcode) then
    raise exception '진행자 번호가 맞지 않아요.';
  end if;
end;
$$;

-- 손님: 사진과 함께 영수증 인쇄를 요청한다. p_show_on_rank 가 true 이면 랭킹 화면에도 사진을 띄운다 (손님이 동의한 경우만)
drop function if exists public.request_match_print(text, text);
create or replace function public.request_match_print(p_code text, p_photo text, p_show_on_rank boolean default false)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_room bigint;
begin
  v_room := public.calc_match_room_id(p_code);
  if (select count(*) from public.match_room_members m where m.room_id = v_room and m.completed_at is not null) < 2 then
    raise exception '두 사람 모두 검사를 마쳐야 영수증을 뽑을 수 있어요.';
  end if;
  if p_photo is null or left(p_photo, 23) <> 'data:image/jpeg;base64,' then
    raise exception '사진 형식을 읽지 못했어요. 다시 찍어주세요. (형식: %)', left(coalesce(p_photo, '없음'), 30);
  end if;
  if char_length(p_photo) > 200000 then
    raise exception '사진이 너무 커요. 다시 찍어주세요. (%자)', char_length(p_photo);
  end if;

  -- 하루 지난 요청(사진)은 지운다
  delete from public.match_print_requests r where r.created_at < now() - interval '24 hours';

  insert into public.match_print_requests (room_id, requested_by, photo, show_on_rank)
  values (v_room, v_uid, p_photo, coalesce(p_show_on_rank, false))
  on conflict (room_id)
  do update set requested_by = excluded.requested_by, photo = excluded.photo, show_on_rank = excluded.show_on_rank, created_at = now(), printed_at = null;
end;
$$;

-- 진행자: 인쇄 대기 목록 (사진은 빼고). 아직 안 뽑은 것 먼저, 오래된 순
create or replace function public.get_match_print_queue(p_passcode text)
returns table (
  request_id bigint,
  code text,
  member_no_a smallint,
  member_no_b smallint,
  nickname_a text,
  nickname_b text,
  score int,
  requested_at timestamptz,
  printed_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
begin
  perform public.calc_match_print_staff(p_passcode);

  return query
  select q.id, r.code, a.member_no, b.member_no, pa.nickname, pb.nickname,
         public.calc_match_score(q.room_id, a.user_id, b.user_id), q.created_at, q.printed_at
  from public.match_print_requests q
  join public.match_rooms r on r.id = q.room_id
  join public.match_room_members a on a.room_id = q.room_id and a.completed_at is not null
  join public.match_room_members b on b.room_id = q.room_id and b.completed_at is not null and b.member_no > a.member_no
  join public.profiles pa on pa.id = a.user_id
  join public.profiles pb on pb.id = b.user_id
  where q.created_at > now() - interval '24 hours'
  order by (q.printed_at is not null), q.created_at;
end;
$$;

-- 진행자: 요청 1건의 사진 (data URL)
create or replace function public.get_match_print_photo(p_passcode text, p_request_id bigint)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform public.calc_match_print_staff(p_passcode);
  return (select q.photo from public.match_print_requests q where q.id = p_request_id);
end;
$$;

-- 진행자: 인쇄를 마친 요청으로 표시한다
create or replace function public.mark_match_printed(p_passcode text, p_request_id bigint)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.calc_match_print_staff(p_passcode);
  update public.match_print_requests set printed_at = now() where id = p_request_id;
end;
$$;

revoke all on function public.calc_match_print_staff(text)             from public, anon, authenticated;
revoke all on function public.request_match_print(text, text, boolean) from public, anon;
revoke all on function public.get_match_print_queue(text)              from public, anon;
revoke all on function public.get_match_print_photo(text, bigint)      from public, anon;
revoke all on function public.mark_match_printed(text, bigint)         from public, anon;
grant execute on function public.request_match_print(text, text, boolean) to authenticated;
grant execute on function public.get_match_print_queue(text)           to authenticated;
grant execute on function public.get_match_print_photo(text, bigint)   to authenticated;
grant execute on function public.mark_match_printed(text, bigint)      to authenticated;

-- 두 사람(p_member_no_a, p_member_no_b)의 PART 1 문항별 답을 나란히 돌려준다 (결과 화면·영수증의 "통한 취향 / 갈린 취향"용).
--   get_match_pair_foods 와 같은 수준으로 연다: 로그인만 확인하고, 방 번호를 아는 사람이 그 방의 답만 본다. 둘 다 검사를 마쳐야 한다.
create or replace function public.get_match_pair_choices(p_code text, p_member_no_a int, p_member_no_b int)
returns table (
  sort_order smallint,
  body text,
  option_a text,
  option_b text,
  a_choice smallint,
  b_choice smallint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_room bigint;
  v_a uuid;
  v_b uuid;
begin
  if auth.uid() is null then
    raise exception '로그인이 필요합니다.';
  end if;
  if p_code is null or p_code !~ '^[0-9]{4}$' then
    raise exception '방 번호는 숫자 4자리예요.';
  end if;

  select r.id into v_room from public.match_rooms r where r.code = p_code;
  if v_room is null then
    raise exception '없는 방 번호예요. 번호를 다시 확인해주세요.';
  end if;

  select m.user_id into v_a
  from public.match_room_members m
  where m.room_id = v_room and m.member_no = p_member_no_a and m.completed_at is not null;
  select m.user_id into v_b
  from public.match_room_members m
  where m.room_id = v_room and m.member_no = p_member_no_b and m.completed_at is not null;
  if v_a is null or v_b is null or v_a = v_b then
    raise exception '두 사람 모두 검사를 마쳐야 결과를 볼 수 있어요.';
  end if;

  return query
  select q.sort_order::smallint, q.body, q.option_a, q.option_b, a.choice, b.choice
  from public.match_questions q
  join public.match_answers a on a.room_id = v_room and a.user_id = v_a and a.question_id = q.id
  join public.match_answers b on b.room_id = v_room and b.user_id = v_b and b.question_id = q.id
  order by q.sort_order;
end;
$$;

revoke all on function public.get_match_pair_choices(text, int, int)    from public, anon;
grant execute on function public.get_match_pair_choices(text, int, int) to authenticated;

-- 랭킹 화면: 손님이 띄워도 된다고 한 사진만, 최근 것부터 (닉네임·궁합 점수·사진). 하루가 지난 것은 빼고 준다
create or replace function public.get_match_rank_photos(p_limit int default 6)
returns table (
  request_id bigint,
  nickname_a text,
  nickname_b text,
  score int,
  photo text
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
  select q.id, pa.nickname, pb.nickname, public.calc_match_score(q.room_id, a.user_id, b.user_id), q.photo
  from public.match_print_requests q
  join public.match_room_members a on a.room_id = q.room_id and a.completed_at is not null
  join public.match_room_members b on b.room_id = q.room_id and b.completed_at is not null and b.member_no > a.member_no
  join public.profiles pa on pa.id = a.user_id
  join public.profiles pb on pb.id = b.user_id
  where q.show_on_rank
    and q.created_at > now() - interval '24 hours'
  order by q.created_at desc
  limit least(greatest(coalesce(p_limit, 6), 1), 12);
end;
$$;

revoke all on function public.get_match_rank_photos(int)    from public, anon;
grant execute on function public.get_match_rank_photos(int) to authenticated;

-- =====================================================================
-- 다른 폰으로 사진 보내기 (PC 에서 검사한 손님용)
--   create_match_photo_token : 방 멤버가 표(token)를 만든다 → 화면에 QR(사진 보내는 주소 + token)로 띄운다
--   get_match_photo_token_info : 사진 보내는 화면이 누구의 결과인지 보여준다 (닉네임·점수만)
--   upload_match_photo_by_token : 로그인하지 않은 폰도 token 으로 그 방의 사진을 올린다 (anon 허용. token 이 곧 권한이라 30분만 유효)
-- =====================================================================

-- 내부: 유효한 token 이면 방 id, 아니면 예외 (30분 지나면 무효)
create or replace function public.calc_match_photo_token_room(p_token uuid)
returns bigint
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_room bigint;
begin
  select t.room_id into v_room
  from public.match_photo_tokens t
  where t.token = p_token and t.created_at > now() - interval '30 minutes';
  if v_room is null then
    raise exception 'QR 코드가 만료됐어요. 결과 화면에서 QR 을 다시 띄워주세요.';
  end if;
  return v_room;
end;
$$;

create or replace function public.create_match_photo_token(p_code text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_room bigint;
  v_token uuid;
begin
  v_room := public.calc_match_room_id(p_code);
  if (select count(*) from public.match_room_members m where m.room_id = v_room and m.completed_at is not null) < 2 then
    raise exception '두 사람 모두 검사를 마쳐야 사진을 올릴 수 있어요.';
  end if;
  -- 오래된 표는 지운다
  delete from public.match_photo_tokens t where t.created_at < now() - interval '1 day';
  insert into public.match_photo_tokens (room_id, created_by) values (v_room, v_uid) returning token into v_token;
  return v_token;
end;
$$;

create or replace function public.get_match_photo_token_info(p_token uuid)
returns table (nickname_a text, nickname_b text, score int)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_room bigint := public.calc_match_photo_token_room(p_token);
begin
  return query
  select pa.nickname, pb.nickname,
         -- 로그인하지 않은 폰도 부르므로 calc_match_score(로그인 필요) 대신 같은 식을 직접 쓴다: 같은 답을 고른 문항 비율
         (
           select round(100.0 * count(*) filter (where x.choice = y.choice) / nullif(count(*), 0))::int
           from public.match_answers x
           join public.match_answers y on y.room_id = x.room_id and y.question_id = x.question_id and y.user_id = b.user_id
           where x.room_id = v_room and x.user_id = a.user_id
         )
  from public.match_room_members a
  join public.match_room_members b on b.room_id = a.room_id and b.member_no > a.member_no and b.completed_at is not null
  join public.profiles pa on pa.id = a.user_id
  join public.profiles pb on pb.id = b.user_id
  where a.room_id = v_room and a.completed_at is not null
  limit 1;
end;
$$;

create or replace function public.upload_match_photo_by_token(p_token uuid, p_photo text, p_show_on_rank boolean default false)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room bigint := public.calc_match_photo_token_room(p_token);
  v_by uuid;
begin
  if p_photo is null or left(p_photo, 23) <> 'data:image/jpeg;base64,' then
    raise exception '사진 형식을 읽지 못했어요. 다시 찍어주세요. (형식: %)', left(coalesce(p_photo, '없음'), 30);
  end if;
  if char_length(p_photo) > 200000 then
    raise exception '사진이 너무 커요. 다시 찍어주세요. (%자)', char_length(p_photo);
  end if;
  select t.created_by into v_by from public.match_photo_tokens t where t.token = p_token;

  delete from public.match_print_requests r where r.created_at < now() - interval '24 hours';

  insert into public.match_print_requests (room_id, requested_by, photo, show_on_rank)
  values (v_room, v_by, p_photo, coalesce(p_show_on_rank, false))
  on conflict (room_id)
  do update set requested_by = excluded.requested_by, photo = excluded.photo, show_on_rank = excluded.show_on_rank, created_at = now(), printed_at = null;
end;
$$;

revoke all on function public.calc_match_photo_token_room(uuid)                   from public, anon, authenticated;
revoke all on function public.create_match_photo_token(text)                      from public, anon;
revoke all on function public.get_match_photo_token_info(uuid)                    from public;
revoke all on function public.upload_match_photo_by_token(uuid, text, boolean)    from public;
grant execute on function public.create_match_photo_token(text)                   to authenticated;
grant execute on function public.get_match_photo_token_info(uuid)                 to anon, authenticated;
grant execute on function public.upload_match_photo_by_token(uuid, text, boolean) to anon, authenticated;

-- 진행자: 오늘(최근 24시간) 현황 — 검사를 마친 팀 수, 사진을 올린 팀 중 인쇄 대기·인쇄한 수 (용지·줄을 가늠하는 용도)
create or replace function public.get_match_print_stats(p_passcode text)
returns table (teams int, waiting int, printed int)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform public.calc_match_print_staff(p_passcode);

  return query
  select
    (
      select count(*)::int from (
        select m.room_id
        from public.match_room_members m
        where m.completed_at > now() - interval '24 hours'
        group by m.room_id
        having count(*) >= 2
      ) t
    ),
    (select count(*)::int from public.match_print_requests q where q.created_at > now() - interval '24 hours' and q.printed_at is null),
    (select count(*)::int from public.match_print_requests q where q.created_at > now() - interval '24 hours' and q.printed_at is not null);
end;
$$;

revoke all on function public.get_match_print_stats(text)    from public, anon;
grant execute on function public.get_match_print_stats(text) to authenticated;

-- 궁합 결과의 "둘이 같이 가볼 만한 곳": 두 사람의 취향 일치도를 평균해 높은 브랜드부터, 브랜드마다 지점 1곳(내 지역에 있으면 그 지점)을 돌려준다.
--   방 멤버만 부를 수 있다. 상대에 대해서는 브랜드별 일치도(%)만 돌려준다. 둘 다 입맛 정보가 없으면 일치도는 0 이고 평점 순으로 나온다.
create or replace function public.get_match_pair_places(p_code text, p_member_no int, p_limit int default 3)
returns table (
  restaurant_id bigint,
  restaurant_name text,
  brand_name text,
  category_name text,
  region text,
  pair_match int,
  my_match int,
  friend_match int
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_uid uuid := auth.uid();
  v_room bigint := public.calc_match_room_id(p_code);
  v_friend uuid;
  v_region text;
begin
  select m.user_id into v_friend
  from public.match_room_members m
  where m.room_id = v_room and m.member_no = p_member_no and m.user_id <> v_uid and m.completed_at is not null;
  if v_friend is null then
    raise exception '친구가 검사를 마치면 볼 수 있어요.';
  end if;
  select p.region into v_region from public.profiles p where p.id = v_uid;

  return query
  select x.restaurant_id, x.restaurant_name, x.brand_name, x.category_name, x.region,
         round((x.my_match + x.friend_match) / 2.0)::int, x.my_match, x.friend_match
  from (
    select b.id as brand_id,
           b.name as brand_name,
           c.name as category_name,
           pick.id as restaurant_id,
           pick.name as restaurant_name,
           pick.region as region,
           coalesce((select round(avg(public.calc_menu_match(v_uid, m.id)))::int from public.menus m where m.brand_id = b.id), 0) as my_match,
           coalesce((select round(avg(public.calc_menu_match(v_friend, m.id)))::int from public.menus m where m.brand_id = b.id), 0) as friend_match,
           bs.avg_rating as avg_rating
    from public.brands b
    left join public.food_categories c on c.id = b.category_id
    left join public.brand_stats bs on bs.brand_id = b.id
    cross join lateral (
      -- 내 지역의 지점을 먼저, 없으면 아무 지점이나 하나
      select r.id, r.name, r.region
      from public.restaurants r
      where r.brand_id = b.id
      order by (r.region is not distinct from v_region) desc, r.id
      limit 1
    ) pick
    where exists (select 1 from public.menus m where m.brand_id = b.id)
  ) x
  order by (x.my_match + x.friend_match) desc, x.avg_rating desc nulls last, x.brand_id
  limit least(greatest(coalesce(p_limit, 3), 1), 10);
end;
$$;

revoke all on function public.get_match_pair_places(text, int, int)    from public, anon;
grant execute on function public.get_match_pair_places(text, int, int) to authenticated;

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
