-- =====================================================================
-- 014_match_pair_places.sql — 궁합 결과의 "둘이 같이 가볼 만한 곳" RPC 1개 추가
--   테이블·데이터는 건드리지 않는다. create or replace 라 재실행해도 안전하다. functions.sql 의 것과 같다.
-- 실행 순서: 013_store_add_menus.sql 까지 적용된 DB 에 이 파일 하나만 실행한다. 실행 후 `npm run gen:types`.
-- =====================================================================
begin;

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

commit;
