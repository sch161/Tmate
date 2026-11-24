-- =====================================================================
-- 013_store_add_menus.sql — 내가 추가한 가게에 메뉴 더 넣기
--   새 RPC is_my_store · begin_store_menu_add · add_user_store_menus (내부 calc_my_store_brand · calc_insert_user_menus).
--   add_user_store 는 메뉴 저장 부분을 calc_insert_user_menus 로 옮겼을 뿐 동작은 같다. calc_setting 에 store_menu_total_max 를 더한다.
--   테이블·데이터는 건드리지 않는다. create or replace 라 재실행해도 안전하다. functions.sql 의 것과 같다.
-- 실행 순서: 012_match_print_stats.sql 까지 적용된 DB 에 이 파일 하나만 실행한다. 실행 후 `npm run gen:types`.
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

commit;
