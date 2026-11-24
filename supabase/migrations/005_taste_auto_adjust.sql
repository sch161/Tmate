-- =====================================================================
-- 005_taste_auto_adjust.sql — 평가로 입맛 자동 보정
--   고른 입맛 비율에 "평가로 본 입맛"을 섞은 "지금 입맛"으로 취향 일치도·추천 이유·입맛 유형을 계산한다.
--   계산식과 상수(taste_learn_per_review, taste_learn_max)는 functions.sql 머리말 참고.
--   새 함수: calc_taste_profile(내부), get_my_taste_profile(화면용)
--   바뀌는 함수(반환 형태는 그대로): calc_setting, calc_content_match, calc_menu_reason, calc_taste_type, get_my_summary
--   * 테이블·데이터는 건드리지 않는다. create or replace 라 재실행해도 안전하다.
--   * 되돌리려면 이전 functions.sql 을 다시 실행한다 (저장된 값이 없어 되돌려도 잃는 데이터가 없다).
-- 실행 순서: functions.sql 이 이미 적용된 DB 에 이 파일 하나만 실행한다.
--   (functions.sql 을 통째로 다시 실행해도 같은 결과다. 아래 함수는 functions.sql 의 것과 같다.)
--   실행 후 `npm run gen:types` 로 src/types/database.types.ts 를 다시 만든다.
-- =====================================================================
begin;

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
    when 'match_room_max'       then 6
    when 'match_food_count'     then 5
    when 'match_room_keep_days' then 7
  end;

  if v_value is null then
    raise exception '알 수 없는 설정 값이에요: %', p_key;
  end if;
  return v_value;
end;
$$;

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

revoke all on function public.calc_taste_profile(uuid)      from public, anon, authenticated;
revoke all on function public.get_my_taste_profile()        from public, anon;
grant execute on function public.get_my_taste_profile()     to authenticated;

commit;
