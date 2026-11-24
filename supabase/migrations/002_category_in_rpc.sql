-- =====================================================================
-- 002_category_in_rpc.sql — 화면용 RPC 4개에 category_name(음식 카테고리 이름: 한식/중식/일식/양식) 컬럼을 "추가"한다.
--   * 기존 컬럼은 이름·타입·순서 그대로 두고 맨 끝에 category_name text 만 붙인다 → 이전 앱 코드가 깨지지 않는다.
--   * 반환 타입이 바뀌므로 create or replace 가 안 된다 → drop 후 create. 한 트랜잭션이라 중간에 함수가 없는 순간이 보이지 않는다.
--   * 대상: get_restaurants, get_recommended_menus, get_restaurant_detail, get_my_reviews. 본문은 functions.sql 과 같다.
--   * 권한은 functions.sql 과 똑같이 다시 준다 (public·anon 회수, authenticated 실행). 함수는 모두 security definer + search_path ''.
--   * brands.category_id 가 null 이면 category_name 도 null 이다 (앱은 이 경우 기본 색 박스를 쓴다).
-- 실행: Supabase SQL Editor 에서 이 파일을 통째로 한 번 실행한다. 재실행해도 안전하다. 그 다음 앱 코드를 배포한다.
--   배포 후 `npm run gen:types` 로 src/types/database.types.ts 를 다시 만든다 (현재 파일은 같은 내용으로 손으로 갱신해 둠).
-- =====================================================================
begin;

drop function if exists public.get_restaurants(text, int, text, int);
drop function if exists public.get_recommended_menus(text, int);
drop function if exists public.get_restaurant_detail(bigint);
drop function if exists public.get_my_reviews();

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

revoke all on function public.get_restaurants(text, int, text, int) from public, anon;
revoke all on function public.get_recommended_menus(text, int) from public, anon;
revoke all on function public.get_restaurant_detail(bigint) from public, anon;
revoke all on function public.get_my_reviews() from public, anon;
grant execute on function public.get_restaurants(text, int, text, int) to authenticated;
grant execute on function public.get_recommended_menus(text, int) to authenticated;
grant execute on function public.get_restaurant_detail(bigint) to authenticated;
grant execute on function public.get_my_reviews() to authenticated;

commit;
