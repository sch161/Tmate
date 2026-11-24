-- =====================================================================
-- 017_match_set_based.sql — 메뉴 일치도를 한 번에 계산해 목록·추천·상세를 빠르게 한다
--   새 내부 함수 calc_menu_matches(사용자의 모든 메뉴 일치도. calc_menu_match_detail 과 같은 값)를 만들고,
--   get_restaurants · get_recommended_menus · get_restaurant_detail · get_restaurant_menus · get_match_pair_places 가 그것을 쓰게 한다.
--   반환 형태·값·테이블·데이터는 그대로다. create or replace 라 재실행해도 안전하다. functions.sql 의 것과 같다.
--   (functions.sql 을 통째로 다시 실행해도 같은 결과다.)
-- =====================================================================
begin;

create or replace function public.calc_menu_matches(p_user uuid)
returns table (menu_id bigint, match int, neighbor_count int, neighbor_avg numeric)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_use_collab boolean;
  v_min numeric;
  v_sim numeric;
  v_w_collab numeric;
  v_w_content numeric;
begin
  if auth.uid() is null then
    raise exception '로그인이 필요합니다.';
  end if;

  v_use_collab := (select count(*) from public.reviews r where r.user_id = p_user) >= public.calc_setting('collab_min_reviews');
  v_min := public.calc_setting('min_common');
  v_sim := public.calc_setting('mate_similarity');
  v_w_collab := public.calc_setting('collab_weight');
  v_w_content := public.calc_setting('content_weight');

  return query
  with profile as (
    select tp.taste_tag_id, tp.ratio from public.calc_taste_profile(p_user) tp
  ),
  content as (
    select m.id as menu_id, coalesce(sum(pf.ratio), 0)::int as content
    from public.menus m
    left join public.menu_taste_tags mtt on mtt.menu_id = m.id
    left join profile pf on pf.taste_tag_id = mtt.taste_tag_id
    group by m.id
  ),
  -- 유사도 기준 이상인 이웃 (공통 평가 메뉴가 min_common 개 이상)
  neighbors as (
    select rb.user_id as user_id, 1 - (avg(abs(ra.rating - rb.rating)) / 4) as sim
    from public.reviews ra
    join public.reviews rb on rb.menu_id = ra.menu_id
    where v_use_collab and ra.user_id = p_user and rb.user_id <> p_user
    group by rb.user_id
    having count(*) >= v_min and 1 - (avg(abs(ra.rating - rb.rating)) / 4) >= v_sim
  ),
  collab as (
    select r.menu_id as menu_id,
           count(*)::int as n,
           round(avg(r.rating), 1) as avg_rating,
           sum(nb.sim * r.rating) / sum(nb.sim) as pred
    from public.reviews r
    join neighbors nb on nb.user_id = r.user_id
    group by r.menu_id
  )
  select c.menu_id,
         case when cb.n is null then c.content
              else round((((cb.pred - 1) / 4 * 100) * v_w_collab + c.content * v_w_content) / (v_w_collab + v_w_content))::int end,
         coalesce(cb.n, 0),
         cb.avg_rating
  from content c
  left join collab cb on cb.menu_id = c.menu_id;
end;
$$;

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
           bb.category_name as category_name,
           -- 같은 브랜드 지점이 줄지어 나오지 않게, 브랜드 안에서의 순번을 매긴다
           row_number() over (partition by bb.brand_id order by bb.restaurant_id) as brand_rank
    from base bb
    join brand_info bi on bi.brand_id = bb.brand_id
    left join brand_match bm on bm.brand_id = bb.brand_id
  ) x
  -- 브랜드마다 한 곳씩 먼저(일치도 높은 브랜드부터), 그다음 두 번째 지점들 … 순서로 섞어 다양하게 보여준다
  order by x.brand_rank, x.match_percent desc, x.avg_rating desc nulls last, x.restaurant_id
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
    join public.calc_menu_matches(v_uid) d on d.menu_id = m.id
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
    join public.calc_menu_matches(v_uid) d on d.menu_id = m.id
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
    join public.calc_menu_matches(v_uid) d on d.menu_id = m.id
    where rr.id = p_restaurant_id
  ) x
  order by x.match_percent desc, x.menu_id;
end;
$$;

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
  with mine as materialized (
    select mm.menu_id, mm.match from public.calc_menu_matches(v_uid) mm
  ),
  theirs as materialized (
    select mm.menu_id, mm.match from public.calc_menu_matches(v_friend) mm
  )
  select x.restaurant_id, x.restaurant_name, x.brand_name, x.category_name, x.region,
         round((x.my_match + x.friend_match) / 2.0)::int, x.my_match, x.friend_match
  from (
    select b.id as brand_id,
           b.name as brand_name,
           c.name as category_name,
           pick.id as restaurant_id,
           pick.name as restaurant_name,
           pick.region as region,
           coalesce((select round(avg(mm.match))::int from public.menus m join mine mm on mm.menu_id = m.id where m.brand_id = b.id), 0) as my_match,
           coalesce((select round(avg(mm.match))::int from public.menus m join theirs mm on mm.menu_id = m.id where m.brand_id = b.id), 0) as friend_match,
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

revoke all on function public.calc_menu_matches(uuid) from public, anon, authenticated;

commit;
