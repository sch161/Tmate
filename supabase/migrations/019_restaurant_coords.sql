-- =====================================================================
-- 019_restaurant_coords.sql — 가게 좌표와 가까운 순 정렬
--   * restaurants 에 lat·lng(WGS84) 열을 추가한다. 값은 seed_branch_coords.sql 이 채운다(공공데이터의 위도·경도).
--   * get_restaurants 에 p_lat·p_lng 를 추가한다. 주면 가까운 순으로 정렬하고 distance_m 을 돌려준다. 본문은 functions.sql 과 같다.
--   * 데이터를 지우지 않는다. 여러 번 실행해도 안전하다.
-- 실행 순서: 이 파일 → seed_branch_coords.sql
-- =====================================================================
alter table public.restaurants add column if not exists lat double precision;
alter table public.restaurants add column if not exists lng double precision;

drop function if exists public.get_restaurants(text, int, text, int);
drop function if exists public.get_restaurants(text, int, text, int, double precision, double precision);

create or replace function public.get_restaurants(
  p_region text,
  p_category_id int default null,
  p_query text default null,
  p_limit int default 20,
  p_lat double precision default null,
  p_lng double precision default null
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
  category_name text,
  distance_m int
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
  v_near boolean := p_lat is not null and p_lng is not null and p_lat between -90 and 90 and p_lng between -180 and 180;
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
           fc.name as category_name,
           -- 하버사인 공식으로 구한 직선 거리(m)
           case when v_near and r.lat is not null and r.lng is not null then
             round(6371000 * 2 * asin(least(1, sqrt(
               power(sin(radians(r.lat - p_lat) / 2), 2)
               + cos(radians(p_lat)) * cos(radians(r.lat)) * power(sin(radians(r.lng - p_lng) / 2), 2)
             ))))::int
           end as distance_m
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
    join public.calc_menu_matches(v_uid) d on d.menu_id = m.id
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
         x.brand_id, x.brand_name, x.is_franchise, x.has_official_allergen, x.category_name, x.distance_m
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
           bb.category_name as category_name,
           bb.distance_m as distance_m,
           -- 같은 브랜드 지점이 줄지어 나오지 않게, 브랜드 안에서의 순번을 매긴다
           row_number() over (partition by bb.brand_id order by bb.restaurant_id) as brand_rank
    from base bb
    join brand_info bi on bi.brand_id = bb.brand_id
    left join brand_match bm on bm.brand_id = bb.brand_id
  ) x
  -- 브랜드마다 한 곳씩 먼저(일치도 높은 브랜드부터), 그다음 두 번째 지점들 … 순서로 섞어 다양하게 보여준다
  -- 내 위치를 받았으면 가까운 순이 먼저다 (위치가 없으면 distance_m 이 모두 null 이라 아래 순서만 남는다)
  order by x.distance_m nulls last, x.brand_rank, x.match_percent desc, x.avg_rating desc nulls last, x.restaurant_id
  limit v_limit;
end;
$$;

revoke all on function public.get_restaurants(text, int, text, int, double precision, double precision) from public, anon;
grant execute on function public.get_restaurants(text, int, text, int, double precision, double precision) to authenticated;
