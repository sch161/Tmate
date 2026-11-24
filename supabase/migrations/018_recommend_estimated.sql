-- =====================================================================
-- 018_recommend_estimated.sql — 알레르기를 등록한 사용자의 추천에 AI 추정(estimated) 메뉴를 포함한다
--   내 알레르기와 겹치는 메뉴와 정보 없음(unknown) 메뉴는 그대로 제외한다. 화면은 추정 메뉴에 "알레르기 추정 · 가게 확인"을 붙인다.
--   get_recommended_menus 의 조건 한 줄만 바뀐다. 반환 형태·테이블·데이터는 그대로다. 재실행해도 안전하다.
-- =====================================================================
begin;

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
      and (not v_has_allergy or m.allergen_status in ('verified', 'official_extract', 'estimated'))
  ) x
  order by x.match_percent desc, x.avg_rating desc nulls last, x.menu_id
  limit v_limit;
end;
$$;

commit;
