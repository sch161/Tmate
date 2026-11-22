-- =====================================================================
-- seed_brand_menus.sql — 브랜드 조사 결과(brands·menus·menu_allergens·menu_taste_tags). scripts/import/build-brand-menus.mjs 가 생성, 직접 수정하지 않는다.
-- 멱등: menus 는 (brand_id, name) upsert, menu_allergens·menu_taste_tags 는 메뉴별로 지우고 다시 넣는다.
-- 실행 순서: seed_branches.sql 먼저(브랜드가 없으면 아래에서 예외) → 이 파일
-- =====================================================================
begin;

-- ===== 맥도날드 (메뉴 10개) =====
do $$
begin
  if not exists (select 1 from brands b where b.name = '맥도날드' and b.is_franchise) then
    raise exception '브랜드 맥도날드 이(가) 없어요. seed_branches.sql 을 먼저 실행하세요.';
  end if;
end;
$$;
update brands b set
  allergen_source_url = 'https://www.mcdonalds.co.kr/kor/menu/information/allergens', allergen_data_date = null::date,
  shared_notice = '일부 튀김류 제품은 새우 패티와 같은 조리 기구를 사용하고 있습니다 / 그릴드 치킨 패티는 돼지고기를 사용한 제품과 같은 조리 기구를 사용합니다. / 지점에 따라 판매하지 않는 제품이 있을 수 있음', research_status = 'done', researched_at = now(), research_error = null
where b.name = '맥도날드' and b.is_franchise;

-- 맥도날드 / 빅맥
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '빅맥', '푸짐하게 즐기는 대표 버거', 'official_extract'::allergen_status, 'https://www.mcdonalds.co.kr/kor/menu/information/allergens', '2026-11-22T18:14:20.082Z'::timestamptz, '맛 태그는 추정.', 'https://www.mcdonalds.co.kr/kor/menu/information/allergens', '공식 사이트'
from brands b where b.name = '맥도날드' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '맥도날드' and b.is_franchise and m.name = '빅맥');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('알류', 'danger', '난류'), ('우유', 'danger', '우유'), ('대두', 'danger', '대두'), ('밀', 'danger', '밀'), ('쇠고기', 'danger', '쇠고기')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '맥도날드' and b.is_franchise and m.name = '빅맥';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '맥도날드' and b.is_franchise and m.name = '빅맥');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('짭조름함'), ('고소함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '맥도날드' and b.is_franchise and m.name = '빅맥';

-- 맥도날드 / 맥스파이시 상하이버거
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '맥스파이시 상하이버거', '매콤하게 즐기는 치킨 버거', 'official_extract'::allergen_status, 'https://www.mcdonalds.co.kr/kor/menu/information/allergens', '2026-11-22T18:14:20.082Z'::timestamptz, '맛 태그는 추정.', 'https://www.mcdonalds.co.kr/kor/menu/information/allergens', '공식 사이트'
from brands b where b.name = '맥도날드' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '맥도날드' and b.is_franchise and m.name = '맥스파이시 상하이버거');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('알류', 'danger', '난류'), ('대두', 'danger', '대두'), ('밀', 'danger', '밀'), ('토마토', 'danger', '토마토'), ('닭고기', 'danger', '닭고기')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '맥도날드' and b.is_franchise and m.name = '맥스파이시 상하이버거';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '맥도날드' and b.is_franchise and m.name = '맥스파이시 상하이버거');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('매콤함'), ('짭조름함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '맥도날드' and b.is_franchise and m.name = '맥스파이시 상하이버거';

-- 맥도날드 / 1955 버거
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '1955 버거', '진한 풍미로 즐기는 버거', 'official_extract'::allergen_status, 'https://www.mcdonalds.co.kr/kor/menu/information/allergens', '2026-11-22T18:14:20.082Z'::timestamptz, '맛 태그는 추정.', 'https://www.mcdonalds.co.kr/kor/menu/information/allergens', '공식 사이트'
from brands b where b.name = '맥도날드' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '맥도날드' and b.is_franchise and m.name = '1955 버거');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('알류', 'danger', '난류'), ('우유', 'danger', '우유'), ('대두', 'danger', '대두'), ('밀', 'danger', '밀'), ('돼지고기', 'danger', '돼지고기'), ('토마토', 'danger', '토마토'), ('쇠고기', 'danger', '쇠고기')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '맥도날드' and b.is_franchise and m.name = '1955 버거';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '맥도날드' and b.is_franchise and m.name = '1955 버거');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('감칠맛'), ('짭조름함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '맥도날드' and b.is_franchise and m.name = '1955 버거';

-- 맥도날드 / 맥치킨
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '맥치킨', '간편하게 즐기는 치킨 버거', 'official_extract'::allergen_status, 'https://www.mcdonalds.co.kr/kor/menu/information/allergens', '2026-11-22T18:14:20.082Z'::timestamptz, '맛 태그는 추정.', 'https://www.mcdonalds.co.kr/kor/menu/information/allergens', '공식 사이트'
from brands b where b.name = '맥도날드' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '맥도날드' and b.is_franchise and m.name = '맥치킨');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('알류', 'danger', '난류'), ('대두', 'danger', '대두'), ('밀', 'danger', '밀'), ('닭고기', 'danger', '닭고기')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '맥도날드' and b.is_franchise and m.name = '맥치킨';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '맥도날드' and b.is_franchise and m.name = '맥치킨');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('짭조름함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '맥도날드' and b.is_franchise and m.name = '맥치킨';

-- 맥도날드 / 더블 불고기버거
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '더블 불고기버거', '달큰하고 든든한 버거', 'official_extract'::allergen_status, 'https://www.mcdonalds.co.kr/kor/menu/information/allergens', '2026-11-22T18:14:20.082Z'::timestamptz, '조개와 굴은 공식 표기대로 각각 기록. 맛 태그는 추정.', 'https://www.mcdonalds.co.kr/kor/menu/information/allergens', '공식 사이트'
from brands b where b.name = '맥도날드' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '맥도날드' and b.is_franchise and m.name = '더블 불고기버거');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('알류', 'danger', '난류'), ('우유', 'danger', '우유'), ('대두', 'danger', '대두'), ('밀', 'danger', '밀'), ('돼지고기', 'danger', '돼지고기'), ('조개류', 'danger', '조개 / 굴')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '맥도날드' and b.is_franchise and m.name = '더블 불고기버거';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '맥도날드' and b.is_franchise and m.name = '더블 불고기버거');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('달콤함'), ('감칠맛')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '맥도날드' and b.is_franchise and m.name = '더블 불고기버거';

-- 맥도날드 / 불고기버거
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '불고기버거', '달큰한 소스 맛의 버거', 'official_extract'::allergen_status, 'https://www.mcdonalds.co.kr/kor/menu/information/allergens', '2026-11-22T18:14:20.082Z'::timestamptz, '조개와 굴은 공식 표기대로 각각 기록. 맛 태그는 추정.', 'https://www.mcdonalds.co.kr/kor/menu/information/allergens', '공식 사이트'
from brands b where b.name = '맥도날드' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '맥도날드' and b.is_franchise and m.name = '불고기버거');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('알류', 'danger', '난류'), ('대두', 'danger', '대두'), ('밀', 'danger', '밀'), ('돼지고기', 'danger', '돼지고기'), ('조개류', 'danger', '조개 / 굴')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '맥도날드' and b.is_franchise and m.name = '불고기버거';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '맥도날드' and b.is_franchise and m.name = '불고기버거');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('달콤함'), ('짭조름함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '맥도날드' and b.is_franchise and m.name = '불고기버거';

-- 맥도날드 / 슈슈버거
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '슈슈버거', '고소한 풍미를 즐기는 버거', 'official_extract'::allergen_status, 'https://www.mcdonalds.co.kr/kor/menu/information/allergens', '2026-11-22T18:14:20.082Z'::timestamptz, '맛 태그는 추정.', 'https://www.mcdonalds.co.kr/kor/menu/information/allergens', '공식 사이트'
from brands b where b.name = '맥도날드' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '맥도날드' and b.is_franchise and m.name = '슈슈버거');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('알류', 'danger', '난류'), ('우유', 'danger', '우유'), ('대두', 'danger', '대두'), ('밀', 'danger', '밀'), ('토마토', 'danger', '토마토'), ('새우', 'danger', '새우'), ('쇠고기', 'danger', '쇠고기'), ('조개류', 'danger', '굴')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '맥도날드' and b.is_franchise and m.name = '슈슈버거';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '맥도날드' and b.is_franchise and m.name = '슈슈버거');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('감칠맛')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '맥도날드' and b.is_franchise and m.name = '슈슈버거';

-- 맥도날드 / 슈비버거
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '슈비버거', '다채로운 풍미의 버거', 'official_extract'::allergen_status, 'https://www.mcdonalds.co.kr/kor/menu/information/allergens', '2026-11-22T18:14:20.082Z'::timestamptz, '맛 태그는 추정.', 'https://www.mcdonalds.co.kr/kor/menu/information/allergens', '공식 사이트'
from brands b where b.name = '맥도날드' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '맥도날드' and b.is_franchise and m.name = '슈비버거');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('알류', 'danger', '난류'), ('우유', 'danger', '우유'), ('대두', 'danger', '대두'), ('밀', 'danger', '밀'), ('토마토', 'danger', '토마토'), ('새우', 'danger', '새우'), ('쇠고기', 'danger', '쇠고기'), ('조개류', 'danger', '굴')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '맥도날드' and b.is_franchise and m.name = '슈비버거';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '맥도날드' and b.is_franchise and m.name = '슈비버거');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('감칠맛')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '맥도날드' and b.is_franchise and m.name = '슈비버거';

-- 맥도날드 / 쿼터파운더치즈
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '쿼터파운더치즈', '고소하고 진한 치즈 버거', 'official_extract'::allergen_status, 'https://www.mcdonalds.co.kr/kor/menu/information/allergens', '2026-11-22T18:14:20.082Z'::timestamptz, '맛 태그는 추정.', 'https://www.mcdonalds.co.kr/kor/menu/information/allergens', '공식 사이트'
from brands b where b.name = '맥도날드' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '맥도날드' and b.is_franchise and m.name = '쿼터파운더치즈');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('우유', 'danger', '우유'), ('대두', 'danger', '대두'), ('밀', 'danger', '밀'), ('토마토', 'danger', '토마토'), ('쇠고기', 'danger', '쇠고기')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '맥도날드' and b.is_franchise and m.name = '쿼터파운더치즈';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '맥도날드' and b.is_franchise and m.name = '쿼터파운더치즈');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('짭조름함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '맥도날드' and b.is_franchise and m.name = '쿼터파운더치즈';

-- 맥도날드 / 베이컨 토마토 디럭스
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '베이컨 토마토 디럭스', '짭조름하고 풍성한 버거', 'official_extract'::allergen_status, 'https://www.mcdonalds.co.kr/kor/menu/information/allergens', '2026-11-22T18:14:20.082Z'::timestamptz, '맛 태그는 추정.', 'https://www.mcdonalds.co.kr/kor/menu/information/allergens', '공식 사이트'
from brands b where b.name = '맥도날드' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '맥도날드' and b.is_franchise and m.name = '베이컨 토마토 디럭스');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('알류', 'danger', '난류'), ('우유', 'danger', '우유'), ('대두', 'danger', '대두'), ('밀', 'danger', '밀'), ('돼지고기', 'danger', '돼지고기'), ('토마토', 'danger', '토마토'), ('쇠고기', 'danger', '쇠고기')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '맥도날드' and b.is_franchise and m.name = '베이컨 토마토 디럭스';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '맥도날드' and b.is_franchise and m.name = '베이컨 토마토 디럭스');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('짭조름함'), ('감칠맛')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '맥도날드' and b.is_franchise and m.name = '베이컨 토마토 디럭스';

-- ===== 롯데리아 (메뉴 10개) =====
do $$
begin
  if not exists (select 1 from brands b where b.name = '롯데리아' and b.is_franchise) then
    raise exception '브랜드 롯데리아 이(가) 없어요. seed_branches.sql 을 먼저 실행하세요.';
  end if;
end;
$$;
update brands b set
  allergen_source_url = 'https://www.lotteeatz.com/upload/etc/ria/items.html', allergen_data_date = '2026-11-20'::date,
  shared_notice = '※ 조리제품은 알류(달걀), 밀, 대두, 우유, 쇠고기, 닭고기, 토마토, 아황산류, 복숭아, 새우, 돼지고기, 조개류(굴,가리비), 오징어, 땅콩, 게가 포함된 제품과 같은 조리기구를 사용하고 있습니다. / 지점에 따라 판매하지 않는 제품이 있을 수 있음', research_status = 'done', researched_at = now(), research_error = null
where b.name = '롯데리아' and b.is_franchise;

-- 롯데리아 / 한우불고기버거 세트
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '한우불고기버거 세트', '한우 풍미를 담은 버거', 'verified'::allergen_status, 'https://www.lotteeatz.com/upload/etc/ria/items.html', '2026-11-22T18:14:20.082Z'::timestamptz, '공식 표는 세트 구성 기준이며 구성에 따라 알레르기가 다를 수 있습니다', 'https://www.lotteeatz.com/upload/etc/ria/items.html', '공식 사이트'
from brands b where b.name = '롯데리아' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '롯데리아' and b.is_franchise and m.name = '한우불고기버거 세트');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('알류', 'danger', '달걀'), ('밀', 'danger', '밀'), ('대두', 'danger', '대두'), ('우유', 'danger', '우유'), ('쇠고기', 'danger', '쇠고기'), ('토마토', 'danger', '토마토')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '롯데리아' and b.is_franchise and m.name = '한우불고기버거 세트';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '롯데리아' and b.is_franchise and m.name = '한우불고기버거 세트');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('달콤함'), ('감칠맛')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '롯데리아' and b.is_franchise and m.name = '한우불고기버거 세트';

-- 롯데리아 / 리아 불고기 세트
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '리아 불고기 세트', '달큰한 풍미의 고기 버거', 'verified'::allergen_status, 'https://www.lotteeatz.com/upload/etc/ria/items.html', '2026-11-22T18:14:20.082Z'::timestamptz, '공식 표는 세트 구성 기준이며 구성에 따라 알레르기가 다를 수 있습니다', 'https://www.lotteeatz.com/upload/etc/ria/items.html', '공식 사이트'
from brands b where b.name = '롯데리아' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '롯데리아' and b.is_franchise and m.name = '리아 불고기 세트');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('밀', 'danger', '밀'), ('대두', 'danger', '대두'), ('알류', 'danger', '달걀'), ('우유', 'danger', '우유'), ('쇠고기', 'danger', '쇠고기'), ('토마토', 'danger', '토마토'), ('돼지고기', 'danger', '돼지고기'), ('닭고기', 'danger', '닭고기')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '롯데리아' and b.is_franchise and m.name = '리아 불고기 세트';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '롯데리아' and b.is_franchise and m.name = '리아 불고기 세트');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('달콤함'), ('짭조름함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '롯데리아' and b.is_franchise and m.name = '리아 불고기 세트';

-- 롯데리아 / 리아 새우 세트
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '리아 새우 세트', '새우 풍미가 도는 버거', 'verified'::allergen_status, 'https://www.lotteeatz.com/upload/etc/ria/items.html', '2026-11-22T18:14:20.082Z'::timestamptz, '공식 표는 세트 구성 기준이며 구성에 따라 알레르기가 다를 수 있습니다', 'https://www.lotteeatz.com/upload/etc/ria/items.html', '공식 사이트'
from brands b where b.name = '롯데리아' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '롯데리아' and b.is_franchise and m.name = '리아 새우 세트');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('알류', 'danger', '달걀'), ('밀', 'danger', '밀'), ('대두', 'danger', '대두'), ('우유', 'danger', '우유'), ('토마토', 'danger', '토마토'), ('새우', 'danger', '새우')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '롯데리아' and b.is_franchise and m.name = '리아 새우 세트';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '롯데리아' and b.is_franchise and m.name = '리아 새우 세트');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('감칠맛')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '롯데리아' and b.is_franchise and m.name = '리아 새우 세트';

-- 롯데리아 / 리아 사각새우 더블 세트
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '리아 사각새우 더블 세트', '겹겹이 즐기는 새우 버거', 'verified'::allergen_status, 'https://www.lotteeatz.com/upload/etc/ria/items.html', '2026-11-22T18:14:20.082Z'::timestamptz, '공식 표는 세트 구성 기준이며 구성에 따라 알레르기가 다를 수 있습니다', 'https://www.lotteeatz.com/upload/etc/ria/items.html', '공식 사이트'
from brands b where b.name = '롯데리아' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '롯데리아' and b.is_franchise and m.name = '리아 사각새우 더블 세트');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('알류', 'danger', '달걀'), ('밀', 'danger', '밀'), ('대두', 'danger', '대두'), ('우유', 'danger', '우유'), ('토마토', 'danger', '토마토'), ('새우', 'danger', '새우')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '롯데리아' and b.is_franchise and m.name = '리아 사각새우 더블 세트';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '롯데리아' and b.is_franchise and m.name = '리아 사각새우 더블 세트');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('짭조름함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '롯데리아' and b.is_franchise and m.name = '리아 사각새우 더블 세트';

-- 롯데리아 / 모짜렐라 인 더 버거 베이컨 세트
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '모짜렐라 인 더 버거 베이컨 세트', '치즈와 베이컨의 조합', 'verified'::allergen_status, 'https://www.lotteeatz.com/upload/etc/ria/items.html', '2026-11-22T18:14:20.082Z'::timestamptz, '공식 표는 세트 구성 기준이며 구성에 따라 알레르기가 다를 수 있습니다', 'https://www.lotteeatz.com/upload/etc/ria/items.html', '공식 사이트'
from brands b where b.name = '롯데리아' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '롯데리아' and b.is_franchise and m.name = '모짜렐라 인 더 버거 베이컨 세트');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('알류', 'danger', '달걀'), ('밀', 'danger', '밀'), ('대두', 'danger', '대두'), ('우유', 'danger', '우유'), ('쇠고기', 'danger', '쇠고기'), ('돼지고기', 'danger', '돼지고기')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '롯데리아' and b.is_franchise and m.name = '모짜렐라 인 더 버거 베이컨 세트';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '롯데리아' and b.is_franchise and m.name = '모짜렐라 인 더 버거 베이컨 세트');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('짭조름함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '롯데리아' and b.is_franchise and m.name = '모짜렐라 인 더 버거 베이컨 세트';

-- 롯데리아 / 전주비빔라이스버거 세트
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '전주비빔라이스버거 세트', '비빔밥 풍미의 밥 버거', 'verified'::allergen_status, 'https://www.lotteeatz.com/upload/etc/ria/items.html', '2026-11-22T18:14:20.082Z'::timestamptz, '공식 표는 세트 구성 기준이며 구성에 따라 알레르기가 다를 수 있습니다', 'https://www.lotteeatz.com/upload/etc/ria/items.html', '공식 사이트'
from brands b where b.name = '롯데리아' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '롯데리아' and b.is_franchise and m.name = '전주비빔라이스버거 세트');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('알류', 'danger', '달걀'), ('밀', 'danger', '밀'), ('대두', 'danger', '대두'), ('쇠고기', 'danger', '쇠고기')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '롯데리아' and b.is_franchise and m.name = '전주비빔라이스버거 세트';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '롯데리아' and b.is_franchise and m.name = '전주비빔라이스버거 세트');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('매콤함'), ('감칠맛')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '롯데리아' and b.is_franchise and m.name = '전주비빔라이스버거 세트';

-- 롯데리아 / 더블엑스투버거 세트
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '더블엑스투버거 세트', '묵직한 풍미의 더블 버거', 'verified'::allergen_status, 'https://www.lotteeatz.com/upload/etc/ria/items.html', '2026-11-22T18:14:20.082Z'::timestamptz, '공식 표는 세트 구성 기준이며 구성에 따라 알레르기가 다를 수 있습니다', 'https://www.lotteeatz.com/upload/etc/ria/items.html', '공식 사이트'
from brands b where b.name = '롯데리아' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '롯데리아' and b.is_franchise and m.name = '더블엑스투버거 세트');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('알류', 'danger', '달걀'), ('밀', 'danger', '밀'), ('대두', 'danger', '대두'), ('우유', 'danger', '우유'), ('쇠고기', 'danger', '쇠고기'), ('토마토', 'danger', '토마토')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '롯데리아' and b.is_franchise and m.name = '더블엑스투버거 세트';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '롯데리아' and b.is_franchise and m.name = '더블엑스투버거 세트');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('감칠맛')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '롯데리아' and b.is_franchise and m.name = '더블엑스투버거 세트';

-- 롯데리아 / 핫크리스피치킨버거 세트
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '핫크리스피치킨버거 세트', '매콤하게 즐기는 치킨 버거', 'verified'::allergen_status, 'https://www.lotteeatz.com/upload/etc/ria/items.html', '2026-11-22T18:14:20.082Z'::timestamptz, '공식 표는 세트 구성 기준이며 구성에 따라 알레르기가 다를 수 있습니다', 'https://www.lotteeatz.com/upload/etc/ria/items.html', '공식 사이트'
from brands b where b.name = '롯데리아' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '롯데리아' and b.is_franchise and m.name = '핫크리스피치킨버거 세트');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('알류', 'danger', '달걀'), ('밀', 'danger', '밀'), ('대두', 'danger', '대두'), ('닭고기', 'danger', '닭고기'), ('토마토', 'danger', '토마토')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '롯데리아' and b.is_franchise and m.name = '핫크리스피치킨버거 세트';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '롯데리아' and b.is_franchise and m.name = '핫크리스피치킨버거 세트');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('매콤함'), ('짭조름함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '롯데리아' and b.is_franchise and m.name = '핫크리스피치킨버거 세트';

-- 롯데리아 / 클래식치즈버거 세트
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '클래식치즈버거 세트', '치즈 풍미를 살린 버거', 'verified'::allergen_status, 'https://www.lotteeatz.com/upload/etc/ria/items.html', '2026-11-22T18:14:20.082Z'::timestamptz, '공식 표는 세트 구성 기준이며 구성에 따라 알레르기가 다를 수 있습니다', 'https://www.lotteeatz.com/upload/etc/ria/items.html', '공식 사이트'
from brands b where b.name = '롯데리아' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '롯데리아' and b.is_franchise and m.name = '클래식치즈버거 세트');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('알류', 'danger', '달걀'), ('밀', 'danger', '밀'), ('대두', 'danger', '대두'), ('우유', 'danger', '우유'), ('쇠고기', 'danger', '쇠고기')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '롯데리아' and b.is_franchise and m.name = '클래식치즈버거 세트';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '롯데리아' and b.is_franchise and m.name = '클래식치즈버거 세트');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('짭조름함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '롯데리아' and b.is_franchise and m.name = '클래식치즈버거 세트';

-- 롯데리아 / 데리버거 세트
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '데리버거 세트', '달짝지근한 소스의 버거', 'verified'::allergen_status, 'https://www.lotteeatz.com/upload/etc/ria/items.html', '2026-11-22T18:14:20.082Z'::timestamptz, '공식 표는 세트 구성 기준이며 구성에 따라 알레르기가 다를 수 있습니다', 'https://www.lotteeatz.com/upload/etc/ria/items.html', '공식 사이트'
from brands b where b.name = '롯데리아' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '롯데리아' and b.is_franchise and m.name = '데리버거 세트');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('알류', 'danger', '달걀'), ('밀', 'danger', '밀'), ('대두', 'danger', '대두'), ('우유', 'danger', '우유'), ('쇠고기', 'danger', '쇠고기'), ('닭고기', 'danger', '닭고기'), ('조개류', 'danger', '조개류(가리비)')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '롯데리아' and b.is_franchise and m.name = '데리버거 세트';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '롯데리아' and b.is_franchise and m.name = '데리버거 세트');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('달콤함'), ('짭조름함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '롯데리아' and b.is_franchise and m.name = '데리버거 세트';

commit;
