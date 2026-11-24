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

-- ===== 버거킹 (메뉴 10개) =====
do $$
begin
  if not exists (select 1 from brands b where b.name = '버거킹' and b.is_franchise) then
    raise exception '브랜드 버거킹 이(가) 없어요. seed_branches.sql 을 먼저 실행하세요.';
  end if;
end;
$$;
update brands b set
  allergen_source_url = 'https://www.burgerking.co.kr/menu/detail/1080013', allergen_data_date = null::date,
  shared_notice = '지점에 따라 판매하지 않는 제품이 있을 수 있음', research_status = 'done', researched_at = now(), research_error = null
where b.name = '버거킹' and b.is_franchise;

-- 버거킹 / 와퍼
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '와퍼', '직화 소고기 패티 대표 버거', 'verified'::allergen_status, 'https://www.burgerking.co.kr/menu/detail/1080013', '2026-11-24T02:11:23.150Z'::timestamptz, null, 'https://www.burgerking.co.kr/menu/detail/1080013', '공식 사이트'
from brands b where b.name = '버거킹' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '버거킹' and b.is_franchise and m.name = '와퍼');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('쇠고기', 'danger', '쇠고기'), ('토마토', 'danger', '토마토'), ('대두', 'danger', '대두'), ('밀', 'danger', '밀'), ('알류', 'danger', '난류')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '버거킹' and b.is_franchise and m.name = '와퍼';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '버거킹' and b.is_franchise and m.name = '와퍼');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('감칠맛'), ('고소함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '버거킹' and b.is_franchise and m.name = '와퍼';

-- 버거킹 / 치즈와퍼
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '치즈와퍼', '치즈를 더한 와퍼', 'verified'::allergen_status, 'https://www.burgerking.co.kr/menu/detail/1080013', '2026-11-24T02:11:23.150Z'::timestamptz, null, 'https://www.burgerking.co.kr/menu/detail/1080013', '공식 사이트'
from brands b where b.name = '버거킹' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '버거킹' and b.is_franchise and m.name = '치즈와퍼');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('밀', 'danger', '밀'), ('대두', 'danger', '대두'), ('우유', 'danger', '우유'), ('토마토', 'danger', '토마토'), ('알류', 'danger', '난류'), ('쇠고기', 'danger', '쇠고기')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '버거킹' and b.is_franchise and m.name = '치즈와퍼';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '버거킹' and b.is_franchise and m.name = '치즈와퍼');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('짭조름함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '버거킹' and b.is_franchise and m.name = '치즈와퍼';

-- 버거킹 / 불고기와퍼
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '불고기와퍼', '불고기 소스 소고기 버거', 'verified'::allergen_status, 'https://www.burgerking.co.kr/menu/detail/1080013', '2026-11-24T02:11:23.150Z'::timestamptz, null, 'https://www.burgerking.co.kr/menu/detail/1080013', '공식 사이트'
from brands b where b.name = '버거킹' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '버거킹' and b.is_franchise and m.name = '불고기와퍼');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('밀', 'danger', '밀'), ('대두', 'danger', '대두'), ('알류', 'danger', '난류'), ('쇠고기', 'danger', '쇠고기'), ('토마토', 'danger', '토마토')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '버거킹' and b.is_franchise and m.name = '불고기와퍼';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '버거킹' and b.is_franchise and m.name = '불고기와퍼');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('달콤함'), ('짭조름함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '버거킹' and b.is_franchise and m.name = '불고기와퍼';

-- 버거킹 / 통새우와퍼
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '통새우와퍼', '통새우를 올린 와퍼', 'verified'::allergen_status, 'https://www.burgerking.co.kr/menu/detail/1080013', '2026-11-24T02:11:23.150Z'::timestamptz, null, 'https://www.burgerking.co.kr/menu/detail/1080013', '공식 사이트'
from brands b where b.name = '버거킹' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '버거킹' and b.is_franchise and m.name = '통새우와퍼');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('대두', 'danger', '대두'), ('우유', 'danger', '우유'), ('토마토', 'danger', '토마토'), ('쇠고기', 'danger', '쇠고기'), ('새우', 'danger', '새우'), ('알류', 'danger', '난류'), ('밀', 'danger', '밀')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '버거킹' and b.is_franchise and m.name = '통새우와퍼';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '버거킹' and b.is_franchise and m.name = '통새우와퍼');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('감칠맛'), ('고소함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '버거킹' and b.is_franchise and m.name = '통새우와퍼';

-- 버거킹 / 몬스터와퍼
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '몬스터와퍼', '소고기·치킨 패티 푸짐 버거', 'verified'::allergen_status, 'https://www.burgerking.co.kr/menu/detail/1080013', '2026-11-24T02:11:23.150Z'::timestamptz, null, 'https://www.burgerking.co.kr/menu/detail/1080013', '공식 사이트'
from brands b where b.name = '버거킹' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '버거킹' and b.is_franchise and m.name = '몬스터와퍼');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('돼지고기', 'danger', '돼지고기'), ('알류', 'danger', '난류'), ('쇠고기', 'danger', '쇠고기'), ('닭고기', 'danger', '닭고기'), ('토마토', 'danger', '토마토'), ('우유', 'danger', '우유'), ('대두', 'danger', '대두'), ('밀', 'danger', '밀')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '버거킹' and b.is_franchise and m.name = '몬스터와퍼';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '버거킹' and b.is_franchise and m.name = '몬스터와퍼');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('매콤함'), ('감칠맛')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '버거킹' and b.is_franchise and m.name = '몬스터와퍼';

-- 버거킹 / 베이컨치즈와퍼
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '베이컨치즈와퍼', '베이컨과 치즈 얹은 와퍼', 'verified'::allergen_status, 'https://www.burgerking.co.kr/menu/detail/1080013', '2026-11-24T02:11:23.150Z'::timestamptz, null, 'https://www.burgerking.co.kr/menu/detail/1080013', '공식 사이트'
from brands b where b.name = '버거킹' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '버거킹' and b.is_franchise and m.name = '베이컨치즈와퍼');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('우유', 'danger', '우유'), ('돼지고기', 'danger', '돼지고기'), ('밀', 'danger', '밀'), ('토마토', 'danger', '토마토'), ('쇠고기', 'danger', '쇠고기'), ('알류', 'danger', '난류'), ('대두', 'danger', '대두')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '버거킹' and b.is_franchise and m.name = '베이컨치즈와퍼';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '버거킹' and b.is_franchise and m.name = '베이컨치즈와퍼');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('짭조름함'), ('고소함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '버거킹' and b.is_franchise and m.name = '베이컨치즈와퍼';

-- 버거킹 / 콰트로치즈와퍼
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '콰트로치즈와퍼', '네 가지 치즈 와퍼', 'verified'::allergen_status, 'https://www.burgerking.co.kr/menu/detail/1080013', '2026-11-24T02:11:23.150Z'::timestamptz, null, 'https://www.burgerking.co.kr/menu/detail/1080013', '공식 사이트'
from brands b where b.name = '버거킹' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '버거킹' and b.is_franchise and m.name = '콰트로치즈와퍼');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('토마토', 'danger', '토마토'), ('쇠고기', 'danger', '쇠고기'), ('밀', 'danger', '밀'), ('알류', 'danger', '난류'), ('대두', 'danger', '대두'), ('우유', 'danger', '우유')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '버거킹' and b.is_franchise and m.name = '콰트로치즈와퍼';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '버거킹' and b.is_franchise and m.name = '콰트로치즈와퍼');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('느끼함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '버거킹' and b.is_franchise and m.name = '콰트로치즈와퍼';

-- 버거킹 / 와퍼주니어
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '와퍼주니어', '작은 사이즈 와퍼', 'verified'::allergen_status, 'https://www.burgerking.co.kr/menu/detail/1080013', '2026-11-24T02:11:23.150Z'::timestamptz, null, 'https://www.burgerking.co.kr/menu/detail/1080013', '공식 사이트'
from brands b where b.name = '버거킹' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '버거킹' and b.is_franchise and m.name = '와퍼주니어');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('쇠고기', 'danger', '쇠고기'), ('밀', 'danger', '밀'), ('대두', 'danger', '대두'), ('토마토', 'danger', '토마토'), ('알류', 'danger', '난류')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '버거킹' and b.is_franchise and m.name = '와퍼주니어';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '버거킹' and b.is_franchise and m.name = '와퍼주니어');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('감칠맛'), ('고소함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '버거킹' and b.is_franchise and m.name = '와퍼주니어';

-- 버거킹 / 롱치킨버거
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '롱치킨버거', '길쭉한 치킨 패티 버거', 'verified'::allergen_status, 'https://www.burgerking.co.kr/menu/detail/1080013', '2026-11-24T02:11:23.150Z'::timestamptz, null, 'https://www.burgerking.co.kr/menu/detail/1080013', '공식 사이트'
from brands b where b.name = '버거킹' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '버거킹' and b.is_franchise and m.name = '롱치킨버거');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('알류', 'danger', '난류'), ('밀', 'danger', '밀'), ('대두', 'danger', '대두'), ('닭고기', 'danger', '닭고기')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '버거킹' and b.is_franchise and m.name = '롱치킨버거';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '버거킹' and b.is_franchise and m.name = '롱치킨버거');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('담백함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '버거킹' and b.is_franchise and m.name = '롱치킨버거';

-- 버거킹 / 치즈버거
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '치즈버거', '치즈 얹은 기본 버거', 'verified'::allergen_status, 'https://www.burgerking.co.kr/menu/detail/1080013', '2026-11-24T02:11:23.150Z'::timestamptz, null, 'https://www.burgerking.co.kr/menu/detail/1080013', '공식 사이트'
from brands b where b.name = '버거킹' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '버거킹' and b.is_franchise and m.name = '치즈버거');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('대두', 'danger', '대두'), ('알류', 'danger', '난류'), ('토마토', 'danger', '토마토'), ('쇠고기', 'danger', '쇠고기'), ('밀', 'danger', '밀'), ('우유', 'danger', '우유')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '버거킹' and b.is_franchise and m.name = '치즈버거';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '버거킹' and b.is_franchise and m.name = '치즈버거');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('짭조름함'), ('고소함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '버거킹' and b.is_franchise and m.name = '치즈버거';

-- ===== BBQ (메뉴 10개) =====
do $$
begin
  if not exists (select 1 from brands b where b.name = 'BBQ' and b.is_franchise) then
    raise exception '브랜드 BBQ 이(가) 없어요. seed_branches.sql 을 먼저 실행하세요.';
  end if;
end;
$$;
update brands b set
  allergen_source_url = 'https://bbq.co.kr/categories/19', allergen_data_date = null::date,
  shared_notice = '지점에 따라 판매하지 않는 제품이 있을 수 있음', research_status = 'done', researched_at = now(), research_error = null
where b.name = 'BBQ' and b.is_franchise;

-- BBQ / 황금올리브치킨
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '황금올리브치킨', '올리브유로 튀긴 후라이드', 'verified'::allergen_status, 'https://bbq.co.kr/categories/19', '2026-11-24T03:13:01.479Z'::timestamptz, null, 'https://bbq.co.kr/categories/19', '공식 사이트'
from brands b where b.name = 'BBQ' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = 'BBQ' and b.is_franchise and m.name = '황금올리브치킨');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('알류', 'danger', '알류'), ('우유', 'danger', '우유'), ('땅콩', 'danger', '땅콩'), ('대두', 'danger', '대두'), ('밀', 'danger', '밀'), ('새우', 'danger', '새우'), ('닭고기', 'danger', '닭고기'), ('쇠고기', 'danger', '쇠고기'), ('조개류', 'danger', '조개류')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = 'BBQ' and b.is_franchise and m.name = '황금올리브치킨';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = 'BBQ' and b.is_franchise and m.name = '황금올리브치킨');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('담백함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = 'BBQ' and b.is_franchise and m.name = '황금올리브치킨';

-- BBQ / 황금올리브치킨양념
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '황금올리브치킨양념', '달콤한 양념 버무림 치킨', 'verified'::allergen_status, 'https://bbq.co.kr/categories/19', '2026-11-24T03:13:01.479Z'::timestamptz, null, 'https://bbq.co.kr/categories/19', '공식 사이트'
from brands b where b.name = 'BBQ' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = 'BBQ' and b.is_franchise and m.name = '황금올리브치킨양념');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('알류', 'danger', '알류'), ('우유', 'danger', '우유'), ('땅콩', 'danger', '땅콩'), ('대두', 'danger', '대두'), ('밀', 'danger', '밀'), ('새우', 'danger', '새우'), ('토마토', 'danger', '토마토'), ('닭고기', 'danger', '닭고기'), ('쇠고기', 'danger', '쇠고기'), ('조개류', 'danger', '조개류')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = 'BBQ' and b.is_franchise and m.name = '황금올리브치킨양념';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = 'BBQ' and b.is_franchise and m.name = '황금올리브치킨양념');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('달콤함'), ('매콤함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = 'BBQ' and b.is_franchise and m.name = '황금올리브치킨양념';

-- BBQ / 황금올리브치킨매운양념
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '황금올리브치킨매운양념', '더 맵게 버무린 양념치킨', 'verified'::allergen_status, 'https://bbq.co.kr/categories/19', '2026-11-24T03:13:01.479Z'::timestamptz, null, 'https://bbq.co.kr/categories/19', '공식 사이트'
from brands b where b.name = 'BBQ' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = 'BBQ' and b.is_franchise and m.name = '황금올리브치킨매운양념');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('알류', 'danger', '알류'), ('우유', 'danger', '우유'), ('땅콩', 'danger', '땅콩'), ('대두', 'danger', '대두'), ('밀', 'danger', '밀'), ('새우', 'danger', '새우'), ('토마토', 'danger', '토마토'), ('닭고기', 'danger', '닭고기'), ('쇠고기', 'danger', '쇠고기'), ('조개류', 'danger', '조개류')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = 'BBQ' and b.is_franchise and m.name = '황금올리브치킨매운양념';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = 'BBQ' and b.is_franchise and m.name = '황금올리브치킨매운양념');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('매콤함'), ('달콤함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = 'BBQ' and b.is_franchise and m.name = '황금올리브치킨매운양념';

-- BBQ / 황금올리브치킨핫크리스피
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '황금올리브치킨핫크리스피', '매콤 바삭한 후라이드', 'verified'::allergen_status, 'https://bbq.co.kr/categories/19', '2026-11-24T03:13:01.479Z'::timestamptz, null, 'https://bbq.co.kr/categories/19', '공식 사이트'
from brands b where b.name = 'BBQ' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = 'BBQ' and b.is_franchise and m.name = '황금올리브치킨핫크리스피');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('우유', 'danger', '우유'), ('땅콩', 'danger', '땅콩'), ('대두', 'danger', '대두'), ('밀', 'danger', '밀'), ('새우', 'danger', '새우'), ('돼지고기', 'danger', '돼지고기'), ('토마토', 'danger', '토마토'), ('닭고기', 'danger', '닭고기'), ('쇠고기', 'danger', '쇠고기'), ('조개류', 'danger', '조개류')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = 'BBQ' and b.is_franchise and m.name = '황금올리브치킨핫크리스피';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = 'BBQ' and b.is_franchise and m.name = '황금올리브치킨핫크리스피');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('매콤함'), ('고소함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = 'BBQ' and b.is_franchise and m.name = '황금올리브치킨핫크리스피';

-- BBQ / 황금올리브치킨블랙페퍼
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '황금올리브치킨블랙페퍼', '후추 풍미 후라이드', 'verified'::allergen_status, 'https://bbq.co.kr/categories/19', '2026-11-24T03:13:01.479Z'::timestamptz, null, 'https://bbq.co.kr/categories/19', '공식 사이트'
from brands b where b.name = 'BBQ' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = 'BBQ' and b.is_franchise and m.name = '황금올리브치킨블랙페퍼');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('알류', 'danger', '알류'), ('우유', 'danger', '우유'), ('땅콩', 'danger', '땅콩'), ('대두', 'danger', '대두'), ('밀', 'danger', '밀'), ('새우', 'danger', '새우'), ('닭고기', 'danger', '닭고기'), ('쇠고기', 'danger', '쇠고기'), ('조개류', 'danger', '조개류')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = 'BBQ' and b.is_franchise and m.name = '황금올리브치킨블랙페퍼';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = 'BBQ' and b.is_franchise and m.name = '황금올리브치킨블랙페퍼');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('짭조름함'), ('고소함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = 'BBQ' and b.is_franchise and m.name = '황금올리브치킨블랙페퍼';

-- BBQ / 황금올리브치킨속안심
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '황금올리브치킨속안심', '안심살 순살 치킨', 'verified'::allergen_status, 'https://bbq.co.kr/categories/19', '2026-11-24T03:13:01.479Z'::timestamptz, null, 'https://bbq.co.kr/categories/19', '공식 사이트'
from brands b where b.name = 'BBQ' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = 'BBQ' and b.is_franchise and m.name = '황금올리브치킨속안심');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('알류', 'danger', '알류'), ('우유', 'danger', '우유'), ('땅콩', 'danger', '땅콩'), ('대두', 'danger', '대두'), ('밀', 'danger', '밀'), ('새우', 'danger', '새우'), ('토마토', 'danger', '토마토'), ('닭고기', 'danger', '닭고기'), ('쇠고기', 'danger', '쇠고기'), ('조개류', 'danger', '조개류')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = 'BBQ' and b.is_franchise and m.name = '황금올리브치킨속안심';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = 'BBQ' and b.is_franchise and m.name = '황금올리브치킨속안심');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('담백함'), ('고소함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = 'BBQ' and b.is_franchise and m.name = '황금올리브치킨속안심';

-- BBQ / 자메이카 통다리구이
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '자메이카 통다리구이', '향신료 양념 통다리 구이', 'verified'::allergen_status, 'https://bbq.co.kr/categories/19', '2026-11-24T03:13:01.479Z'::timestamptz, '공식 원문 표기: ''대두, 밀, 토마토, 닭고기, 쇠고기,, 조개류'' (쇠고기 뒤 쉼표 중복은 원문 그대로이며 누락 항목 여부는 확인 불가)', 'https://bbq.co.kr/categories/19', '공식 사이트'
from brands b where b.name = 'BBQ' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = 'BBQ' and b.is_franchise and m.name = '자메이카 통다리구이');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('대두', 'danger', '대두'), ('밀', 'danger', '밀'), ('토마토', 'danger', '토마토'), ('닭고기', 'danger', '닭고기'), ('쇠고기', 'danger', '쇠고기'), ('조개류', 'danger', '조개류')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = 'BBQ' and b.is_franchise and m.name = '자메이카 통다리구이';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = 'BBQ' and b.is_franchise and m.name = '자메이카 통다리구이');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('매콤함'), ('짭조름함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = 'BBQ' and b.is_franchise and m.name = '자메이카 통다리구이';

-- BBQ / 뿜치킹
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '뿜치킹', '시즈닝 뿌린 후라이드', 'verified'::allergen_status, 'https://bbq.co.kr/categories/19', '2026-11-24T03:13:01.479Z'::timestamptz, null, 'https://bbq.co.kr/categories/19', '공식 사이트'
from brands b where b.name = 'BBQ' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = 'BBQ' and b.is_franchise and m.name = '뿜치킹');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('우유', 'danger', '우유'), ('땅콩', 'danger', '땅콩'), ('대두', 'danger', '대두'), ('밀', 'danger', '밀'), ('닭고기', 'danger', '닭고기'), ('쇠고기', 'danger', '쇠고기')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = 'BBQ' and b.is_franchise and m.name = '뿜치킹';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = 'BBQ' and b.is_franchise and m.name = '뿜치킹');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('짭조름함'), ('고소함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = 'BBQ' and b.is_franchise and m.name = '뿜치킹';

-- BBQ / 크런치버터치킨
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '크런치버터치킨', '버터 풍미 바삭 치킨', 'verified'::allergen_status, 'https://bbq.co.kr/categories/19', '2026-11-24T03:13:01.479Z'::timestamptz, null, 'https://bbq.co.kr/categories/19', '공식 사이트'
from brands b where b.name = 'BBQ' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = 'BBQ' and b.is_franchise and m.name = '크런치버터치킨');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('알류', 'danger', '알류'), ('우유', 'danger', '우유'), ('땅콩', 'danger', '땅콩'), ('대두', 'danger', '대두'), ('밀', 'danger', '밀'), ('새우', 'danger', '새우'), ('닭고기', 'danger', '닭고기'), ('쇠고기', 'danger', '쇠고기'), ('조개류', 'danger', '조개류')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = 'BBQ' and b.is_franchise and m.name = '크런치버터치킨';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = 'BBQ' and b.is_franchise and m.name = '크런치버터치킨');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('느끼함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = 'BBQ' and b.is_franchise and m.name = '크런치버터치킨';

-- BBQ / 맵소디
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '맵소디', '매운 소스 치킨', 'verified'::allergen_status, 'https://bbq.co.kr/categories/19', '2026-11-24T03:13:01.479Z'::timestamptz, null, 'https://bbq.co.kr/categories/19', '공식 사이트'
from brands b where b.name = 'BBQ' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = 'BBQ' and b.is_franchise and m.name = '맵소디');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('알류', 'danger', '알류'), ('우유', 'danger', '우유'), ('땅콩', 'danger', '땅콩'), ('대두', 'danger', '대두'), ('밀', 'danger', '밀'), ('닭고기', 'danger', '닭고기'), ('쇠고기', 'danger', '쇠고기'), ('조개류', 'danger', '조개류')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = 'BBQ' and b.is_franchise and m.name = '맵소디';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = 'BBQ' and b.is_franchise and m.name = '맵소디');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('매콤함'), ('감칠맛')) as v(name)
join taste_tags t on t.name = v.name
where b.name = 'BBQ' and b.is_franchise and m.name = '맵소디';

-- ===== 피자헛 (메뉴 10개) =====
do $$
begin
  if not exists (select 1 from brands b where b.name = '피자헛' and b.is_franchise) then
    raise exception '브랜드 피자헛 이(가) 없어요. seed_branches.sql 을 먼저 실행하세요.';
  end if;
end;
$$;
update brands b set
  allergen_source_url = 'https://www.pizzahut.co.kr/menu/pizza', allergen_data_date = null::date,
  shared_notice = '지점에 따라 판매하지 않는 제품이 있을 수 있음', research_status = 'done', researched_at = now(), research_error = null
where b.name = '피자헛' and b.is_franchise;

-- 피자헛 / 안창 스테이크 슈프림 (오리지널 도우 L)
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '안창 스테이크 슈프림 (오리지널 도우 L)', '안창살 스테이크를 올린 피자', 'verified'::allergen_status, 'https://www.pizzahut.co.kr/menu/pizza', '2026-11-24T03:13:01.479Z'::timestamptz, '공식 표는 피자명·사이즈·도우/엣지 조합별 행으로 구성됨. 대표로 L 오리지널 도우 행을 사용함. 리치골드(M/L) 행은 ''계란''이 추가로 표기됨. 치즈크러스트 골드, 치즈크러스트, 씬 도우 라지 행과 M 사이즈 행은 오리지널 행과 같음.', 'https://www.pizzahut.co.kr/menu/pizza', '공식 사이트'
from brands b where b.name = '피자헛' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '피자헛' and b.is_franchise and m.name = '안창 스테이크 슈프림 (오리지널 도우 L)');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('우유', 'danger', '우유'), ('대두', 'danger', '대두'), ('밀', 'danger', '밀'), ('토마토', 'danger', '토마토'), ('돼지고기', 'danger', '돼지고기'), ('쇠고기', 'danger', '소고기'), ('닭고기', 'danger', '닭고기'), ('게', 'danger', '게'), ('조개류', 'danger', '조개류(굴, 홍합)'), ('아황산류', 'danger', '아황산류')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '피자헛' and b.is_franchise and m.name = '안창 스테이크 슈프림 (오리지널 도우 L)';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '피자헛' and b.is_franchise and m.name = '안창 스테이크 슈프림 (오리지널 도우 L)');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('짭조름함'), ('감칠맛')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '피자헛' and b.is_franchise and m.name = '안창 스테이크 슈프림 (오리지널 도우 L)';

-- 피자헛 / 수퍼슈프림 (오리지널 도우 L)
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '수퍼슈프림 (오리지널 도우 L)', '고기와 채소를 듬뿍 올린 피자', 'verified'::allergen_status, 'https://www.pizzahut.co.kr/menu/pizza', '2026-11-24T03:13:01.479Z'::timestamptz, '공식 표는 피자명·사이즈·도우/엣지 조합별 행으로 구성됨. 대표로 L 오리지널 도우 행을 사용함. 리치골드(M/L) 행은 ''계란''이 추가로 표기됨. 나머지 도우 행과 M 사이즈 행은 오리지널 행과 같음.', 'https://www.pizzahut.co.kr/menu/pizza', '공식 사이트'
from brands b where b.name = '피자헛' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '피자헛' and b.is_franchise and m.name = '수퍼슈프림 (오리지널 도우 L)');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('우유', 'danger', '우유'), ('대두', 'danger', '대두'), ('밀', 'danger', '밀'), ('토마토', 'danger', '토마토'), ('돼지고기', 'danger', '돼지고기'), ('쇠고기', 'danger', '소고기'), ('조개류', 'danger', '조개류')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '피자헛' and b.is_franchise and m.name = '수퍼슈프림 (오리지널 도우 L)';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '피자헛' and b.is_franchise and m.name = '수퍼슈프림 (오리지널 도우 L)');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('짭조름함'), ('감칠맛')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '피자헛' and b.is_franchise and m.name = '수퍼슈프림 (오리지널 도우 L)';

-- 피자헛 / 트러플 스테이크 뇨끼 (오리지널 도우 L)
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '트러플 스테이크 뇨끼 (오리지널 도우 L)', '트러플 향 스테이크 뇨끼 피자', 'verified'::allergen_status, 'https://www.pizzahut.co.kr/menu/pizza', '2026-11-24T03:13:01.479Z'::timestamptz, '공식 표는 피자명·사이즈·도우/엣지 조합별 행으로 구성됨. 대표로 L 오리지널 도우 행을 사용함. 표에 나온 모든 사이즈·도우 행의 표기가 같음.', 'https://www.pizzahut.co.kr/menu/pizza', '공식 사이트'
from brands b where b.name = '피자헛' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '피자헛' and b.is_franchise and m.name = '트러플 스테이크 뇨끼 (오리지널 도우 L)');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('알류', 'danger', '계란'), ('우유', 'danger', '우유'), ('대두', 'danger', '대두'), ('밀', 'danger', '밀'), ('토마토', 'danger', '토마토'), ('닭고기', 'danger', '닭고기'), ('돼지고기', 'danger', '돼지고기'), ('쇠고기', 'danger', '소고기'), ('게', 'danger', '게'), ('조개류', 'danger', '조개류'), ('아황산류', 'danger', '아황산류')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '피자헛' and b.is_franchise and m.name = '트러플 스테이크 뇨끼 (오리지널 도우 L)';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '피자헛' and b.is_franchise and m.name = '트러플 스테이크 뇨끼 (오리지널 도우 L)');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('감칠맛')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '피자헛' and b.is_franchise and m.name = '트러플 스테이크 뇨끼 (오리지널 도우 L)';

-- 피자헛 / 오리지널 콤비네이션 (오리지널 도우 L)
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '오리지널 콤비네이션 (오리지널 도우 L)', '여러 토핑을 올린 기본 피자', 'verified'::allergen_status, 'https://www.pizzahut.co.kr/menu/pizza', '2026-11-24T03:13:01.479Z'::timestamptz, '공식 표는 피자명·사이즈·도우/엣지 조합별 행으로 구성됨. 대표로 L 오리지널 도우 행을 사용함. 리치골드(M/L) 행은 ''계란''이 추가로 표기됨. 나머지 도우 행(팬·씬 도우 라지 포함)은 같음. M 사이즈 오리지널 도우 행은 표에 없음.', 'https://www.pizzahut.co.kr/menu/pizza', '공식 사이트'
from brands b where b.name = '피자헛' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '피자헛' and b.is_franchise and m.name = '오리지널 콤비네이션 (오리지널 도우 L)');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('우유', 'danger', '우유'), ('대두', 'danger', '대두'), ('밀', 'danger', '밀'), ('토마토', 'danger', '토마토'), ('돼지고기', 'danger', '돼지고기'), ('쇠고기', 'danger', '소고기'), ('조개류', 'danger', '조개류')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '피자헛' and b.is_franchise and m.name = '오리지널 콤비네이션 (오리지널 도우 L)';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '피자헛' and b.is_franchise and m.name = '오리지널 콤비네이션 (오리지널 도우 L)');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('짭조름함'), ('감칠맛')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '피자헛' and b.is_franchise and m.name = '오리지널 콤비네이션 (오리지널 도우 L)';

-- 피자헛 / 클래식 페페로니 (오리지널 도우 L)
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '클래식 페페로니 (오리지널 도우 L)', '페페로니를 올린 클래식 피자', 'verified'::allergen_status, 'https://www.pizzahut.co.kr/menu/pizza', '2026-11-24T03:13:01.479Z'::timestamptz, '공식 표는 피자명·사이즈·도우/엣지 조합별 행으로 구성됨. 대표로 L 오리지널 도우 행을 사용함. 리치골드(M/L) 행은 ''계란''이 추가로 표기됨. 씬 도우 라지 행은 ''대두''가 빠진 ''우유, 밀, 토마토, 돼지고기''로 표기됨.', 'https://www.pizzahut.co.kr/menu/pizza', '공식 사이트'
from brands b where b.name = '피자헛' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '피자헛' and b.is_franchise and m.name = '클래식 페페로니 (오리지널 도우 L)');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('우유', 'danger', '우유'), ('대두', 'danger', '대두'), ('밀', 'danger', '밀'), ('토마토', 'danger', '토마토'), ('돼지고기', 'danger', '돼지고기')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '피자헛' and b.is_franchise and m.name = '클래식 페페로니 (오리지널 도우 L)';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '피자헛' and b.is_franchise and m.name = '클래식 페페로니 (오리지널 도우 L)');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('짭조름함'), ('매콤함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '피자헛' and b.is_franchise and m.name = '클래식 페페로니 (오리지널 도우 L)';

-- 피자헛 / 직화불고기 (오리지널 도우 L)
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '직화불고기 (오리지널 도우 L)', '불맛 불고기를 올린 피자', 'verified'::allergen_status, 'https://www.pizzahut.co.kr/menu/pizza', '2026-11-24T03:13:01.479Z'::timestamptz, '공식 표는 피자명·사이즈·도우/엣지 조합별 행으로 구성됨. 대표로 L 오리지널 도우 행을 사용함. 표에 나온 모든 사이즈·도우 행의 표기가 같음.', 'https://www.pizzahut.co.kr/menu/pizza', '공식 사이트'
from brands b where b.name = '피자헛' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '피자헛' and b.is_franchise and m.name = '직화불고기 (오리지널 도우 L)');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('알류', 'danger', '계란'), ('우유', 'danger', '우유'), ('대두', 'danger', '대두'), ('밀', 'danger', '밀'), ('토마토', 'danger', '토마토'), ('쇠고기', 'danger', '소고기'), ('조개류', 'danger', '조개류')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '피자헛' and b.is_franchise and m.name = '직화불고기 (오리지널 도우 L)';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '피자헛' and b.is_franchise and m.name = '직화불고기 (오리지널 도우 L)');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('달콤함'), ('짭조름함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '피자헛' and b.is_franchise and m.name = '직화불고기 (오리지널 도우 L)';

-- 피자헛 / 더블 메가 쉬림프 (오리지널 도우 L)
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '더블 메가 쉬림프 (오리지널 도우 L)', '큼직한 새우를 두 배로 올린 피자', 'verified'::allergen_status, 'https://www.pizzahut.co.kr/menu/pizza', '2026-11-24T03:13:01.479Z'::timestamptz, '공식 표는 피자명·사이즈·도우/엣지 조합별 행으로 구성됨. 대표로 L 오리지널 도우 행을 사용함. 표에 나온 모든 사이즈·도우 행의 표기가 같음.', 'https://www.pizzahut.co.kr/menu/pizza', '공식 사이트'
from brands b where b.name = '피자헛' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '피자헛' and b.is_franchise and m.name = '더블 메가 쉬림프 (오리지널 도우 L)');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('알류', 'danger', '계란'), ('우유', 'danger', '우유'), ('대두', 'danger', '대두'), ('밀', 'danger', '밀'), ('토마토', 'danger', '토마토'), ('새우', 'danger', '새우'), ('아황산류', 'danger', '아황산류')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '피자헛' and b.is_franchise and m.name = '더블 메가 쉬림프 (오리지널 도우 L)';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '피자헛' and b.is_franchise and m.name = '더블 메가 쉬림프 (오리지널 도우 L)');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('감칠맛')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '피자헛' and b.is_franchise and m.name = '더블 메가 쉬림프 (오리지널 도우 L)';

-- 피자헛 / 씨푸드 디럭스 (오리지널 도우 L)
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '씨푸드 디럭스 (오리지널 도우 L)', '해산물과 고기를 함께 올린 피자', 'verified'::allergen_status, 'https://www.pizzahut.co.kr/menu/pizza', '2026-11-24T03:13:01.479Z'::timestamptz, '공식 표는 피자명·사이즈·도우/엣지 조합별 행으로 구성됨. 대표로 L 오리지널 도우 행을 사용함. 리치골드(M/L) 행은 ''계란''이 추가로 표기됨. 나머지 도우 행과 M 사이즈 행은 오리지널 행과 같음.', 'https://www.pizzahut.co.kr/menu/pizza', '공식 사이트'
from brands b where b.name = '피자헛' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '피자헛' and b.is_franchise and m.name = '씨푸드 디럭스 (오리지널 도우 L)');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('우유', 'danger', '우유'), ('대두', 'danger', '대두'), ('밀', 'danger', '밀'), ('토마토', 'danger', '토마토'), ('닭고기', 'danger', '닭고기'), ('돼지고기', 'danger', '돼지고기'), ('쇠고기', 'danger', '소고기'), ('게', 'danger', '게'), ('새우', 'danger', '새우'), ('조개류', 'danger', '조개류')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '피자헛' and b.is_franchise and m.name = '씨푸드 디럭스 (오리지널 도우 L)';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '피자헛' and b.is_franchise and m.name = '씨푸드 디럭스 (오리지널 도우 L)');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('감칠맛'), ('짭조름함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '피자헛' and b.is_franchise and m.name = '씨푸드 디럭스 (오리지널 도우 L)';

-- 피자헛 / 치즈 러버 (오리지널 도우 L)
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '치즈 러버 (오리지널 도우 L)', '치즈 맛에 집중한 피자', 'verified'::allergen_status, 'https://www.pizzahut.co.kr/menu/pizza', '2026-11-24T03:13:01.479Z'::timestamptz, '공식 표는 피자명·사이즈·도우/엣지 조합별 행으로 구성됨. 대표로 L 오리지널 도우 행을 사용함. 리치골드(M/L) 행은 ''계란''이 추가로 표기됨. 씬 도우 라지 행은 ''대두''가 빠진 ''우유, 밀, 토마토''로 표기됨.', 'https://www.pizzahut.co.kr/menu/pizza', '공식 사이트'
from brands b where b.name = '피자헛' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '피자헛' and b.is_franchise and m.name = '치즈 러버 (오리지널 도우 L)');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('우유', 'danger', '우유'), ('대두', 'danger', '대두'), ('밀', 'danger', '밀'), ('토마토', 'danger', '토마토')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '피자헛' and b.is_franchise and m.name = '치즈 러버 (오리지널 도우 L)';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '피자헛' and b.is_franchise and m.name = '치즈 러버 (오리지널 도우 L)');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('느끼함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '피자헛' and b.is_franchise and m.name = '치즈 러버 (오리지널 도우 L)';

-- 피자헛 / 멜팅치즈 포테이토 (오리지널 도우 L)
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '멜팅치즈 포테이토 (오리지널 도우 L)', '녹은 치즈와 감자를 올린 피자', 'verified'::allergen_status, 'https://www.pizzahut.co.kr/menu/pizza', '2026-11-24T03:13:01.479Z'::timestamptz, '공식 표는 피자명·사이즈·도우/엣지 조합별 행으로 구성됨. 대표로 L 오리지널 도우 행을 사용함. 표에 나온 모든 사이즈·도우 행의 표기가 같음.', 'https://www.pizzahut.co.kr/menu/pizza', '공식 사이트'
from brands b where b.name = '피자헛' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '피자헛' and b.is_franchise and m.name = '멜팅치즈 포테이토 (오리지널 도우 L)');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('알류', 'danger', '계란'), ('우유', 'danger', '우유'), ('대두', 'danger', '대두'), ('밀', 'danger', '밀'), ('토마토', 'danger', '토마토'), ('돼지고기', 'danger', '돼지고기'), ('쇠고기', 'danger', '소고기'), ('조개류', 'danger', '조개류')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '피자헛' and b.is_franchise and m.name = '멜팅치즈 포테이토 (오리지널 도우 L)';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '피자헛' and b.is_franchise and m.name = '멜팅치즈 포테이토 (오리지널 도우 L)');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('짭조름함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '피자헛' and b.is_franchise and m.name = '멜팅치즈 포테이토 (오리지널 도우 L)';

-- ===== 파파존스 (메뉴 10개) =====
do $$
begin
  if not exists (select 1 from brands b where b.name = '파파존스' and b.is_franchise) then
    raise exception '브랜드 파파존스 이(가) 없어요. seed_branches.sql 을 먼저 실행하세요.';
  end if;
end;
$$;
update brands b set
  allergen_source_url = 'https://www.pji.co.kr/menu/pizza/1000', allergen_data_date = null::date,
  shared_notice = '매장에서는 난류, 우유, 대두, 밀, 게, 새우, 돼지고기, 토마토, 닭고기, 쇠고기, 조개류 등이 포함된 제품을 사용하고 있으며, 모든 피자는 동일한 공간에서 제조됩니다. 이로 인해 알레르기 유발 성분이 혼입될 수 있으니, 섭취 시 주의해 주시기 바랍니다. / 지점에 따라 판매하지 않는 제품이 있을 수 있음', research_status = 'done', researched_at = now(), research_error = null
where b.name = '파파존스' and b.is_franchise;

-- 파파존스 / 수퍼 파파스 (오리지널 크러스트)
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '수퍼 파파스 (오리지널 크러스트)', '여러 고기와 채소 콤비네이션', 'verified'::allergen_status, 'https://www.pji.co.kr/menu/pizza/1000', '2026-11-24T03:13:01.479Z'::timestamptz, '공식 표는 피자×크러스트 단위로 표기되어 있음. 위 값은 오리지널 크러스트 행 기준이며 씬도 동일함. 치즈롤·골드링·스파이시 갈릭 치즈롤·골드링씬·하트씬·크루아상·체다치즈롤은 난류가 추가됨.', 'https://www.pji.co.kr/menu/pizza/1000', '공식 사이트'
from brands b where b.name = '파파존스' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '파파존스' and b.is_franchise and m.name = '수퍼 파파스 (오리지널 크러스트)');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('우유', 'danger', '우유'), ('대두', 'danger', '대두'), ('밀', 'danger', '밀'), ('돼지고기', 'danger', '돼지고기'), ('토마토', 'danger', '토마토'), ('쇠고기', 'danger', '쇠고기')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '파파존스' and b.is_franchise and m.name = '수퍼 파파스 (오리지널 크러스트)';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '파파존스' and b.is_franchise and m.name = '수퍼 파파스 (오리지널 크러스트)');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('짭조름함'), ('감칠맛')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '파파존스' and b.is_franchise and m.name = '수퍼 파파스 (오리지널 크러스트)';

-- 파파존스 / 아이리쉬 포테이토 (오리지널 크러스트)
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '아이리쉬 포테이토 (오리지널 크러스트)', '감자 토핑의 고소한 피자', 'verified'::allergen_status, 'https://www.pji.co.kr/menu/pizza/1000', '2026-11-24T03:13:01.479Z'::timestamptz, '공식 표는 피자×크러스트 단위로 표기되어 있음. 위 값은 오리지널 크러스트 행 기준임. 표에 있는 모든 크러스트(치즈롤·골드링·스파이시 갈릭 치즈롤·씬·골드링씬·크루아상·체다치즈롤)가 같은 값임.', 'https://www.pji.co.kr/menu/pizza/1000', '공식 사이트'
from brands b where b.name = '파파존스' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '파파존스' and b.is_franchise and m.name = '아이리쉬 포테이토 (오리지널 크러스트)');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('알류', 'danger', '난류'), ('우유', 'danger', '우유'), ('대두', 'danger', '대두'), ('밀', 'danger', '밀'), ('돼지고기', 'danger', '돼지고기'), ('토마토', 'danger', '토마토')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '파파존스' and b.is_franchise and m.name = '아이리쉬 포테이토 (오리지널 크러스트)';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '파파존스' and b.is_franchise and m.name = '아이리쉬 포테이토 (오리지널 크러스트)');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('짭조름함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '파파존스' and b.is_franchise and m.name = '아이리쉬 포테이토 (오리지널 크러스트)';

-- 파파존스 / 스파이시 치킨 랜치 (오리지널 크러스트)
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '스파이시 치킨 랜치 (오리지널 크러스트)', '매콤한 치킨과 랜치 소스', 'verified'::allergen_status, 'https://www.pji.co.kr/menu/pizza/1000', '2026-11-24T03:13:01.479Z'::timestamptz, '공식 표는 피자×크러스트 단위로 표기되어 있음. 위 값은 오리지널 크러스트 행 기준임. 표에 있는 모든 크러스트가 같은 값임.', 'https://www.pji.co.kr/menu/pizza/1000', '공식 사이트'
from brands b where b.name = '파파존스' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '파파존스' and b.is_franchise and m.name = '스파이시 치킨 랜치 (오리지널 크러스트)');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('알류', 'danger', '난류'), ('우유', 'danger', '우유'), ('대두', 'danger', '대두'), ('밀', 'danger', '밀'), ('돼지고기', 'danger', '돼지고기'), ('토마토', 'danger', '토마토'), ('닭고기', 'danger', '닭고기'), ('쇠고기', 'danger', '쇠고기')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '파파존스' and b.is_franchise and m.name = '스파이시 치킨 랜치 (오리지널 크러스트)';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '파파존스' and b.is_franchise and m.name = '스파이시 치킨 랜치 (오리지널 크러스트)');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('매콤함'), ('고소함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '파파존스' and b.is_franchise and m.name = '스파이시 치킨 랜치 (오리지널 크러스트)';

-- 파파존스 / 존스 페이버릿 (오리지널 크러스트)
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '존스 페이버릿 (오리지널 크러스트)', '고기 토핑 클래식 피자', 'verified'::allergen_status, 'https://www.pji.co.kr/menu/pizza/1000', '2026-11-24T03:13:01.479Z'::timestamptz, '공식 표는 피자×크러스트 단위로 표기되어 있음. 위 값은 오리지널 크러스트 행 기준이며 씬도 동일함. 치즈롤·골드링·스파이시 갈릭 치즈롤·골드링씬·체다치즈롤은 난류가 추가됨. 크루아상은 난류가 추가되고 대두는 표기되지 않음(난류, 우유, 밀, 돼지고기, 토마토, 쇠고기).', 'https://www.pji.co.kr/menu/pizza/1000', '공식 사이트'
from brands b where b.name = '파파존스' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '파파존스' and b.is_franchise and m.name = '존스 페이버릿 (오리지널 크러스트)');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('우유', 'danger', '우유'), ('대두', 'danger', '대두'), ('밀', 'danger', '밀'), ('돼지고기', 'danger', '돼지고기'), ('토마토', 'danger', '토마토'), ('쇠고기', 'danger', '쇠고기')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '파파존스' and b.is_franchise and m.name = '존스 페이버릿 (오리지널 크러스트)';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '파파존스' and b.is_franchise and m.name = '존스 페이버릿 (오리지널 크러스트)');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('짭조름함'), ('감칠맛')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '파파존스' and b.is_franchise and m.name = '존스 페이버릿 (오리지널 크러스트)';

-- 파파존스 / 올미트 (오리지널 크러스트)
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '올미트 (오리지널 크러스트)', '고기 토핑을 가득 올린 피자', 'verified'::allergen_status, 'https://www.pji.co.kr/menu/pizza/1000', '2026-11-24T03:13:01.479Z'::timestamptz, '공식 표는 피자×크러스트 단위로 표기되어 있음. 위 값은 오리지널 크러스트 행 기준이며 씬도 동일함. 치즈롤·골드링·스파이시 갈릭 치즈롤·골드링씬·크루아상·체다치즈롤은 난류가 추가됨.', 'https://www.pji.co.kr/menu/pizza/1000', '공식 사이트'
from brands b where b.name = '파파존스' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '파파존스' and b.is_franchise and m.name = '올미트 (오리지널 크러스트)');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('우유', 'danger', '우유'), ('대두', 'danger', '대두'), ('밀', 'danger', '밀'), ('돼지고기', 'danger', '돼지고기'), ('토마토', 'danger', '토마토'), ('쇠고기', 'danger', '쇠고기')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '파파존스' and b.is_franchise and m.name = '올미트 (오리지널 크러스트)';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '파파존스' and b.is_franchise and m.name = '올미트 (오리지널 크러스트)');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('짭조름함'), ('감칠맛'), ('느끼함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '파파존스' and b.is_franchise and m.name = '올미트 (오리지널 크러스트)';

-- 파파존스 / 페퍼로니 (오리지널 크러스트)
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '페퍼로니 (오리지널 크러스트)', '페퍼로니 올린 기본 피자', 'verified'::allergen_status, 'https://www.pji.co.kr/menu/pizza/1000', '2026-11-24T03:13:01.479Z'::timestamptz, '공식 표는 피자×크러스트 단위로 표기되어 있음. 위 값은 오리지널 크러스트 행 기준이며 씬도 동일함. 치즈롤·골드링·스파이시 갈릭 치즈롤·골드링씬·하트씬·체다치즈롤은 난류가 추가됨. 크루아상은 난류가 추가되고 대두는 표기되지 않음(난류, 우유, 밀, 돼지고기, 토마토, 쇠고기).', 'https://www.pji.co.kr/menu/pizza/1000', '공식 사이트'
from brands b where b.name = '파파존스' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '파파존스' and b.is_franchise and m.name = '페퍼로니 (오리지널 크러스트)');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('우유', 'danger', '우유'), ('대두', 'danger', '대두'), ('밀', 'danger', '밀'), ('돼지고기', 'danger', '돼지고기'), ('토마토', 'danger', '토마토'), ('쇠고기', 'danger', '쇠고기')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '파파존스' and b.is_franchise and m.name = '페퍼로니 (오리지널 크러스트)';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '파파존스' and b.is_franchise and m.name = '페퍼로니 (오리지널 크러스트)');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('짭조름함'), ('매콤함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '파파존스' and b.is_franchise and m.name = '페퍼로니 (오리지널 크러스트)';

-- 파파존스 / 치킨 바베큐 (오리지널 크러스트)
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '치킨 바베큐 (오리지널 크러스트)', '바베큐 소스 치킨 피자', 'verified'::allergen_status, 'https://www.pji.co.kr/menu/pizza/1000', '2026-11-24T03:13:01.479Z'::timestamptz, '공식 표는 피자×크러스트 단위로 표기되어 있음. 위 값은 오리지널 크러스트 행 기준이며 씬도 동일함. 치즈롤·골드링·스파이시 갈릭 치즈롤·골드링씬·크루아상·체다치즈롤은 난류가 추가됨.', 'https://www.pji.co.kr/menu/pizza/1000', '공식 사이트'
from brands b where b.name = '파파존스' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '파파존스' and b.is_franchise and m.name = '치킨 바베큐 (오리지널 크러스트)');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('우유', 'danger', '우유'), ('대두', 'danger', '대두'), ('밀', 'danger', '밀'), ('돼지고기', 'danger', '돼지고기'), ('토마토', 'danger', '토마토'), ('닭고기', 'danger', '닭고기'), ('쇠고기', 'danger', '쇠고기'), ('조개류', 'danger', '조개류(굴 포함)')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '파파존스' and b.is_franchise and m.name = '치킨 바베큐 (오리지널 크러스트)';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '파파존스' and b.is_franchise and m.name = '치킨 바베큐 (오리지널 크러스트)');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('달콤함'), ('짭조름함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '파파존스' and b.is_franchise and m.name = '치킨 바베큐 (오리지널 크러스트)';

-- 파파존스 / 더블 치즈버거 (오리지널 크러스트)
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '더블 치즈버거 (오리지널 크러스트)', '치즈버거 맛을 담은 피자', 'verified'::allergen_status, 'https://www.pji.co.kr/menu/pizza/1000', '2026-11-24T03:13:01.479Z'::timestamptz, '공식 표는 피자×크러스트 단위로 표기되어 있음. 위 값은 오리지널 크러스트 행 기준임. 표에 있는 모든 크러스트가 같은 값임.', 'https://www.pji.co.kr/menu/pizza/1000', '공식 사이트'
from brands b where b.name = '파파존스' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '파파존스' and b.is_franchise and m.name = '더블 치즈버거 (오리지널 크러스트)');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('알류', 'danger', '난류'), ('우유', 'danger', '우유'), ('대두', 'danger', '대두'), ('밀', 'danger', '밀'), ('토마토', 'danger', '토마토'), ('쇠고기', 'danger', '쇠고기'), ('조개류', 'danger', '조개류(굴)')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '파파존스' and b.is_franchise and m.name = '더블 치즈버거 (오리지널 크러스트)';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '파파존스' and b.is_franchise and m.name = '더블 치즈버거 (오리지널 크러스트)');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('짭조름함'), ('느끼함'), ('감칠맛')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '파파존스' and b.is_franchise and m.name = '더블 치즈버거 (오리지널 크러스트)';

-- 파파존스 / 마가리타 (오리지널 크러스트)
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '마가리타 (오리지널 크러스트)', '치즈와 토마토 소스 피자', 'verified'::allergen_status, 'https://www.pji.co.kr/menu/pizza/1000', '2026-11-24T03:13:01.479Z'::timestamptz, '공식 표는 피자×크러스트 단위로 표기되어 있음. 위 값은 오리지널 크러스트 행 기준이며 씬도 동일함. 치즈롤·골드링·스파이시 갈릭 치즈롤·골드링씬·체다치즈롤은 난류가 추가됨. 크루아상은 난류가 추가되고 대두는 표기되지 않음(난류, 우유, 밀, 토마토).', 'https://www.pji.co.kr/menu/pizza/1000', '공식 사이트'
from brands b where b.name = '파파존스' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '파파존스' and b.is_franchise and m.name = '마가리타 (오리지널 크러스트)');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('우유', 'danger', '우유'), ('대두', 'danger', '대두'), ('밀', 'danger', '밀'), ('토마토', 'danger', '토마토')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '파파존스' and b.is_franchise and m.name = '마가리타 (오리지널 크러스트)';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '파파존스' and b.is_franchise and m.name = '마가리타 (오리지널 크러스트)');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('담백함'), ('고소함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '파파존스' and b.is_franchise and m.name = '마가리타 (오리지널 크러스트)';

-- 파파존스 / 하와이안 (오리지널 크러스트)
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '하와이안 (오리지널 크러스트)', '햄과 파인애플 피자', 'verified'::allergen_status, 'https://www.pji.co.kr/menu/pizza/1000', '2026-11-24T03:13:01.479Z'::timestamptz, '공식 표는 피자×크러스트 단위로 표기되어 있음. 위 값은 오리지널 크러스트 행 기준이며 씬도 동일함. 치즈롤·골드링·스파이시 갈릭 치즈롤·골드링씬·크루아상·체다치즈롤은 난류가 추가됨.', 'https://www.pji.co.kr/menu/pizza/1000', '공식 사이트'
from brands b where b.name = '파파존스' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '파파존스' and b.is_franchise and m.name = '하와이안 (오리지널 크러스트)');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('우유', 'danger', '우유'), ('대두', 'danger', '대두'), ('밀', 'danger', '밀'), ('돼지고기', 'danger', '돼지고기'), ('토마토', 'danger', '토마토')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '파파존스' and b.is_franchise and m.name = '하와이안 (오리지널 크러스트)';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '파파존스' and b.is_franchise and m.name = '하와이안 (오리지널 크러스트)');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('달콤함'), ('짭조름함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '파파존스' and b.is_franchise and m.name = '하와이안 (오리지널 크러스트)';

-- ===== 본죽 (메뉴 8개) =====
do $$
begin
  if not exists (select 1 from brands b where b.name = '본죽' and b.is_franchise) then
    raise exception '브랜드 본죽 이(가) 없어요. seed_branches.sql 을 먼저 실행하세요.';
  end if;
end;
$$;
update brands b set
  allergen_source_url = null, allergen_data_date = null::date,
  shared_notice = '지점에 따라 판매하지 않는 제품이 있을 수 있음', research_status = 'done', researched_at = now(), research_error = null
where b.name = '본죽' and b.is_franchise;

-- 본죽 / 전복죽
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '전복죽', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '본죽' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '본죽' and b.is_franchise and m.name = '전복죽');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('조개류', 'danger', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('밀', 'caution', 'AI 추정'), ('잣', 'caution', 'AI 추정'), ('쇠고기', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '본죽' and b.is_franchise and m.name = '전복죽';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '본죽' and b.is_franchise and m.name = '전복죽');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('담백함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '본죽' and b.is_franchise and m.name = '전복죽';

-- 본죽 / 소고기야채죽
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '소고기야채죽', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '본죽' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '본죽' and b.is_franchise and m.name = '소고기야채죽');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('쇠고기', 'danger', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('밀', 'caution', 'AI 추정'), ('잣', 'caution', 'AI 추정'), ('조개류', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '본죽' and b.is_franchise and m.name = '소고기야채죽';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '본죽' and b.is_franchise and m.name = '소고기야채죽');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('담백함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '본죽' and b.is_franchise and m.name = '소고기야채죽';

-- 본죽 / 삼계죽
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '삼계죽', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '본죽' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '본죽' and b.is_franchise and m.name = '삼계죽');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('닭고기', 'danger', 'AI 추정'), ('잣', 'caution', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('밀', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '본죽' and b.is_franchise and m.name = '삼계죽';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '본죽' and b.is_franchise and m.name = '삼계죽');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('담백함'), ('고소함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '본죽' and b.is_franchise and m.name = '삼계죽';

-- 본죽 / 참치야채죽
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '참치야채죽', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '본죽' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '본죽' and b.is_franchise and m.name = '참치야채죽');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('대두', 'caution', 'AI 추정'), ('밀', 'caution', 'AI 추정'), ('알류', 'caution', 'AI 추정'), ('조개류', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '본죽' and b.is_franchise and m.name = '참치야채죽';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '본죽' and b.is_franchise and m.name = '참치야채죽');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('담백함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '본죽' and b.is_franchise and m.name = '참치야채죽';

-- 본죽 / 낙지김치죽
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '낙지김치죽', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '본죽' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '본죽' and b.is_franchise and m.name = '낙지김치죽');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('새우', 'caution', 'AI 추정'), ('오징어', 'caution', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('밀', 'caution', 'AI 추정'), ('조개류', 'caution', 'AI 추정'), ('쇠고기', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '본죽' and b.is_franchise and m.name = '낙지김치죽';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '본죽' and b.is_franchise and m.name = '낙지김치죽');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('매콤함'), ('감칠맛')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '본죽' and b.is_franchise and m.name = '낙지김치죽';

-- 본죽 / 단호박죽
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '단호박죽', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '본죽' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '본죽' and b.is_franchise and m.name = '단호박죽');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('우유', 'caution', 'AI 추정'), ('잣', 'caution', 'AI 추정'), ('밀', 'caution', 'AI 추정'), ('대두', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '본죽' and b.is_franchise and m.name = '단호박죽';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '본죽' and b.is_franchise and m.name = '단호박죽');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('달콤함'), ('고소함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '본죽' and b.is_franchise and m.name = '단호박죽';

-- 본죽 / 동지팥죽
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '동지팥죽', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '본죽' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '본죽' and b.is_franchise and m.name = '동지팥죽');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('밀', 'caution', 'AI 추정'), ('잣', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '본죽' and b.is_franchise and m.name = '동지팥죽';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '본죽' and b.is_franchise and m.name = '동지팥죽');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('달콤함'), ('담백함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '본죽' and b.is_franchise and m.name = '동지팥죽';

-- 본죽 / 불낙죽
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '불낙죽', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '본죽' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '본죽' and b.is_franchise and m.name = '불낙죽');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('쇠고기', 'danger', 'AI 추정'), ('대두', 'danger', 'AI 추정'), ('밀', 'danger', 'AI 추정'), ('오징어', 'caution', 'AI 추정'), ('새우', 'caution', 'AI 추정'), ('조개류', 'caution', 'AI 추정'), ('잣', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '본죽' and b.is_franchise and m.name = '불낙죽';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '본죽' and b.is_franchise and m.name = '불낙죽');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('매콤함'), ('달콤함'), ('짭조름함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '본죽' and b.is_franchise and m.name = '불낙죽';

-- ===== 김가네 (메뉴 8개) =====
do $$
begin
  if not exists (select 1 from brands b where b.name = '김가네' and b.is_franchise) then
    raise exception '브랜드 김가네 이(가) 없어요. seed_branches.sql 을 먼저 실행하세요.';
  end if;
end;
$$;
update brands b set
  allergen_source_url = null, allergen_data_date = null::date,
  shared_notice = '지점에 따라 판매하지 않는 제품이 있을 수 있음', research_status = 'done', researched_at = now(), research_error = null
where b.name = '김가네' and b.is_franchise;

-- 김가네 / 김가네김밥
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '김가네김밥', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '김가네' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '김가네' and b.is_franchise and m.name = '김가네김밥');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('알류', 'danger', 'AI 추정'), ('돼지고기', 'danger', 'AI 추정'), ('밀', 'danger', 'AI 추정'), ('대두', 'danger', 'AI 추정'), ('게', 'caution', 'AI 추정'), ('쇠고기', 'caution', 'AI 추정'), ('우유', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정'), ('새우', 'caution', 'AI 추정'), ('오징어', 'caution', 'AI 추정'), ('고등어', 'caution', 'AI 추정'), ('닭고기', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '김가네' and b.is_franchise and m.name = '김가네김밥';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '김가네' and b.is_franchise and m.name = '김가네김밥');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('담백함'), ('고소함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '김가네' and b.is_franchise and m.name = '김가네김밥';

-- 김가네 / 참치마요김밥
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '참치마요김밥', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '김가네' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '김가네' and b.is_franchise and m.name = '참치마요김밥');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('알류', 'danger', 'AI 추정'), ('대두', 'danger', 'AI 추정'), ('밀', 'caution', 'AI 추정'), ('돼지고기', 'caution', 'AI 추정'), ('게', 'caution', 'AI 추정'), ('우유', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정'), ('새우', 'caution', 'AI 추정'), ('오징어', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '김가네' and b.is_franchise and m.name = '참치마요김밥';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '김가네' and b.is_franchise and m.name = '참치마요김밥');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('느끼함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '김가네' and b.is_franchise and m.name = '참치마요김밥';

-- 김가네 / 멸추김밥
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '멸추김밥', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '김가네' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '김가네' and b.is_franchise and m.name = '멸추김밥');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('알류', 'danger', 'AI 추정'), ('대두', 'danger', 'AI 추정'), ('밀', 'danger', 'AI 추정'), ('돼지고기', 'caution', 'AI 추정'), ('게', 'caution', 'AI 추정'), ('새우', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정'), ('땅콩', 'caution', 'AI 추정'), ('호두', 'caution', 'AI 추정'), ('잣', 'caution', 'AI 추정'), ('오징어', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '김가네' and b.is_franchise and m.name = '멸추김밥';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '김가네' and b.is_franchise and m.name = '멸추김밥');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('매콤함'), ('짭조름함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '김가네' and b.is_franchise and m.name = '멸추김밥';

-- 김가네 / 라볶이
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '라볶이', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '김가네' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '김가네' and b.is_franchise and m.name = '라볶이');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('밀', 'danger', 'AI 추정'), ('대두', 'danger', 'AI 추정'), ('알류', 'caution', 'AI 추정'), ('새우', 'caution', 'AI 추정'), ('오징어', 'caution', 'AI 추정'), ('게', 'caution', 'AI 추정'), ('고등어', 'caution', 'AI 추정'), ('쇠고기', 'caution', 'AI 추정'), ('돼지고기', 'caution', 'AI 추정'), ('닭고기', 'caution', 'AI 추정'), ('우유', 'caution', 'AI 추정'), ('조개류', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '김가네' and b.is_franchise and m.name = '라볶이';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '김가네' and b.is_franchise and m.name = '라볶이');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('매콤함'), ('달콤함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '김가네' and b.is_franchise and m.name = '라볶이';

-- 김가네 / 쫄면
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '쫄면', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '김가네' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '김가네' and b.is_franchise and m.name = '쫄면');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('밀', 'danger', 'AI 추정'), ('대두', 'danger', 'AI 추정'), ('알류', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정'), ('돼지고기', 'caution', 'AI 추정'), ('토마토', 'caution', 'AI 추정'), ('복숭아', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '김가네' and b.is_franchise and m.name = '쫄면';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '김가네' and b.is_franchise and m.name = '쫄면');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('매콤함'), ('새콤함'), ('달콤함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '김가네' and b.is_franchise and m.name = '쫄면';

-- 김가네 / 돈까스
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '돈까스', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '김가네' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '김가네' and b.is_franchise and m.name = '돈까스');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('돼지고기', 'danger', 'AI 추정'), ('밀', 'danger', 'AI 추정'), ('알류', 'danger', 'AI 추정'), ('우유', 'caution', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('토마토', 'caution', 'AI 추정'), ('쇠고기', 'caution', 'AI 추정'), ('닭고기', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정'), ('복숭아', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '김가네' and b.is_franchise and m.name = '돈까스';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '김가네' and b.is_franchise and m.name = '돈까스');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('달콤함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '김가네' and b.is_franchise and m.name = '돈까스';

-- 김가네 / 김치찌개
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '김치찌개', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '김가네' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '김가네' and b.is_franchise and m.name = '김치찌개');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('새우', 'danger', 'AI 추정'), ('돼지고기', 'danger', 'AI 추정'), ('대두', 'danger', 'AI 추정'), ('밀', 'caution', 'AI 추정'), ('조개류', 'caution', 'AI 추정'), ('쇠고기', 'caution', 'AI 추정'), ('고등어', 'caution', 'AI 추정'), ('오징어', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '김가네' and b.is_franchise and m.name = '김치찌개';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '김가네' and b.is_franchise and m.name = '김치찌개');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('매콤함'), ('짭조름함'), ('감칠맛')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '김가네' and b.is_franchise and m.name = '김치찌개';

-- 김가네 / 제육덮밥
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '제육덮밥', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '김가네' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '김가네' and b.is_franchise and m.name = '제육덮밥');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('돼지고기', 'danger', 'AI 추정'), ('대두', 'danger', 'AI 추정'), ('밀', 'danger', 'AI 추정'), ('알류', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정'), ('복숭아', 'caution', 'AI 추정'), ('새우', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '김가네' and b.is_franchise and m.name = '제육덮밥';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '김가네' and b.is_franchise and m.name = '제육덮밥');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('매콤함'), ('달콤함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '김가네' and b.is_franchise and m.name = '제육덮밥';

-- ===== 한솥도시락 (메뉴 8개) =====
do $$
begin
  if not exists (select 1 from brands b where b.name = '한솥도시락' and b.is_franchise) then
    raise exception '브랜드 한솥도시락 이(가) 없어요. seed_branches.sql 을 먼저 실행하세요.';
  end if;
end;
$$;
update brands b set
  allergen_source_url = null, allergen_data_date = null::date,
  shared_notice = '지점에 따라 판매하지 않는 제품이 있을 수 있음', research_status = 'done', researched_at = now(), research_error = null
where b.name = '한솥도시락' and b.is_franchise;

-- 한솥도시락 / 치킨마요
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '치킨마요', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '한솥도시락' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '한솥도시락' and b.is_franchise and m.name = '치킨마요');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('닭고기', 'danger', 'AI 추정'), ('알류', 'danger', 'AI 추정'), ('밀', 'danger', 'AI 추정'), ('대두', 'danger', 'AI 추정'), ('우유', 'caution', 'AI 추정'), ('돼지고기', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '한솥도시락' and b.is_franchise and m.name = '치킨마요';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '한솥도시락' and b.is_franchise and m.name = '치킨마요');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('달콤함'), ('고소함'), ('짭조름함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '한솥도시락' and b.is_franchise and m.name = '치킨마요';

-- 한솥도시락 / 참치마요
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '참치마요', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '한솥도시락' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '한솥도시락' and b.is_franchise and m.name = '참치마요');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('알류', 'danger', 'AI 추정'), ('대두', 'danger', 'AI 추정'), ('밀', 'danger', 'AI 추정'), ('우유', 'caution', 'AI 추정'), ('고등어', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '한솥도시락' and b.is_franchise and m.name = '참치마요';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '한솥도시락' and b.is_franchise and m.name = '참치마요');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('짭조름함'), ('달콤함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '한솥도시락' and b.is_franchise and m.name = '참치마요';

-- 한솥도시락 / 도련님 도시락
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '도련님 도시락', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '한솥도시락' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '한솥도시락' and b.is_franchise and m.name = '도련님 도시락');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('닭고기', 'danger', 'AI 추정'), ('돼지고기', 'danger', 'AI 추정'), ('알류', 'danger', 'AI 추정'), ('밀', 'danger', 'AI 추정'), ('대두', 'danger', 'AI 추정'), ('쇠고기', 'caution', 'AI 추정'), ('우유', 'caution', 'AI 추정'), ('토마토', 'caution', 'AI 추정'), ('새우', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '한솥도시락' and b.is_franchise and m.name = '도련님 도시락';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '한솥도시락' and b.is_franchise and m.name = '도련님 도시락');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('짭조름함'), ('달콤함'), ('고소함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '한솥도시락' and b.is_franchise and m.name = '도련님 도시락';

-- 한솥도시락 / 동백 도시락
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '동백 도시락', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '한솥도시락' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '한솥도시락' and b.is_franchise and m.name = '동백 도시락');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('밀', 'danger', 'AI 추정'), ('대두', 'danger', 'AI 추정'), ('알류', 'danger', 'AI 추정'), ('닭고기', 'caution', 'AI 추정'), ('돼지고기', 'caution', 'AI 추정'), ('쇠고기', 'caution', 'AI 추정'), ('우유', 'caution', 'AI 추정'), ('토마토', 'caution', 'AI 추정'), ('새우', 'caution', 'AI 추정'), ('고등어', 'caution', 'AI 추정'), ('오징어', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '한솥도시락' and b.is_franchise and m.name = '동백 도시락';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '한솥도시락' and b.is_franchise and m.name = '동백 도시락');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('짭조름함'), ('달콤함'), ('고소함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '한솥도시락' and b.is_franchise and m.name = '동백 도시락';

-- 한솥도시락 / 매화 도시락
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '매화 도시락', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '한솥도시락' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '한솥도시락' and b.is_franchise and m.name = '매화 도시락');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('밀', 'danger', 'AI 추정'), ('대두', 'danger', 'AI 추정'), ('알류', 'danger', 'AI 추정'), ('닭고기', 'caution', 'AI 추정'), ('돼지고기', 'caution', 'AI 추정'), ('쇠고기', 'caution', 'AI 추정'), ('우유', 'caution', 'AI 추정'), ('토마토', 'caution', 'AI 추정'), ('새우', 'caution', 'AI 추정'), ('고등어', 'caution', 'AI 추정'), ('오징어', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '한솥도시락' and b.is_franchise and m.name = '매화 도시락';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '한솥도시락' and b.is_franchise and m.name = '매화 도시락');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('짭조름함'), ('달콤함'), ('고소함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '한솥도시락' and b.is_franchise and m.name = '매화 도시락';

-- 한솥도시락 / 제육볶음 도시락
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '제육볶음 도시락', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '한솥도시락' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '한솥도시락' and b.is_franchise and m.name = '제육볶음 도시락');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('돼지고기', 'danger', 'AI 추정'), ('대두', 'danger', 'AI 추정'), ('밀', 'danger', 'AI 추정'), ('알류', 'caution', 'AI 추정'), ('새우', 'caution', 'AI 추정'), ('조개류', 'caution', 'AI 추정'), ('우유', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '한솥도시락' and b.is_franchise and m.name = '제육볶음 도시락';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '한솥도시락' and b.is_franchise and m.name = '제육볶음 도시락');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('매콤함'), ('달콤함'), ('짭조름함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '한솥도시락' and b.is_franchise and m.name = '제육볶음 도시락';

-- 한솥도시락 / 돈까스도련님 도시락
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '돈까스도련님 도시락', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '한솥도시락' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '한솥도시락' and b.is_franchise and m.name = '돈까스도련님 도시락');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('돼지고기', 'danger', 'AI 추정'), ('밀', 'danger', 'AI 추정'), ('알류', 'danger', 'AI 추정'), ('대두', 'danger', 'AI 추정'), ('닭고기', 'danger', 'AI 추정'), ('쇠고기', 'caution', 'AI 추정'), ('우유', 'caution', 'AI 추정'), ('토마토', 'caution', 'AI 추정'), ('새우', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '한솥도시락' and b.is_franchise and m.name = '돈까스도련님 도시락';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '한솥도시락' and b.is_franchise and m.name = '돈까스도련님 도시락');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('짭조름함'), ('달콤함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '한솥도시락' and b.is_franchise and m.name = '돈까스도련님 도시락';

-- 한솥도시락 / 김치볶음밥
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '김치볶음밥', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '한솥도시락' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '한솥도시락' and b.is_franchise and m.name = '김치볶음밥');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('알류', 'danger', 'AI 추정'), ('새우', 'danger', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('밀', 'caution', 'AI 추정'), ('돼지고기', 'caution', 'AI 추정'), ('조개류', 'caution', 'AI 추정'), ('우유', 'caution', 'AI 추정'), ('고등어', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '한솥도시락' and b.is_franchise and m.name = '김치볶음밥';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '한솥도시락' and b.is_franchise and m.name = '김치볶음밥');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('매콤함'), ('새콤함'), ('짭조름함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '한솥도시락' and b.is_franchise and m.name = '김치볶음밥';

-- ===== 동대문엽기떡볶이 (메뉴 6개) =====
do $$
begin
  if not exists (select 1 from brands b where b.name = '동대문엽기떡볶이' and b.is_franchise) then
    raise exception '브랜드 동대문엽기떡볶이 이(가) 없어요. seed_branches.sql 을 먼저 실행하세요.';
  end if;
end;
$$;
update brands b set
  allergen_source_url = null, allergen_data_date = null::date,
  shared_notice = '지점에 따라 판매하지 않는 제품이 있을 수 있음', research_status = 'done', researched_at = now(), research_error = null
where b.name = '동대문엽기떡볶이' and b.is_franchise;

-- 동대문엽기떡볶이 / 엽기떡볶이
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '엽기떡볶이', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '동대문엽기떡볶이' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '동대문엽기떡볶이' and b.is_franchise and m.name = '엽기떡볶이');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('밀', 'danger', 'AI 추정'), ('대두', 'danger', 'AI 추정'), ('알류', 'caution', 'AI 추정'), ('우유', 'caution', 'AI 추정'), ('새우', 'caution', 'AI 추정'), ('게', 'caution', 'AI 추정'), ('오징어', 'caution', 'AI 추정'), ('조개류', 'caution', 'AI 추정'), ('닭고기', 'caution', 'AI 추정'), ('돼지고기', 'caution', 'AI 추정'), ('쇠고기', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정'), ('토마토', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '동대문엽기떡볶이' and b.is_franchise and m.name = '엽기떡볶이';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '동대문엽기떡볶이' and b.is_franchise and m.name = '엽기떡볶이');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('매콤함'), ('달콤함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '동대문엽기떡볶이' and b.is_franchise and m.name = '엽기떡볶이';

-- 동대문엽기떡볶이 / 엽기오뎅
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '엽기오뎅', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '동대문엽기떡볶이' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '동대문엽기떡볶이' and b.is_franchise and m.name = '엽기오뎅');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('밀', 'danger', 'AI 추정'), ('대두', 'danger', 'AI 추정'), ('알류', 'caution', 'AI 추정'), ('우유', 'caution', 'AI 추정'), ('새우', 'caution', 'AI 추정'), ('게', 'caution', 'AI 추정'), ('오징어', 'caution', 'AI 추정'), ('조개류', 'caution', 'AI 추정'), ('닭고기', 'caution', 'AI 추정'), ('돼지고기', 'caution', 'AI 추정'), ('쇠고기', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정'), ('토마토', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '동대문엽기떡볶이' and b.is_franchise and m.name = '엽기오뎅';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '동대문엽기떡볶이' and b.is_franchise and m.name = '엽기오뎅');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('매콤함'), ('달콤함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '동대문엽기떡볶이' and b.is_franchise and m.name = '엽기오뎅';

-- 동대문엽기떡볶이 / 엽기반반
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '엽기반반', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '동대문엽기떡볶이' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '동대문엽기떡볶이' and b.is_franchise and m.name = '엽기반반');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('밀', 'danger', 'AI 추정'), ('대두', 'danger', 'AI 추정'), ('알류', 'caution', 'AI 추정'), ('우유', 'caution', 'AI 추정'), ('새우', 'caution', 'AI 추정'), ('게', 'caution', 'AI 추정'), ('오징어', 'caution', 'AI 추정'), ('조개류', 'caution', 'AI 추정'), ('닭고기', 'caution', 'AI 추정'), ('돼지고기', 'caution', 'AI 추정'), ('쇠고기', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정'), ('토마토', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '동대문엽기떡볶이' and b.is_franchise and m.name = '엽기반반';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '동대문엽기떡볶이' and b.is_franchise and m.name = '엽기반반');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('매콤함'), ('달콤함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '동대문엽기떡볶이' and b.is_franchise and m.name = '엽기반반';

-- 동대문엽기떡볶이 / 엽기닭볶음탕
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '엽기닭볶음탕', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '동대문엽기떡볶이' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '동대문엽기떡볶이' and b.is_franchise and m.name = '엽기닭볶음탕');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('닭고기', 'danger', 'AI 추정'), ('대두', 'danger', 'AI 추정'), ('밀', 'danger', 'AI 추정'), ('알류', 'caution', 'AI 추정'), ('우유', 'caution', 'AI 추정'), ('새우', 'caution', 'AI 추정'), ('조개류', 'caution', 'AI 추정'), ('오징어', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정'), ('토마토', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '동대문엽기떡볶이' and b.is_franchise and m.name = '엽기닭볶음탕';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '동대문엽기떡볶이' and b.is_franchise and m.name = '엽기닭볶음탕');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('매콤함'), ('달콤함'), ('짭조름함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '동대문엽기떡볶이' and b.is_franchise and m.name = '엽기닭볶음탕';

-- 동대문엽기떡볶이 / 주먹김밥
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '주먹김밥', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '동대문엽기떡볶이' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '동대문엽기떡볶이' and b.is_franchise and m.name = '주먹김밥');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('대두', 'caution', 'AI 추정'), ('밀', 'caution', 'AI 추정'), ('알류', 'caution', 'AI 추정'), ('우유', 'caution', 'AI 추정'), ('돼지고기', 'caution', 'AI 추정'), ('새우', 'caution', 'AI 추정'), ('고등어', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '동대문엽기떡볶이' and b.is_franchise and m.name = '주먹김밥';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '동대문엽기떡볶이' and b.is_franchise and m.name = '주먹김밥');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('담백함'), ('짭조름함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '동대문엽기떡볶이' and b.is_franchise and m.name = '주먹김밥';

-- 동대문엽기떡볶이 / 계란찜
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '계란찜', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '동대문엽기떡볶이' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '동대문엽기떡볶이' and b.is_franchise and m.name = '계란찜');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('알류', 'danger', 'AI 추정'), ('새우', 'caution', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('밀', 'caution', 'AI 추정'), ('우유', 'caution', 'AI 추정'), ('조개류', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '동대문엽기떡볶이' and b.is_franchise and m.name = '계란찜';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '동대문엽기떡볶이' and b.is_franchise and m.name = '계란찜');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('담백함'), ('고소함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '동대문엽기떡볶이' and b.is_franchise and m.name = '계란찜';

-- ===== 원할머니보쌈족발 (메뉴 4개) =====
do $$
begin
  if not exists (select 1 from brands b where b.name = '원할머니보쌈족발' and b.is_franchise) then
    raise exception '브랜드 원할머니보쌈족발 이(가) 없어요. seed_branches.sql 을 먼저 실행하세요.';
  end if;
end;
$$;
update brands b set
  allergen_source_url = null, allergen_data_date = null::date,
  shared_notice = '지점에 따라 판매하지 않는 제품이 있을 수 있음', research_status = 'done', researched_at = now(), research_error = null
where b.name = '원할머니보쌈족발' and b.is_franchise;

-- 원할머니보쌈족발 / 보쌈
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '보쌈', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '원할머니보쌈족발' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '원할머니보쌈족발' and b.is_franchise and m.name = '보쌈');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('돼지고기', 'danger', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('밀', 'caution', 'AI 추정'), ('새우', 'caution', 'AI 추정'), ('조개류', 'caution', 'AI 추정'), ('오징어', 'caution', 'AI 추정'), ('고등어', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '원할머니보쌈족발' and b.is_franchise and m.name = '보쌈';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '원할머니보쌈족발' and b.is_franchise and m.name = '보쌈');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('담백함'), ('짭조름함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '원할머니보쌈족발' and b.is_franchise and m.name = '보쌈';

-- 원할머니보쌈족발 / 족발
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '족발', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '원할머니보쌈족발' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '원할머니보쌈족발' and b.is_franchise and m.name = '족발');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('돼지고기', 'danger', 'AI 추정'), ('대두', 'danger', 'AI 추정'), ('밀', 'danger', 'AI 추정'), ('새우', 'caution', 'AI 추정'), ('조개류', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '원할머니보쌈족발' and b.is_franchise and m.name = '족발';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '원할머니보쌈족발' and b.is_franchise and m.name = '족발');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('짭조름함'), ('달콤함'), ('고소함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '원할머니보쌈족발' and b.is_franchise and m.name = '족발';

-- 원할머니보쌈족발 / 보쌈정식
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '보쌈정식', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '원할머니보쌈족발' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '원할머니보쌈족발' and b.is_franchise and m.name = '보쌈정식');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('돼지고기', 'danger', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('밀', 'caution', 'AI 추정'), ('새우', 'caution', 'AI 추정'), ('조개류', 'caution', 'AI 추정'), ('오징어', 'caution', 'AI 추정'), ('알류', 'caution', 'AI 추정'), ('고등어', 'caution', 'AI 추정'), ('쇠고기', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '원할머니보쌈족발' and b.is_franchise and m.name = '보쌈정식';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '원할머니보쌈족발' and b.is_franchise and m.name = '보쌈정식');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('짭조름함'), ('담백함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '원할머니보쌈족발' and b.is_franchise and m.name = '보쌈정식';

-- 원할머니보쌈족발 / 막국수
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '막국수', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '원할머니보쌈족발' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '원할머니보쌈족발' and b.is_franchise and m.name = '막국수');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('메밀', 'danger', 'AI 추정'), ('밀', 'danger', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('알류', 'caution', 'AI 추정'), ('쇠고기', 'caution', 'AI 추정'), ('닭고기', 'caution', 'AI 추정'), ('돼지고기', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '원할머니보쌈족발' and b.is_franchise and m.name = '막국수';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '원할머니보쌈족발' and b.is_franchise and m.name = '막국수');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('새콤함'), ('매콤함'), ('달콤함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '원할머니보쌈족발' and b.is_franchise and m.name = '막국수';

-- ===== 명륜진사갈비 (메뉴 4개) =====
do $$
begin
  if not exists (select 1 from brands b where b.name = '명륜진사갈비' and b.is_franchise) then
    raise exception '브랜드 명륜진사갈비 이(가) 없어요. seed_branches.sql 을 먼저 실행하세요.';
  end if;
end;
$$;
update brands b set
  allergen_source_url = null, allergen_data_date = null::date,
  shared_notice = '지점에 따라 판매하지 않는 제품이 있을 수 있음', research_status = 'done', researched_at = now(), research_error = null
where b.name = '명륜진사갈비' and b.is_franchise;

-- 명륜진사갈비 / 숯불돼지갈비
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '숯불돼지갈비', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '명륜진사갈비' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '명륜진사갈비' and b.is_franchise and m.name = '숯불돼지갈비');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('돼지고기', 'danger', 'AI 추정'), ('대두', 'danger', 'AI 추정'), ('밀', 'danger', 'AI 추정'), ('아황산류', 'caution', 'AI 추정'), ('복숭아', 'caution', 'AI 추정'), ('토마토', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '명륜진사갈비' and b.is_franchise and m.name = '숯불돼지갈비';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '명륜진사갈비' and b.is_franchise and m.name = '숯불돼지갈비');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('달콤함'), ('짭조름함'), ('고소함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '명륜진사갈비' and b.is_franchise and m.name = '숯불돼지갈비';

-- 명륜진사갈비 / 된장찌개
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '된장찌개', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '명륜진사갈비' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '명륜진사갈비' and b.is_franchise and m.name = '된장찌개');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('대두', 'danger', 'AI 추정'), ('밀', 'danger', 'AI 추정'), ('조개류', 'caution', 'AI 추정'), ('새우', 'caution', 'AI 추정'), ('돼지고기', 'caution', 'AI 추정'), ('쇠고기', 'caution', 'AI 추정'), ('고등어', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '명륜진사갈비' and b.is_franchise and m.name = '된장찌개';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '명륜진사갈비' and b.is_franchise and m.name = '된장찌개');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('짭조름함'), ('감칠맛')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '명륜진사갈비' and b.is_franchise and m.name = '된장찌개';

-- 명륜진사갈비 / 물냉면
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '물냉면', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '명륜진사갈비' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '명륜진사갈비' and b.is_franchise and m.name = '물냉면');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('메밀', 'danger', 'AI 추정'), ('밀', 'danger', 'AI 추정'), ('쇠고기', 'danger', 'AI 추정'), ('알류', 'danger', 'AI 추정'), ('돼지고기', 'caution', 'AI 추정'), ('닭고기', 'caution', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '명륜진사갈비' and b.is_franchise and m.name = '물냉면';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '명륜진사갈비' and b.is_franchise and m.name = '물냉면');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('새콤함'), ('달콤함'), ('담백함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '명륜진사갈비' and b.is_franchise and m.name = '물냉면';

-- 명륜진사갈비 / 비빔냉면
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '비빔냉면', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '명륜진사갈비' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '명륜진사갈비' and b.is_franchise and m.name = '비빔냉면');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('메밀', 'danger', 'AI 추정'), ('밀', 'danger', 'AI 추정'), ('대두', 'danger', 'AI 추정'), ('알류', 'danger', 'AI 추정'), ('쇠고기', 'caution', 'AI 추정'), ('돼지고기', 'caution', 'AI 추정'), ('닭고기', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '명륜진사갈비' and b.is_franchise and m.name = '비빔냉면';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '명륜진사갈비' and b.is_franchise and m.name = '비빔냉면');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('매콤함'), ('달콤함'), ('새콤함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '명륜진사갈비' and b.is_franchise and m.name = '비빔냉면';

-- ===== 신전떡볶이 (메뉴 5개) =====
do $$
begin
  if not exists (select 1 from brands b where b.name = '신전떡볶이' and b.is_franchise) then
    raise exception '브랜드 신전떡볶이 이(가) 없어요. seed_branches.sql 을 먼저 실행하세요.';
  end if;
end;
$$;
update brands b set
  allergen_source_url = null, allergen_data_date = null::date,
  shared_notice = '지점에 따라 판매하지 않는 제품이 있을 수 있음', research_status = 'done', researched_at = now(), research_error = null
where b.name = '신전떡볶이' and b.is_franchise;

-- 신전떡볶이 / 신전떡볶이
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '신전떡볶이', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '신전떡볶이' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '신전떡볶이' and b.is_franchise and m.name = '신전떡볶이');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('밀', 'danger', 'AI 추정'), ('대두', 'danger', 'AI 추정'), ('알류', 'caution', 'AI 추정'), ('새우', 'caution', 'AI 추정'), ('게', 'caution', 'AI 추정'), ('오징어', 'caution', 'AI 추정'), ('조개류', 'caution', 'AI 추정'), ('고등어', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정'), ('쇠고기', 'caution', 'AI 추정'), ('돼지고기', 'caution', 'AI 추정'), ('닭고기', 'caution', 'AI 추정'), ('토마토', 'caution', 'AI 추정'), ('우유', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '신전떡볶이' and b.is_franchise and m.name = '신전떡볶이';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '신전떡볶이' and b.is_franchise and m.name = '신전떡볶이');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('매콤함'), ('달콤함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '신전떡볶이' and b.is_franchise and m.name = '신전떡볶이';

-- 신전떡볶이 / 신전치즈김밥
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '신전치즈김밥', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '신전떡볶이' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '신전떡볶이' and b.is_franchise and m.name = '신전치즈김밥');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('우유', 'danger', 'AI 추정'), ('알류', 'danger', 'AI 추정'), ('밀', 'caution', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('돼지고기', 'caution', 'AI 추정'), ('쇠고기', 'caution', 'AI 추정'), ('게', 'caution', 'AI 추정'), ('새우', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정'), ('땅콩', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '신전떡볶이' and b.is_franchise and m.name = '신전치즈김밥';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '신전떡볶이' and b.is_franchise and m.name = '신전치즈김밥');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('담백함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '신전떡볶이' and b.is_franchise and m.name = '신전치즈김밥';

-- 신전떡볶이 / 튀김오뎅
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '튀김오뎅', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '신전떡볶이' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '신전떡볶이' and b.is_franchise and m.name = '튀김오뎅');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('밀', 'danger', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('알류', 'caution', 'AI 추정'), ('새우', 'caution', 'AI 추정'), ('게', 'caution', 'AI 추정'), ('오징어', 'caution', 'AI 추정'), ('고등어', 'caution', 'AI 추정'), ('조개류', 'caution', 'AI 추정'), ('우유', 'caution', 'AI 추정'), ('돼지고기', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '신전떡볶이' and b.is_franchise and m.name = '튀김오뎅';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '신전떡볶이' and b.is_franchise and m.name = '튀김오뎅');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('느끼함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '신전떡볶이' and b.is_franchise and m.name = '튀김오뎅';

-- 신전떡볶이 / 모둠튀김
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '모둠튀김', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '신전떡볶이' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '신전떡볶이' and b.is_franchise and m.name = '모둠튀김');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('밀', 'danger', 'AI 추정'), ('알류', 'caution', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('새우', 'caution', 'AI 추정'), ('오징어', 'caution', 'AI 추정'), ('돼지고기', 'caution', 'AI 추정'), ('쇠고기', 'caution', 'AI 추정'), ('닭고기', 'caution', 'AI 추정'), ('우유', 'caution', 'AI 추정'), ('게', 'caution', 'AI 추정'), ('고등어', 'caution', 'AI 추정'), ('조개류', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '신전떡볶이' and b.is_franchise and m.name = '모둠튀김';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '신전떡볶이' and b.is_franchise and m.name = '모둠튀김');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('느끼함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '신전떡볶이' and b.is_franchise and m.name = '모둠튀김';

-- 신전떡볶이 / 참치마요컵밥
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '참치마요컵밥', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '신전떡볶이' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '신전떡볶이' and b.is_franchise and m.name = '참치마요컵밥');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('알류', 'danger', 'AI 추정'), ('대두', 'danger', 'AI 추정'), ('밀', 'caution', 'AI 추정'), ('우유', 'caution', 'AI 추정'), ('돼지고기', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정'), ('새우', 'caution', 'AI 추정'), ('게', 'caution', 'AI 추정'), ('고등어', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '신전떡볶이' and b.is_franchise and m.name = '참치마요컵밥';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '신전떡볶이' and b.is_franchise and m.name = '참치마요컵밥');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('짭조름함'), ('느끼함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '신전떡볶이' and b.is_franchise and m.name = '참치마요컵밥';

-- ===== 유가네닭갈비 (메뉴 4개) =====
do $$
begin
  if not exists (select 1 from brands b where b.name = '유가네닭갈비' and b.is_franchise) then
    raise exception '브랜드 유가네닭갈비 이(가) 없어요. seed_branches.sql 을 먼저 실행하세요.';
  end if;
end;
$$;
update brands b set
  allergen_source_url = null, allergen_data_date = null::date,
  shared_notice = '지점에 따라 판매하지 않는 제품이 있을 수 있음', research_status = 'done', researched_at = now(), research_error = null
where b.name = '유가네닭갈비' and b.is_franchise;

-- 유가네닭갈비 / 닭갈비
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '닭갈비', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '유가네닭갈비' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '유가네닭갈비' and b.is_franchise and m.name = '닭갈비');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('닭고기', 'danger', 'AI 추정'), ('대두', 'danger', 'AI 추정'), ('밀', 'danger', 'AI 추정'), ('조개류', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정'), ('우유', 'caution', 'AI 추정'), ('알류', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '유가네닭갈비' and b.is_franchise and m.name = '닭갈비';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '유가네닭갈비' and b.is_franchise and m.name = '닭갈비');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('매콤함'), ('달콤함'), ('감칠맛')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '유가네닭갈비' and b.is_franchise and m.name = '닭갈비';

-- 유가네닭갈비 / 치즈닭갈비
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '치즈닭갈비', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '유가네닭갈비' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '유가네닭갈비' and b.is_franchise and m.name = '치즈닭갈비');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('닭고기', 'danger', 'AI 추정'), ('대두', 'danger', 'AI 추정'), ('밀', 'danger', 'AI 추정'), ('우유', 'danger', 'AI 추정'), ('조개류', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정'), ('알류', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '유가네닭갈비' and b.is_franchise and m.name = '치즈닭갈비';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '유가네닭갈비' and b.is_franchise and m.name = '치즈닭갈비');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('매콤함'), ('고소함'), ('달콤함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '유가네닭갈비' and b.is_franchise and m.name = '치즈닭갈비';

-- 유가네닭갈비 / 닭야채철판볶음밥
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '닭야채철판볶음밥', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '유가네닭갈비' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '유가네닭갈비' and b.is_franchise and m.name = '닭야채철판볶음밥');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('닭고기', 'danger', 'AI 추정'), ('대두', 'danger', 'AI 추정'), ('밀', 'danger', 'AI 추정'), ('알류', 'caution', 'AI 추정'), ('우유', 'caution', 'AI 추정'), ('새우', 'caution', 'AI 추정'), ('조개류', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '유가네닭갈비' and b.is_franchise and m.name = '닭야채철판볶음밥';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '유가네닭갈비' and b.is_franchise and m.name = '닭야채철판볶음밥');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('매콤함'), ('고소함'), ('감칠맛')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '유가네닭갈비' and b.is_franchise and m.name = '닭야채철판볶음밥';

-- 유가네닭갈비 / 철판볶음밥
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '철판볶음밥', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '유가네닭갈비' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '유가네닭갈비' and b.is_franchise and m.name = '철판볶음밥');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('대두', 'danger', 'AI 추정'), ('밀', 'danger', 'AI 추정'), ('닭고기', 'caution', 'AI 추정'), ('알류', 'caution', 'AI 추정'), ('우유', 'caution', 'AI 추정'), ('새우', 'caution', 'AI 추정'), ('조개류', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정'), ('돼지고기', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '유가네닭갈비' and b.is_franchise and m.name = '철판볶음밥';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '유가네닭갈비' and b.is_franchise and m.name = '철판볶음밥');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('매콤함'), ('고소함'), ('감칠맛')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '유가네닭갈비' and b.is_franchise and m.name = '철판볶음밥';

-- ===== 홍콩반점0410 (메뉴 7개) =====
do $$
begin
  if not exists (select 1 from brands b where b.name = '홍콩반점0410' and b.is_franchise) then
    raise exception '브랜드 홍콩반점0410 이(가) 없어요. seed_branches.sql 을 먼저 실행하세요.';
  end if;
end;
$$;
update brands b set
  allergen_source_url = null, allergen_data_date = null::date,
  shared_notice = '지점에 따라 판매하지 않는 제품이 있을 수 있음', research_status = 'done', researched_at = now(), research_error = null
where b.name = '홍콩반점0410' and b.is_franchise;

-- 홍콩반점0410 / 짜장면
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '짜장면', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '홍콩반점0410' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '홍콩반점0410' and b.is_franchise and m.name = '짜장면');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('밀', 'danger', 'AI 추정'), ('대두', 'danger', 'AI 추정'), ('돼지고기', 'danger', 'AI 추정'), ('오징어', 'caution', 'AI 추정'), ('새우', 'caution', 'AI 추정'), ('조개류', 'caution', 'AI 추정'), ('닭고기', 'caution', 'AI 추정'), ('쇠고기', 'caution', 'AI 추정'), ('알류', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '홍콩반점0410' and b.is_franchise and m.name = '짜장면';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '홍콩반점0410' and b.is_franchise and m.name = '짜장면');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('짭조름함'), ('달콤함'), ('고소함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '홍콩반점0410' and b.is_franchise and m.name = '짜장면';

-- 홍콩반점0410 / 짬뽕
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '짬뽕', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '홍콩반점0410' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '홍콩반점0410' and b.is_franchise and m.name = '짬뽕');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('밀', 'danger', 'AI 추정'), ('오징어', 'danger', 'AI 추정'), ('조개류', 'danger', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('새우', 'caution', 'AI 추정'), ('돼지고기', 'caution', 'AI 추정'), ('닭고기', 'caution', 'AI 추정'), ('쇠고기', 'caution', 'AI 추정'), ('게', 'caution', 'AI 추정'), ('알류', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '홍콩반점0410' and b.is_franchise and m.name = '짬뽕';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '홍콩반점0410' and b.is_franchise and m.name = '짬뽕');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('매콤함'), ('감칠맛')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '홍콩반점0410' and b.is_franchise and m.name = '짬뽕';

-- 홍콩반점0410 / 탕수육
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '탕수육', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '홍콩반점0410' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '홍콩반점0410' and b.is_franchise and m.name = '탕수육');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('돼지고기', 'danger', 'AI 추정'), ('밀', 'caution', 'AI 추정'), ('알류', 'caution', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('토마토', 'caution', 'AI 추정'), ('복숭아', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '홍콩반점0410' and b.is_franchise and m.name = '탕수육';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '홍콩반점0410' and b.is_franchise and m.name = '탕수육');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('달콤함'), ('새콤함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '홍콩반점0410' and b.is_franchise and m.name = '탕수육';

-- 홍콩반점0410 / 볶음밥
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '볶음밥', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '홍콩반점0410' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '홍콩반점0410' and b.is_franchise and m.name = '볶음밥');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('알류', 'danger', 'AI 추정'), ('돼지고기', 'caution', 'AI 추정'), ('새우', 'caution', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('밀', 'caution', 'AI 추정'), ('조개류', 'caution', 'AI 추정'), ('오징어', 'caution', 'AI 추정'), ('닭고기', 'caution', 'AI 추정'), ('쇠고기', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '홍콩반점0410' and b.is_franchise and m.name = '볶음밥';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '홍콩반점0410' and b.is_franchise and m.name = '볶음밥');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('짭조름함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '홍콩반점0410' and b.is_franchise and m.name = '볶음밥';

-- 홍콩반점0410 / 군만두
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '군만두', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '홍콩반점0410' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '홍콩반점0410' and b.is_franchise and m.name = '군만두');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('밀', 'danger', 'AI 추정'), ('돼지고기', 'danger', 'AI 추정'), ('대두', 'danger', 'AI 추정'), ('알류', 'caution', 'AI 추정'), ('쇠고기', 'caution', 'AI 추정'), ('닭고기', 'caution', 'AI 추정'), ('새우', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '홍콩반점0410' and b.is_franchise and m.name = '군만두';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '홍콩반점0410' and b.is_franchise and m.name = '군만두');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('짭조름함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '홍콩반점0410' and b.is_franchise and m.name = '군만두';

-- 홍콩반점0410 / 쟁반짜장
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '쟁반짜장', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '홍콩반점0410' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '홍콩반점0410' and b.is_franchise and m.name = '쟁반짜장');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('밀', 'danger', 'AI 추정'), ('대두', 'danger', 'AI 추정'), ('돼지고기', 'danger', 'AI 추정'), ('오징어', 'caution', 'AI 추정'), ('새우', 'caution', 'AI 추정'), ('조개류', 'caution', 'AI 추정'), ('알류', 'caution', 'AI 추정'), ('닭고기', 'caution', 'AI 추정'), ('쇠고기', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '홍콩반점0410' and b.is_franchise and m.name = '쟁반짜장';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '홍콩반점0410' and b.is_franchise and m.name = '쟁반짜장');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('짭조름함'), ('달콤함'), ('고소함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '홍콩반점0410' and b.is_franchise and m.name = '쟁반짜장';

-- 홍콩반점0410 / 짬뽕밥
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '짬뽕밥', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '홍콩반점0410' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '홍콩반점0410' and b.is_franchise and m.name = '짬뽕밥');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('오징어', 'danger', 'AI 추정'), ('조개류', 'danger', 'AI 추정'), ('밀', 'caution', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('새우', 'caution', 'AI 추정'), ('돼지고기', 'caution', 'AI 추정'), ('닭고기', 'caution', 'AI 추정'), ('쇠고기', 'caution', 'AI 추정'), ('게', 'caution', 'AI 추정'), ('알류', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '홍콩반점0410' and b.is_franchise and m.name = '짬뽕밥';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '홍콩반점0410' and b.is_franchise and m.name = '짬뽕밥');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('매콤함'), ('감칠맛')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '홍콩반점0410' and b.is_franchise and m.name = '짬뽕밥';

-- ===== 역전우동0410 (메뉴 7개) =====
do $$
begin
  if not exists (select 1 from brands b where b.name = '역전우동0410' and b.is_franchise) then
    raise exception '브랜드 역전우동0410 이(가) 없어요. seed_branches.sql 을 먼저 실행하세요.';
  end if;
end;
$$;
update brands b set
  allergen_source_url = null, allergen_data_date = null::date,
  shared_notice = '지점에 따라 판매하지 않는 제품이 있을 수 있음', research_status = 'done', researched_at = now(), research_error = null
where b.name = '역전우동0410' and b.is_franchise;

-- 역전우동0410 / 옛날우동
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '옛날우동', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '역전우동0410' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '역전우동0410' and b.is_franchise and m.name = '옛날우동');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('밀', 'danger', 'AI 추정'), ('대두', 'danger', 'AI 추정'), ('알류', 'caution', 'AI 추정'), ('고등어', 'caution', 'AI 추정'), ('새우', 'caution', 'AI 추정'), ('게', 'caution', 'AI 추정'), ('조개류', 'caution', 'AI 추정'), ('오징어', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '역전우동0410' and b.is_franchise and m.name = '옛날우동';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '역전우동0410' and b.is_franchise and m.name = '옛날우동');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('담백함'), ('짭조름함'), ('감칠맛')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '역전우동0410' and b.is_franchise and m.name = '옛날우동';

-- 역전우동0410 / 어묵우동
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '어묵우동', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '역전우동0410' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '역전우동0410' and b.is_franchise and m.name = '어묵우동');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('밀', 'danger', 'AI 추정'), ('대두', 'danger', 'AI 추정'), ('알류', 'caution', 'AI 추정'), ('고등어', 'caution', 'AI 추정'), ('새우', 'caution', 'AI 추정'), ('게', 'caution', 'AI 추정'), ('오징어', 'caution', 'AI 추정'), ('조개류', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '역전우동0410' and b.is_franchise and m.name = '어묵우동';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '역전우동0410' and b.is_franchise and m.name = '어묵우동');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('짭조름함'), ('감칠맛'), ('담백함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '역전우동0410' and b.is_franchise and m.name = '어묵우동';

-- 역전우동0410 / 튀김우동
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '튀김우동', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '역전우동0410' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '역전우동0410' and b.is_franchise and m.name = '튀김우동');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('밀', 'danger', 'AI 추정'), ('대두', 'danger', 'AI 추정'), ('새우', 'caution', 'AI 추정'), ('알류', 'caution', 'AI 추정'), ('고등어', 'caution', 'AI 추정'), ('게', 'caution', 'AI 추정'), ('오징어', 'caution', 'AI 추정'), ('조개류', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '역전우동0410' and b.is_franchise and m.name = '튀김우동';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '역전우동0410' and b.is_franchise and m.name = '튀김우동');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('짭조름함'), ('감칠맛')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '역전우동0410' and b.is_franchise and m.name = '튀김우동';

-- 역전우동0410 / 김치우동
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '김치우동', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '역전우동0410' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '역전우동0410' and b.is_franchise and m.name = '김치우동');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('밀', 'danger', 'AI 추정'), ('대두', 'danger', 'AI 추정'), ('새우', 'caution', 'AI 추정'), ('돼지고기', 'caution', 'AI 추정'), ('알류', 'caution', 'AI 추정'), ('고등어', 'caution', 'AI 추정'), ('게', 'caution', 'AI 추정'), ('오징어', 'caution', 'AI 추정'), ('조개류', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '역전우동0410' and b.is_franchise and m.name = '김치우동';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '역전우동0410' and b.is_franchise and m.name = '김치우동');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('매콤함'), ('짭조름함'), ('감칠맛')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '역전우동0410' and b.is_franchise and m.name = '김치우동';

-- 역전우동0410 / 냉모밀
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '냉모밀', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '역전우동0410' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '역전우동0410' and b.is_franchise and m.name = '냉모밀');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('메밀', 'danger', 'AI 추정'), ('밀', 'danger', 'AI 추정'), ('대두', 'danger', 'AI 추정'), ('고등어', 'caution', 'AI 추정'), ('알류', 'caution', 'AI 추정'), ('새우', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '역전우동0410' and b.is_franchise and m.name = '냉모밀';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '역전우동0410' and b.is_franchise and m.name = '냉모밀');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('짭조름함'), ('담백함'), ('달콤함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '역전우동0410' and b.is_franchise and m.name = '냉모밀';

-- 역전우동0410 / 돈까스
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '돈까스', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '역전우동0410' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '역전우동0410' and b.is_franchise and m.name = '돈까스');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('돼지고기', 'danger', 'AI 추정'), ('밀', 'danger', 'AI 추정'), ('알류', 'danger', 'AI 추정'), ('우유', 'caution', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('토마토', 'caution', 'AI 추정'), ('쇠고기', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정'), ('닭고기', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '역전우동0410' and b.is_franchise and m.name = '돈까스';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '역전우동0410' and b.is_franchise and m.name = '돈까스');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('달콤함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '역전우동0410' and b.is_franchise and m.name = '돈까스';

-- 역전우동0410 / 제육덮밥
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '제육덮밥', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '역전우동0410' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '역전우동0410' and b.is_franchise and m.name = '제육덮밥');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('돼지고기', 'danger', 'AI 추정'), ('대두', 'danger', 'AI 추정'), ('밀', 'danger', 'AI 추정'), ('알류', 'caution', 'AI 추정'), ('조개류', 'caution', 'AI 추정'), ('토마토', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '역전우동0410' and b.is_franchise and m.name = '제육덮밥';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '역전우동0410' and b.is_franchise and m.name = '제육덮밥');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('매콤함'), ('달콤함'), ('짭조름함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '역전우동0410' and b.is_franchise and m.name = '제육덮밥';

-- ===== 아비꼬 (메뉴 6개) =====
do $$
begin
  if not exists (select 1 from brands b where b.name = '아비꼬' and b.is_franchise) then
    raise exception '브랜드 아비꼬 이(가) 없어요. seed_branches.sql 을 먼저 실행하세요.';
  end if;
end;
$$;
update brands b set
  allergen_source_url = null, allergen_data_date = null::date,
  shared_notice = '지점에 따라 판매하지 않는 제품이 있을 수 있음', research_status = 'done', researched_at = now(), research_error = null
where b.name = '아비꼬' and b.is_franchise;

-- 아비꼬 / 카레라이스
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '카레라이스', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '아비꼬' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '아비꼬' and b.is_franchise and m.name = '카레라이스');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('밀', 'danger', 'AI 추정'), ('우유', 'caution', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('돼지고기', 'caution', 'AI 추정'), ('쇠고기', 'caution', 'AI 추정'), ('닭고기', 'caution', 'AI 추정'), ('토마토', 'caution', 'AI 추정'), ('땅콩', 'caution', 'AI 추정'), ('알류', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '아비꼬' and b.is_franchise and m.name = '카레라이스';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '아비꼬' and b.is_franchise and m.name = '카레라이스');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('매콤함'), ('감칠맛'), ('느끼함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '아비꼬' and b.is_franchise and m.name = '카레라이스';

-- 아비꼬 / 카레우동
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '카레우동', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '아비꼬' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '아비꼬' and b.is_franchise and m.name = '카레우동');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('밀', 'danger', 'AI 추정'), ('우유', 'caution', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('고등어', 'caution', 'AI 추정'), ('돼지고기', 'caution', 'AI 추정'), ('쇠고기', 'caution', 'AI 추정'), ('닭고기', 'caution', 'AI 추정'), ('토마토', 'caution', 'AI 추정'), ('땅콩', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '아비꼬' and b.is_franchise and m.name = '카레우동';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '아비꼬' and b.is_franchise and m.name = '카레우동');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('매콤함'), ('감칠맛'), ('짭조름함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '아비꼬' and b.is_franchise and m.name = '카레우동';

-- 아비꼬 / 돈까스 카레
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '돈까스 카레', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '아비꼬' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '아비꼬' and b.is_franchise and m.name = '돈까스 카레');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('밀', 'danger', 'AI 추정'), ('돼지고기', 'danger', 'AI 추정'), ('알류', 'danger', 'AI 추정'), ('우유', 'caution', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('쇠고기', 'caution', 'AI 추정'), ('닭고기', 'caution', 'AI 추정'), ('토마토', 'caution', 'AI 추정'), ('땅콩', 'caution', 'AI 추정'), ('새우', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '아비꼬' and b.is_franchise and m.name = '돈까스 카레';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '아비꼬' and b.is_franchise and m.name = '돈까스 카레');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('매콤함'), ('고소함'), ('감칠맛')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '아비꼬' and b.is_franchise and m.name = '돈까스 카레';

-- 아비꼬 / 새우튀김 카레
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '새우튀김 카레', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '아비꼬' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '아비꼬' and b.is_franchise and m.name = '새우튀김 카레');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('밀', 'danger', 'AI 추정'), ('새우', 'danger', 'AI 추정'), ('알류', 'caution', 'AI 추정'), ('우유', 'caution', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('돼지고기', 'caution', 'AI 추정'), ('쇠고기', 'caution', 'AI 추정'), ('닭고기', 'caution', 'AI 추정'), ('토마토', 'caution', 'AI 추정'), ('땅콩', 'caution', 'AI 추정'), ('게', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '아비꼬' and b.is_franchise and m.name = '새우튀김 카레';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '아비꼬' and b.is_franchise and m.name = '새우튀김 카레');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('매콤함'), ('고소함'), ('감칠맛')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '아비꼬' and b.is_franchise and m.name = '새우튀김 카레';

-- 아비꼬 / 치킨가라아게 카레
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '치킨가라아게 카레', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '아비꼬' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '아비꼬' and b.is_franchise and m.name = '치킨가라아게 카레');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('밀', 'danger', 'AI 추정'), ('닭고기', 'danger', 'AI 추정'), ('대두', 'danger', 'AI 추정'), ('알류', 'caution', 'AI 추정'), ('우유', 'caution', 'AI 추정'), ('돼지고기', 'caution', 'AI 추정'), ('쇠고기', 'caution', 'AI 추정'), ('토마토', 'caution', 'AI 추정'), ('땅콩', 'caution', 'AI 추정'), ('새우', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '아비꼬' and b.is_franchise and m.name = '치킨가라아게 카레';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '아비꼬' and b.is_franchise and m.name = '치킨가라아게 카레');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('매콤함'), ('고소함'), ('짭조름함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '아비꼬' and b.is_franchise and m.name = '치킨가라아게 카레';

-- 아비꼬 / 하이라이스
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '하이라이스', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '아비꼬' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '아비꼬' and b.is_franchise and m.name = '하이라이스');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('쇠고기', 'danger', 'AI 추정'), ('밀', 'danger', 'AI 추정'), ('토마토', 'danger', 'AI 추정'), ('우유', 'caution', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('돼지고기', 'caution', 'AI 추정'), ('닭고기', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '아비꼬' and b.is_franchise and m.name = '하이라이스';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '아비꼬' and b.is_franchise and m.name = '하이라이스');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('새콤함'), ('달콤함'), ('감칠맛')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '아비꼬' and b.is_franchise and m.name = '하이라이스';

-- ===== 코코이찌방야 (메뉴 7개) =====
do $$
begin
  if not exists (select 1 from brands b where b.name = '코코이찌방야' and b.is_franchise) then
    raise exception '브랜드 코코이찌방야 이(가) 없어요. seed_branches.sql 을 먼저 실행하세요.';
  end if;
end;
$$;
update brands b set
  allergen_source_url = null, allergen_data_date = null::date,
  shared_notice = '지점에 따라 판매하지 않는 제품이 있을 수 있음', research_status = 'done', researched_at = now(), research_error = null
where b.name = '코코이찌방야' and b.is_franchise;

-- 코코이찌방야 / 포크카레
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '포크카레', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '코코이찌방야' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '코코이찌방야' and b.is_franchise and m.name = '포크카레');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('돼지고기', 'danger', 'AI 추정'), ('밀', 'danger', 'AI 추정'), ('우유', 'caution', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('쇠고기', 'caution', 'AI 추정'), ('닭고기', 'caution', 'AI 추정'), ('토마토', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '코코이찌방야' and b.is_franchise and m.name = '포크카레';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '코코이찌방야' and b.is_franchise and m.name = '포크카레');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('감칠맛'), ('짭조름함'), ('매콤함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '코코이찌방야' and b.is_franchise and m.name = '포크카레';

-- 코코이찌방야 / 비프카레
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '비프카레', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '코코이찌방야' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '코코이찌방야' and b.is_franchise and m.name = '비프카레');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('쇠고기', 'danger', 'AI 추정'), ('밀', 'danger', 'AI 추정'), ('우유', 'caution', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('돼지고기', 'caution', 'AI 추정'), ('닭고기', 'caution', 'AI 추정'), ('토마토', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '코코이찌방야' and b.is_franchise and m.name = '비프카레';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '코코이찌방야' and b.is_franchise and m.name = '비프카레');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('감칠맛'), ('짭조름함'), ('매콤함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '코코이찌방야' and b.is_franchise and m.name = '비프카레';

-- 코코이찌방야 / 로스까스카레
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '로스까스카레', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '코코이찌방야' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '코코이찌방야' and b.is_franchise and m.name = '로스까스카레');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('돼지고기', 'danger', 'AI 추정'), ('밀', 'danger', 'AI 추정'), ('알류', 'danger', 'AI 추정'), ('우유', 'caution', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('쇠고기', 'caution', 'AI 추정'), ('닭고기', 'caution', 'AI 추정'), ('토마토', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '코코이찌방야' and b.is_franchise and m.name = '로스까스카레';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '코코이찌방야' and b.is_franchise and m.name = '로스까스카레');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('감칠맛'), ('짭조름함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '코코이찌방야' and b.is_franchise and m.name = '로스까스카레';

-- 코코이찌방야 / 치킨까스카레
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '치킨까스카레', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '코코이찌방야' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '코코이찌방야' and b.is_franchise and m.name = '치킨까스카레');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('닭고기', 'danger', 'AI 추정'), ('밀', 'danger', 'AI 추정'), ('알류', 'danger', 'AI 추정'), ('우유', 'caution', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('돼지고기', 'caution', 'AI 추정'), ('쇠고기', 'caution', 'AI 추정'), ('토마토', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '코코이찌방야' and b.is_franchise and m.name = '치킨까스카레';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '코코이찌방야' and b.is_franchise and m.name = '치킨까스카레');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('감칠맛'), ('짭조름함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '코코이찌방야' and b.is_franchise and m.name = '치킨까스카레';

-- 코코이찌방야 / 해물카레
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '해물카레', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '코코이찌방야' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '코코이찌방야' and b.is_franchise and m.name = '해물카레');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('밀', 'danger', 'AI 추정'), ('새우', 'danger', 'AI 추정'), ('오징어', 'caution', 'AI 추정'), ('조개류', 'caution', 'AI 추정'), ('게', 'caution', 'AI 추정'), ('우유', 'caution', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('돼지고기', 'caution', 'AI 추정'), ('쇠고기', 'caution', 'AI 추정'), ('닭고기', 'caution', 'AI 추정'), ('토마토', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '코코이찌방야' and b.is_franchise and m.name = '해물카레';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '코코이찌방야' and b.is_franchise and m.name = '해물카레');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('감칠맛'), ('짭조름함'), ('매콤함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '코코이찌방야' and b.is_franchise and m.name = '해물카레';

-- 코코이찌방야 / 야채카레
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '야채카레', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '코코이찌방야' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '코코이찌방야' and b.is_franchise and m.name = '야채카레');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('밀', 'danger', 'AI 추정'), ('우유', 'caution', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('돼지고기', 'caution', 'AI 추정'), ('쇠고기', 'caution', 'AI 추정'), ('닭고기', 'caution', 'AI 추정'), ('토마토', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '코코이찌방야' and b.is_franchise and m.name = '야채카레';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '코코이찌방야' and b.is_franchise and m.name = '야채카레');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('감칠맛'), ('달콤함'), ('매콤함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '코코이찌방야' and b.is_franchise and m.name = '야채카레';

-- 코코이찌방야 / 카레우동
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '카레우동', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '코코이찌방야' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '코코이찌방야' and b.is_franchise and m.name = '카레우동');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('밀', 'danger', 'AI 추정'), ('대두', 'danger', 'AI 추정'), ('우유', 'caution', 'AI 추정'), ('돼지고기', 'caution', 'AI 추정'), ('쇠고기', 'caution', 'AI 추정'), ('닭고기', 'caution', 'AI 추정'), ('고등어', 'caution', 'AI 추정'), ('토마토', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '코코이찌방야' and b.is_franchise and m.name = '카레우동';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '코코이찌방야' and b.is_franchise and m.name = '카레우동');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('감칠맛'), ('짭조름함'), ('매콤함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '코코이찌방야' and b.is_franchise and m.name = '카레우동';

-- ===== 미소야 (메뉴 7개) =====
do $$
begin
  if not exists (select 1 from brands b where b.name = '미소야' and b.is_franchise) then
    raise exception '브랜드 미소야 이(가) 없어요. seed_branches.sql 을 먼저 실행하세요.';
  end if;
end;
$$;
update brands b set
  allergen_source_url = null, allergen_data_date = null::date,
  shared_notice = '지점에 따라 판매하지 않는 제품이 있을 수 있음', research_status = 'done', researched_at = now(), research_error = null
where b.name = '미소야' and b.is_franchise;

-- 미소야 / 로스까스
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '로스까스', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '미소야' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '미소야' and b.is_franchise and m.name = '로스까스');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('돼지고기', 'danger', 'AI 추정'), ('밀', 'danger', 'AI 추정'), ('알류', 'danger', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('토마토', 'caution', 'AI 추정'), ('우유', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정'), ('땅콩', 'caution', 'AI 추정'), ('복숭아', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '미소야' and b.is_franchise and m.name = '로스까스';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '미소야' and b.is_franchise and m.name = '로스까스');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('달콤함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '미소야' and b.is_franchise and m.name = '로스까스';

-- 미소야 / 히레까스
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '히레까스', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '미소야' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '미소야' and b.is_franchise and m.name = '히레까스');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('돼지고기', 'danger', 'AI 추정'), ('밀', 'danger', 'AI 추정'), ('알류', 'danger', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('토마토', 'caution', 'AI 추정'), ('우유', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정'), ('땅콩', 'caution', 'AI 추정'), ('복숭아', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '미소야' and b.is_franchise and m.name = '히레까스';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '미소야' and b.is_franchise and m.name = '히레까스');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('담백함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '미소야' and b.is_franchise and m.name = '히레까스';

-- 미소야 / 치즈까스
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '치즈까스', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '미소야' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '미소야' and b.is_franchise and m.name = '치즈까스');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('돼지고기', 'danger', 'AI 추정'), ('밀', 'danger', 'AI 추정'), ('알류', 'danger', 'AI 추정'), ('우유', 'danger', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('토마토', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정'), ('땅콩', 'caution', 'AI 추정'), ('복숭아', 'caution', 'AI 추정'), ('닭고기', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '미소야' and b.is_franchise and m.name = '치즈까스';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '미소야' and b.is_franchise and m.name = '치즈까스');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('느끼함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '미소야' and b.is_franchise and m.name = '치즈까스';

-- 미소야 / 가츠동
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '가츠동', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '미소야' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '미소야' and b.is_franchise and m.name = '가츠동');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('돼지고기', 'danger', 'AI 추정'), ('밀', 'danger', 'AI 추정'), ('알류', 'danger', 'AI 추정'), ('대두', 'danger', 'AI 추정'), ('우유', 'caution', 'AI 추정'), ('고등어', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정'), ('토마토', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '미소야' and b.is_franchise and m.name = '가츠동';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '미소야' and b.is_franchise and m.name = '가츠동');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('달콤함'), ('짭조름함'), ('고소함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '미소야' and b.is_franchise and m.name = '가츠동';

-- 미소야 / 냉모밀
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '냉모밀', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '미소야' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '미소야' and b.is_franchise and m.name = '냉모밀');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('메밀', 'danger', 'AI 추정'), ('밀', 'danger', 'AI 추정'), ('대두', 'danger', 'AI 추정'), ('고등어', 'caution', 'AI 추정'), ('알류', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '미소야' and b.is_franchise and m.name = '냉모밀';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '미소야' and b.is_franchise and m.name = '냉모밀');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('짭조름함'), ('달콤함'), ('담백함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '미소야' and b.is_franchise and m.name = '냉모밀';

-- 미소야 / 김치우동
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '김치우동', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '미소야' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '미소야' and b.is_franchise and m.name = '김치우동');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('밀', 'danger', 'AI 추정'), ('대두', 'danger', 'AI 추정'), ('새우', 'caution', 'AI 추정'), ('고등어', 'caution', 'AI 추정'), ('조개류', 'caution', 'AI 추정'), ('돼지고기', 'caution', 'AI 추정'), ('오징어', 'caution', 'AI 추정'), ('알류', 'caution', 'AI 추정'), ('닭고기', 'caution', 'AI 추정'), ('쇠고기', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '미소야' and b.is_franchise and m.name = '김치우동';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '미소야' and b.is_franchise and m.name = '김치우동');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('매콤함'), ('짭조름함'), ('감칠맛')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '미소야' and b.is_franchise and m.name = '김치우동';

-- 미소야 / 알밥
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '알밥', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '미소야' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '미소야' and b.is_franchise and m.name = '알밥');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('알류', 'caution', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('밀', 'caution', 'AI 추정'), ('게', 'caution', 'AI 추정'), ('새우', 'caution', 'AI 추정'), ('돼지고기', 'caution', 'AI 추정'), ('우유', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정'), ('고등어', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '미소야' and b.is_franchise and m.name = '알밥';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '미소야' and b.is_franchise and m.name = '알밥');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('짭조름함'), ('감칠맛')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '미소야' and b.is_franchise and m.name = '알밥';

-- ===== 스타벅스 (메뉴 6개) =====
do $$
begin
  if not exists (select 1 from brands b where b.name = '스타벅스' and b.is_franchise) then
    raise exception '브랜드 스타벅스 이(가) 없어요. seed_branches.sql 을 먼저 실행하세요.';
  end if;
end;
$$;
update brands b set
  allergen_source_url = null, allergen_data_date = null::date,
  shared_notice = '지점에 따라 판매하지 않는 제품이 있을 수 있음', research_status = 'done', researched_at = now(), research_error = null
where b.name = '스타벅스' and b.is_franchise;

-- 스타벅스 / 아메리카노
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '아메리카노', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '스타벅스' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '스타벅스' and b.is_franchise and m.name = '아메리카노');
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '스타벅스' and b.is_franchise and m.name = '아메리카노');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('쌉싸름함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '스타벅스' and b.is_franchise and m.name = '아메리카노';

-- 스타벅스 / 카페 라떼
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '카페 라떼', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '스타벅스' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '스타벅스' and b.is_franchise and m.name = '카페 라떼');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('우유', 'danger', 'AI 추정'), ('대두', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '스타벅스' and b.is_franchise and m.name = '카페 라떼';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '스타벅스' and b.is_franchise and m.name = '카페 라떼');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('쌉싸름함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '스타벅스' and b.is_franchise and m.name = '카페 라떼';

-- 스타벅스 / 카라멜 마키아또
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '카라멜 마키아또', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '스타벅스' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '스타벅스' and b.is_franchise and m.name = '카라멜 마키아또');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('우유', 'danger', 'AI 추정'), ('대두', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '스타벅스' and b.is_franchise and m.name = '카라멜 마키아또';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '스타벅스' and b.is_franchise and m.name = '카라멜 마키아또');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('달콤함'), ('쌉싸름함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '스타벅스' and b.is_franchise and m.name = '카라멜 마키아또';

-- 스타벅스 / 자바 칩 프라푸치노
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '자바 칩 프라푸치노', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '스타벅스' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '스타벅스' and b.is_franchise and m.name = '자바 칩 프라푸치노');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('우유', 'danger', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('밀', 'caution', 'AI 추정'), ('알류', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '스타벅스' and b.is_franchise and m.name = '자바 칩 프라푸치노';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '스타벅스' and b.is_franchise and m.name = '자바 칩 프라푸치노');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('달콤함'), ('쌉싸름함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '스타벅스' and b.is_franchise and m.name = '자바 칩 프라푸치노';

-- 스타벅스 / 돌체 라떼
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '돌체 라떼', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '스타벅스' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '스타벅스' and b.is_franchise and m.name = '돌체 라떼');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('우유', 'danger', 'AI 추정'), ('대두', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '스타벅스' and b.is_franchise and m.name = '돌체 라떼';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '스타벅스' and b.is_franchise and m.name = '돌체 라떼');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('달콤함'), ('고소함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '스타벅스' and b.is_franchise and m.name = '돌체 라떼';

-- 스타벅스 / 자몽 허니 블랙 티
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '자몽 허니 블랙 티', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '스타벅스' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '스타벅스' and b.is_franchise and m.name = '자몽 허니 블랙 티');
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '스타벅스' and b.is_franchise and m.name = '자몽 허니 블랙 티');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('새콤함'), ('달콤함'), ('쌉싸름함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '스타벅스' and b.is_franchise and m.name = '자몽 허니 블랙 티';

-- ===== 투썸플레이스 (메뉴 5개) =====
do $$
begin
  if not exists (select 1 from brands b where b.name = '투썸플레이스' and b.is_franchise) then
    raise exception '브랜드 투썸플레이스 이(가) 없어요. seed_branches.sql 을 먼저 실행하세요.';
  end if;
end;
$$;
update brands b set
  allergen_source_url = null, allergen_data_date = null::date,
  shared_notice = '지점에 따라 판매하지 않는 제품이 있을 수 있음', research_status = 'done', researched_at = now(), research_error = null
where b.name = '투썸플레이스' and b.is_franchise;

-- 투썸플레이스 / 아메리카노
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '아메리카노', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '투썸플레이스' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '투썸플레이스' and b.is_franchise and m.name = '아메리카노');
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '투썸플레이스' and b.is_franchise and m.name = '아메리카노');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('쌉싸름함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '투썸플레이스' and b.is_franchise and m.name = '아메리카노';

-- 투썸플레이스 / 카페 라떼
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '카페 라떼', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '투썸플레이스' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '투썸플레이스' and b.is_franchise and m.name = '카페 라떼');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('우유', 'danger', 'AI 추정'), ('대두', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '투썸플레이스' and b.is_franchise and m.name = '카페 라떼';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '투썸플레이스' and b.is_franchise and m.name = '카페 라떼');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('쌉싸름함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '투썸플레이스' and b.is_franchise and m.name = '카페 라떼';

-- 투썸플레이스 / 스트로베리 초콜릿 생크림 케이크
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '스트로베리 초콜릿 생크림 케이크', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '투썸플레이스' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '투썸플레이스' and b.is_franchise and m.name = '스트로베리 초콜릿 생크림 케이크');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('알류', 'danger', 'AI 추정'), ('우유', 'danger', 'AI 추정'), ('밀', 'danger', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('땅콩', 'caution', 'AI 추정'), ('호두', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '투썸플레이스' and b.is_franchise and m.name = '스트로베리 초콜릿 생크림 케이크';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '투썸플레이스' and b.is_franchise and m.name = '스트로베리 초콜릿 생크림 케이크');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('달콤함'), ('새콤함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '투썸플레이스' and b.is_franchise and m.name = '스트로베리 초콜릿 생크림 케이크';

-- 투썸플레이스 / 아이스박스 케이크
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '아이스박스 케이크', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '투썸플레이스' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '투썸플레이스' and b.is_franchise and m.name = '아이스박스 케이크');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('우유', 'danger', 'AI 추정'), ('밀', 'danger', 'AI 추정'), ('알류', 'caution', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('땅콩', 'caution', 'AI 추정'), ('호두', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '투썸플레이스' and b.is_franchise and m.name = '아이스박스 케이크';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '투썸플레이스' and b.is_franchise and m.name = '아이스박스 케이크');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('달콤함'), ('고소함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '투썸플레이스' and b.is_franchise and m.name = '아이스박스 케이크';

-- 투썸플레이스 / 떠먹는 티라미수
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '떠먹는 티라미수', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '투썸플레이스' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '투썸플레이스' and b.is_franchise and m.name = '떠먹는 티라미수');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('우유', 'danger', 'AI 추정'), ('알류', 'danger', 'AI 추정'), ('밀', 'danger', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('땅콩', 'caution', 'AI 추정'), ('호두', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '투썸플레이스' and b.is_franchise and m.name = '떠먹는 티라미수';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '투썸플레이스' and b.is_franchise and m.name = '떠먹는 티라미수');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('달콤함'), ('쌉싸름함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '투썸플레이스' and b.is_franchise and m.name = '떠먹는 티라미수';

-- ===== 이디야커피 (메뉴 4개) =====
do $$
begin
  if not exists (select 1 from brands b where b.name = '이디야커피' and b.is_franchise) then
    raise exception '브랜드 이디야커피 이(가) 없어요. seed_branches.sql 을 먼저 실행하세요.';
  end if;
end;
$$;
update brands b set
  allergen_source_url = null, allergen_data_date = null::date,
  shared_notice = '지점에 따라 판매하지 않는 제품이 있을 수 있음', research_status = 'done', researched_at = now(), research_error = null
where b.name = '이디야커피' and b.is_franchise;

-- 이디야커피 / 아메리카노
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '아메리카노', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '이디야커피' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '이디야커피' and b.is_franchise and m.name = '아메리카노');
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '이디야커피' and b.is_franchise and m.name = '아메리카노');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('쌉싸름함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '이디야커피' and b.is_franchise and m.name = '아메리카노';

-- 이디야커피 / 카페 라떼
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '카페 라떼', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '이디야커피' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '이디야커피' and b.is_franchise and m.name = '카페 라떼');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('우유', 'danger', 'AI 추정'), ('대두', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '이디야커피' and b.is_franchise and m.name = '카페 라떼';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '이디야커피' and b.is_franchise and m.name = '카페 라떼');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('쌉싸름함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '이디야커피' and b.is_franchise and m.name = '카페 라떼';

-- 이디야커피 / 토피 넛 라떼
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '토피 넛 라떼', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '이디야커피' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '이디야커피' and b.is_franchise and m.name = '토피 넛 라떼');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('우유', 'danger', 'AI 추정'), ('땅콩', 'caution', 'AI 추정'), ('호두', 'caution', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('알류', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '이디야커피' and b.is_franchise and m.name = '토피 넛 라떼';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '이디야커피' and b.is_franchise and m.name = '토피 넛 라떼');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('달콤함'), ('고소함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '이디야커피' and b.is_franchise and m.name = '토피 넛 라떼';

-- 이디야커피 / 복숭아 아이스티
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '복숭아 아이스티', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '이디야커피' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '이디야커피' and b.is_franchise and m.name = '복숭아 아이스티');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('복숭아', 'danger', 'AI 추정'), ('아황산류', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '이디야커피' and b.is_franchise and m.name = '복숭아 아이스티';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '이디야커피' and b.is_franchise and m.name = '복숭아 아이스티');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('달콤함'), ('새콤함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '이디야커피' and b.is_franchise and m.name = '복숭아 아이스티';

-- ===== 메가MGC커피 (메뉴 5개) =====
do $$
begin
  if not exists (select 1 from brands b where b.name = '메가MGC커피' and b.is_franchise) then
    raise exception '브랜드 메가MGC커피 이(가) 없어요. seed_branches.sql 을 먼저 실행하세요.';
  end if;
end;
$$;
update brands b set
  allergen_source_url = null, allergen_data_date = null::date,
  shared_notice = '지점에 따라 판매하지 않는 제품이 있을 수 있음', research_status = 'done', researched_at = now(), research_error = null
where b.name = '메가MGC커피' and b.is_franchise;

-- 메가MGC커피 / 아메리카노
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '아메리카노', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '메가MGC커피' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '메가MGC커피' and b.is_franchise and m.name = '아메리카노');
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '메가MGC커피' and b.is_franchise and m.name = '아메리카노');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('쌉싸름함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '메가MGC커피' and b.is_franchise and m.name = '아메리카노';

-- 메가MGC커피 / 카페 라떼
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '카페 라떼', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '메가MGC커피' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '메가MGC커피' and b.is_franchise and m.name = '카페 라떼');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('우유', 'danger', 'AI 추정'), ('대두', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '메가MGC커피' and b.is_franchise and m.name = '카페 라떼';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '메가MGC커피' and b.is_franchise and m.name = '카페 라떼');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('담백함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '메가MGC커피' and b.is_franchise and m.name = '카페 라떼';

-- 메가MGC커피 / 쿠키 프라페
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '쿠키 프라페', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '메가MGC커피' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '메가MGC커피' and b.is_franchise and m.name = '쿠키 프라페');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('우유', 'danger', 'AI 추정'), ('밀', 'danger', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('알류', 'caution', 'AI 추정'), ('땅콩', 'caution', 'AI 추정'), ('호두', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '메가MGC커피' and b.is_franchise and m.name = '쿠키 프라페';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '메가MGC커피' and b.is_franchise and m.name = '쿠키 프라페');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('달콤함'), ('고소함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '메가MGC커피' and b.is_franchise and m.name = '쿠키 프라페';

-- 메가MGC커피 / 딸기 라떼
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '딸기 라떼', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '메가MGC커피' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '메가MGC커피' and b.is_franchise and m.name = '딸기 라떼');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('우유', 'danger', 'AI 추정'), ('대두', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '메가MGC커피' and b.is_franchise and m.name = '딸기 라떼';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '메가MGC커피' and b.is_franchise and m.name = '딸기 라떼');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('달콤함'), ('새콤함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '메가MGC커피' and b.is_franchise and m.name = '딸기 라떼';

-- 메가MGC커피 / 유자차
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '유자차', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '메가MGC커피' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '메가MGC커피' and b.is_franchise and m.name = '유자차');
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '메가MGC커피' and b.is_franchise and m.name = '유자차');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('달콤함'), ('새콤함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '메가MGC커피' and b.is_franchise and m.name = '유자차';

-- ===== 컴포즈커피 (메뉴 4개) =====
do $$
begin
  if not exists (select 1 from brands b where b.name = '컴포즈커피' and b.is_franchise) then
    raise exception '브랜드 컴포즈커피 이(가) 없어요. seed_branches.sql 을 먼저 실행하세요.';
  end if;
end;
$$;
update brands b set
  allergen_source_url = null, allergen_data_date = null::date,
  shared_notice = '지점에 따라 판매하지 않는 제품이 있을 수 있음', research_status = 'done', researched_at = now(), research_error = null
where b.name = '컴포즈커피' and b.is_franchise;

-- 컴포즈커피 / 아메리카노
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '아메리카노', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '컴포즈커피' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '컴포즈커피' and b.is_franchise and m.name = '아메리카노');
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '컴포즈커피' and b.is_franchise and m.name = '아메리카노');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('쌉싸름함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '컴포즈커피' and b.is_franchise and m.name = '아메리카노';

-- 컴포즈커피 / 카페 라떼
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '카페 라떼', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '컴포즈커피' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '컴포즈커피' and b.is_franchise and m.name = '카페 라떼');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('우유', 'danger', 'AI 추정'), ('대두', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '컴포즈커피' and b.is_franchise and m.name = '카페 라떼';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '컴포즈커피' and b.is_franchise and m.name = '카페 라떼');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('쌉싸름함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '컴포즈커피' and b.is_franchise and m.name = '카페 라떼';

-- 컴포즈커피 / 바닐라 라떼
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '바닐라 라떼', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '컴포즈커피' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '컴포즈커피' and b.is_franchise and m.name = '바닐라 라떼');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('우유', 'danger', 'AI 추정'), ('대두', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '컴포즈커피' and b.is_franchise and m.name = '바닐라 라떼';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '컴포즈커피' and b.is_franchise and m.name = '바닐라 라떼');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('달콤함'), ('고소함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '컴포즈커피' and b.is_franchise and m.name = '바닐라 라떼';

-- 컴포즈커피 / 유자차
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '유자차', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '컴포즈커피' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '컴포즈커피' and b.is_franchise and m.name = '유자차');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('아황산류', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '컴포즈커피' and b.is_franchise and m.name = '유자차';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '컴포즈커피' and b.is_franchise and m.name = '유자차');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('달콤함'), ('새콤함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '컴포즈커피' and b.is_franchise and m.name = '유자차';

-- ===== 빽다방 (메뉴 4개) =====
do $$
begin
  if not exists (select 1 from brands b where b.name = '빽다방' and b.is_franchise) then
    raise exception '브랜드 빽다방 이(가) 없어요. seed_branches.sql 을 먼저 실행하세요.';
  end if;
end;
$$;
update brands b set
  allergen_source_url = null, allergen_data_date = null::date,
  shared_notice = '지점에 따라 판매하지 않는 제품이 있을 수 있음', research_status = 'done', researched_at = now(), research_error = null
where b.name = '빽다방' and b.is_franchise;

-- 빽다방 / 아메리카노
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '아메리카노', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '빽다방' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '빽다방' and b.is_franchise and m.name = '아메리카노');
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '빽다방' and b.is_franchise and m.name = '아메리카노');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('쌉싸름함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '빽다방' and b.is_franchise and m.name = '아메리카노';

-- 빽다방 / 원조커피
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '원조커피', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '빽다방' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '빽다방' and b.is_franchise and m.name = '원조커피');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('우유', 'danger', 'AI 추정'), ('대두', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '빽다방' and b.is_franchise and m.name = '원조커피';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '빽다방' and b.is_franchise and m.name = '원조커피');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('달콤함'), ('쌉싸름함'), ('고소함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '빽다방' and b.is_franchise and m.name = '원조커피';

-- 빽다방 / 바닐라 라떼
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '바닐라 라떼', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '빽다방' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '빽다방' and b.is_franchise and m.name = '바닐라 라떼');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('우유', 'danger', 'AI 추정'), ('대두', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '빽다방' and b.is_franchise and m.name = '바닐라 라떼';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '빽다방' and b.is_franchise and m.name = '바닐라 라떼');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('달콤함'), ('고소함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '빽다방' and b.is_franchise and m.name = '바닐라 라떼';

-- 빽다방 / 사라다빵
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '사라다빵', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '빽다방' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '빽다방' and b.is_franchise and m.name = '사라다빵');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('밀', 'danger', 'AI 추정'), ('알류', 'danger', 'AI 추정'), ('우유', 'caution', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('돼지고기', 'caution', 'AI 추정'), ('닭고기', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '빽다방' and b.is_franchise and m.name = '사라다빵';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '빽다방' and b.is_franchise and m.name = '사라다빵');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('달콤함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '빽다방' and b.is_franchise and m.name = '사라다빵';

-- ===== 파리바게뜨 (메뉴 6개) =====
do $$
begin
  if not exists (select 1 from brands b where b.name = '파리바게뜨' and b.is_franchise) then
    raise exception '브랜드 파리바게뜨 이(가) 없어요. seed_branches.sql 을 먼저 실행하세요.';
  end if;
end;
$$;
update brands b set
  allergen_source_url = null, allergen_data_date = null::date,
  shared_notice = '지점에 따라 판매하지 않는 제품이 있을 수 있음', research_status = 'done', researched_at = now(), research_error = null
where b.name = '파리바게뜨' and b.is_franchise;

-- 파리바게뜨 / 단팥빵
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '단팥빵', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '파리바게뜨' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '파리바게뜨' and b.is_franchise and m.name = '단팥빵');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('밀', 'danger', 'AI 추정'), ('알류', 'danger', 'AI 추정'), ('우유', 'danger', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('땅콩', 'caution', 'AI 추정'), ('호두', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '파리바게뜨' and b.is_franchise and m.name = '단팥빵';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '파리바게뜨' and b.is_franchise and m.name = '단팥빵');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('달콤함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '파리바게뜨' and b.is_franchise and m.name = '단팥빵';

-- 파리바게뜨 / 소보루빵
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '소보루빵', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '파리바게뜨' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '파리바게뜨' and b.is_franchise and m.name = '소보루빵');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('밀', 'danger', 'AI 추정'), ('알류', 'danger', 'AI 추정'), ('우유', 'danger', 'AI 추정'), ('땅콩', 'danger', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('호두', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '파리바게뜨' and b.is_franchise and m.name = '소보루빵';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '파리바게뜨' and b.is_franchise and m.name = '소보루빵');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('달콤함'), ('고소함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '파리바게뜨' and b.is_franchise and m.name = '소보루빵';

-- 파리바게뜨 / 크림빵
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '크림빵', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '파리바게뜨' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '파리바게뜨' and b.is_franchise and m.name = '크림빵');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('밀', 'danger', 'AI 추정'), ('우유', 'danger', 'AI 추정'), ('알류', 'danger', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('땅콩', 'caution', 'AI 추정'), ('호두', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '파리바게뜨' and b.is_franchise and m.name = '크림빵';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '파리바게뜨' and b.is_franchise and m.name = '크림빵');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('달콤함'), ('고소함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '파리바게뜨' and b.is_franchise and m.name = '크림빵';

-- 파리바게뜨 / 우유식빵
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '우유식빵', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '파리바게뜨' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '파리바게뜨' and b.is_franchise and m.name = '우유식빵');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('밀', 'danger', 'AI 추정'), ('우유', 'danger', 'AI 추정'), ('알류', 'caution', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('땅콩', 'caution', 'AI 추정'), ('호두', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '파리바게뜨' and b.is_franchise and m.name = '우유식빵';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '파리바게뜨' and b.is_franchise and m.name = '우유식빵');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('담백함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '파리바게뜨' and b.is_franchise and m.name = '우유식빵';

-- 파리바게뜨 / 생크림 케이크
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '생크림 케이크', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '파리바게뜨' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '파리바게뜨' and b.is_franchise and m.name = '생크림 케이크');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('밀', 'danger', 'AI 추정'), ('우유', 'danger', 'AI 추정'), ('알류', 'danger', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('복숭아', 'caution', 'AI 추정'), ('땅콩', 'caution', 'AI 추정'), ('호두', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '파리바게뜨' and b.is_franchise and m.name = '생크림 케이크';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '파리바게뜨' and b.is_franchise and m.name = '생크림 케이크');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('달콤함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '파리바게뜨' and b.is_franchise and m.name = '생크림 케이크';

-- 파리바게뜨 / 샌드위치
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '샌드위치', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '파리바게뜨' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '파리바게뜨' and b.is_franchise and m.name = '샌드위치');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('밀', 'danger', 'AI 추정'), ('알류', 'danger', 'AI 추정'), ('우유', 'caution', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('돼지고기', 'caution', 'AI 추정'), ('닭고기', 'caution', 'AI 추정'), ('쇠고기', 'caution', 'AI 추정'), ('토마토', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정'), ('새우', 'caution', 'AI 추정'), ('땅콩', 'caution', 'AI 추정'), ('호두', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '파리바게뜨' and b.is_franchise and m.name = '샌드위치';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '파리바게뜨' and b.is_franchise and m.name = '샌드위치');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('담백함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '파리바게뜨' and b.is_franchise and m.name = '샌드위치';

-- ===== 뚜레쥬르 (메뉴 5개) =====
do $$
begin
  if not exists (select 1 from brands b where b.name = '뚜레쥬르' and b.is_franchise) then
    raise exception '브랜드 뚜레쥬르 이(가) 없어요. seed_branches.sql 을 먼저 실행하세요.';
  end if;
end;
$$;
update brands b set
  allergen_source_url = null, allergen_data_date = null::date,
  shared_notice = '지점에 따라 판매하지 않는 제품이 있을 수 있음', research_status = 'done', researched_at = now(), research_error = null
where b.name = '뚜레쥬르' and b.is_franchise;

-- 뚜레쥬르 / 단팥빵
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '단팥빵', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '뚜레쥬르' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '뚜레쥬르' and b.is_franchise and m.name = '단팥빵');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('밀', 'danger', 'AI 추정'), ('알류', 'danger', 'AI 추정'), ('우유', 'danger', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('땅콩', 'caution', 'AI 추정'), ('호두', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '뚜레쥬르' and b.is_franchise and m.name = '단팥빵';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '뚜레쥬르' and b.is_franchise and m.name = '단팥빵');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('달콤함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '뚜레쥬르' and b.is_franchise and m.name = '단팥빵';

-- 뚜레쥬르 / 소보로빵
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '소보로빵', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '뚜레쥬르' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '뚜레쥬르' and b.is_franchise and m.name = '소보로빵');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('밀', 'danger', 'AI 추정'), ('알류', 'danger', 'AI 추정'), ('우유', 'danger', 'AI 추정'), ('땅콩', 'caution', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('호두', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '뚜레쥬르' and b.is_franchise and m.name = '소보로빵';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '뚜레쥬르' and b.is_franchise and m.name = '소보로빵');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('달콤함'), ('고소함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '뚜레쥬르' and b.is_franchise and m.name = '소보로빵';

-- 뚜레쥬르 / 우유식빵
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '우유식빵', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '뚜레쥬르' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '뚜레쥬르' and b.is_franchise and m.name = '우유식빵');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('밀', 'danger', 'AI 추정'), ('우유', 'danger', 'AI 추정'), ('알류', 'caution', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('땅콩', 'caution', 'AI 추정'), ('호두', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '뚜레쥬르' and b.is_franchise and m.name = '우유식빵';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '뚜레쥬르' and b.is_franchise and m.name = '우유식빵');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('담백함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '뚜레쥬르' and b.is_franchise and m.name = '우유식빵';

-- 뚜레쥬르 / 크루아상
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '크루아상', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '뚜레쥬르' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '뚜레쥬르' and b.is_franchise and m.name = '크루아상');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('밀', 'danger', 'AI 추정'), ('우유', 'danger', 'AI 추정'), ('알류', 'danger', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('땅콩', 'caution', 'AI 추정'), ('호두', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '뚜레쥬르' and b.is_franchise and m.name = '크루아상';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '뚜레쥬르' and b.is_franchise and m.name = '크루아상');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('느끼함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '뚜레쥬르' and b.is_franchise and m.name = '크루아상';

-- 뚜레쥬르 / 생크림 케이크
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '생크림 케이크', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '뚜레쥬르' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '뚜레쥬르' and b.is_franchise and m.name = '생크림 케이크');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('밀', 'danger', 'AI 추정'), ('알류', 'danger', 'AI 추정'), ('우유', 'danger', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('복숭아', 'caution', 'AI 추정'), ('호두', 'caution', 'AI 추정'), ('땅콩', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '뚜레쥬르' and b.is_franchise and m.name = '생크림 케이크';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '뚜레쥬르' and b.is_franchise and m.name = '생크림 케이크');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('달콤함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '뚜레쥬르' and b.is_franchise and m.name = '생크림 케이크';

-- ===== 배스킨라빈스 (메뉴 6개) =====
do $$
begin
  if not exists (select 1 from brands b where b.name = '배스킨라빈스' and b.is_franchise) then
    raise exception '브랜드 배스킨라빈스 이(가) 없어요. seed_branches.sql 을 먼저 실행하세요.';
  end if;
end;
$$;
update brands b set
  allergen_source_url = null, allergen_data_date = null::date,
  shared_notice = '지점에 따라 판매하지 않는 제품이 있을 수 있음', research_status = 'done', researched_at = now(), research_error = null
where b.name = '배스킨라빈스' and b.is_franchise;

-- 배스킨라빈스 / 엄마는 외계인
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '엄마는 외계인', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '배스킨라빈스' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '배스킨라빈스' and b.is_franchise and m.name = '엄마는 외계인');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('우유', 'danger', 'AI 추정'), ('밀', 'danger', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('알류', 'caution', 'AI 추정'), ('땅콩', 'caution', 'AI 추정'), ('호두', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '배스킨라빈스' and b.is_franchise and m.name = '엄마는 외계인';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '배스킨라빈스' and b.is_franchise and m.name = '엄마는 외계인');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('달콤함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '배스킨라빈스' and b.is_franchise and m.name = '엄마는 외계인';

-- 배스킨라빈스 / 아몬드 봉봉
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '아몬드 봉봉', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '배스킨라빈스' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '배스킨라빈스' and b.is_franchise and m.name = '아몬드 봉봉');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('우유', 'danger', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('알류', 'caution', 'AI 추정'), ('땅콩', 'caution', 'AI 추정'), ('호두', 'caution', 'AI 추정'), ('밀', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '배스킨라빈스' and b.is_franchise and m.name = '아몬드 봉봉';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '배스킨라빈스' and b.is_franchise and m.name = '아몬드 봉봉');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('달콤함'), ('고소함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '배스킨라빈스' and b.is_franchise and m.name = '아몬드 봉봉';

-- 배스킨라빈스 / 민트 초콜릿 칩
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '민트 초콜릿 칩', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '배스킨라빈스' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '배스킨라빈스' and b.is_franchise and m.name = '민트 초콜릿 칩');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('우유', 'danger', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('알류', 'caution', 'AI 추정'), ('땅콩', 'caution', 'AI 추정'), ('호두', 'caution', 'AI 추정'), ('밀', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '배스킨라빈스' and b.is_franchise and m.name = '민트 초콜릿 칩';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '배스킨라빈스' and b.is_franchise and m.name = '민트 초콜릿 칩');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('달콤함'), ('쌉싸름함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '배스킨라빈스' and b.is_franchise and m.name = '민트 초콜릿 칩';

-- 배스킨라빈스 / 슈팅스타
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '슈팅스타', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '배스킨라빈스' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '배스킨라빈스' and b.is_franchise and m.name = '슈팅스타');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('우유', 'danger', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('알류', 'caution', 'AI 추정'), ('밀', 'caution', 'AI 추정'), ('땅콩', 'caution', 'AI 추정'), ('호두', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '배스킨라빈스' and b.is_franchise and m.name = '슈팅스타';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '배스킨라빈스' and b.is_franchise and m.name = '슈팅스타');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('달콤함'), ('새콤함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '배스킨라빈스' and b.is_franchise and m.name = '슈팅스타';

-- 배스킨라빈스 / 체리쥬빌레
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '체리쥬빌레', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '배스킨라빈스' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '배스킨라빈스' and b.is_franchise and m.name = '체리쥬빌레');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('우유', 'danger', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('알류', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정'), ('땅콩', 'caution', 'AI 추정'), ('호두', 'caution', 'AI 추정'), ('밀', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '배스킨라빈스' and b.is_franchise and m.name = '체리쥬빌레';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '배스킨라빈스' and b.is_franchise and m.name = '체리쥬빌레');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('달콤함'), ('새콤함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '배스킨라빈스' and b.is_franchise and m.name = '체리쥬빌레';

-- 배스킨라빈스 / 뉴욕 치즈케이크
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '뉴욕 치즈케이크', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '배스킨라빈스' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '배스킨라빈스' and b.is_franchise and m.name = '뉴욕 치즈케이크');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('우유', 'danger', 'AI 추정'), ('밀', 'danger', 'AI 추정'), ('알류', 'danger', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('땅콩', 'caution', 'AI 추정'), ('호두', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '배스킨라빈스' and b.is_franchise and m.name = '뉴욕 치즈케이크';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '배스킨라빈스' and b.is_franchise and m.name = '뉴욕 치즈케이크');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('달콤함'), ('느끼함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '배스킨라빈스' and b.is_franchise and m.name = '뉴욕 치즈케이크';

-- ===== 던킨 (메뉴 5개) =====
do $$
begin
  if not exists (select 1 from brands b where b.name = '던킨' and b.is_franchise) then
    raise exception '브랜드 던킨 이(가) 없어요. seed_branches.sql 을 먼저 실행하세요.';
  end if;
end;
$$;
update brands b set
  allergen_source_url = null, allergen_data_date = null::date,
  shared_notice = '지점에 따라 판매하지 않는 제품이 있을 수 있음', research_status = 'done', researched_at = now(), research_error = null
where b.name = '던킨' and b.is_franchise;

-- 던킨 / 글레이즈드 도넛
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '글레이즈드 도넛', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '던킨' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '던킨' and b.is_franchise and m.name = '글레이즈드 도넛');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('밀', 'danger', 'AI 추정'), ('우유', 'danger', 'AI 추정'), ('알류', 'danger', 'AI 추정'), ('대두', 'danger', 'AI 추정'), ('땅콩', 'caution', 'AI 추정'), ('호두', 'caution', 'AI 추정'), ('메밀', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '던킨' and b.is_franchise and m.name = '글레이즈드 도넛';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '던킨' and b.is_franchise and m.name = '글레이즈드 도넛');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('달콤함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '던킨' and b.is_franchise and m.name = '글레이즈드 도넛';

-- 던킨 / 보스톤 크림 도넛
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '보스톤 크림 도넛', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '던킨' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '던킨' and b.is_franchise and m.name = '보스톤 크림 도넛');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('밀', 'danger', 'AI 추정'), ('우유', 'danger', 'AI 추정'), ('알류', 'danger', 'AI 추정'), ('대두', 'danger', 'AI 추정'), ('땅콩', 'caution', 'AI 추정'), ('호두', 'caution', 'AI 추정'), ('메밀', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '던킨' and b.is_franchise and m.name = '보스톤 크림 도넛';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '던킨' and b.is_franchise and m.name = '보스톤 크림 도넛');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('달콤함'), ('느끼함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '던킨' and b.is_franchise and m.name = '보스톤 크림 도넛';

-- 던킨 / 스트로베리 필드 도넛
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '스트로베리 필드 도넛', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '던킨' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '던킨' and b.is_franchise and m.name = '스트로베리 필드 도넛');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('밀', 'danger', 'AI 추정'), ('우유', 'danger', 'AI 추정'), ('알류', 'danger', 'AI 추정'), ('대두', 'danger', 'AI 추정'), ('땅콩', 'caution', 'AI 추정'), ('호두', 'caution', 'AI 추정'), ('메밀', 'caution', 'AI 추정'), ('복숭아', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '던킨' and b.is_franchise and m.name = '스트로베리 필드 도넛';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '던킨' and b.is_franchise and m.name = '스트로베리 필드 도넛');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('달콤함'), ('새콤함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '던킨' and b.is_franchise and m.name = '스트로베리 필드 도넛';

-- 던킨 / 먼치킨
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '먼치킨', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '던킨' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '던킨' and b.is_franchise and m.name = '먼치킨');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('밀', 'danger', 'AI 추정'), ('우유', 'danger', 'AI 추정'), ('알류', 'danger', 'AI 추정'), ('대두', 'danger', 'AI 추정'), ('땅콩', 'caution', 'AI 추정'), ('호두', 'caution', 'AI 추정'), ('메밀', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '던킨' and b.is_franchise and m.name = '먼치킨';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '던킨' and b.is_franchise and m.name = '먼치킨');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('달콤함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '던킨' and b.is_franchise and m.name = '먼치킨';

-- 던킨 / 아메리카노
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '아메리카노', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '던킨' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '던킨' and b.is_franchise and m.name = '아메리카노');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('우유', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '던킨' and b.is_franchise and m.name = '아메리카노';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '던킨' and b.is_franchise and m.name = '아메리카노');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('담백함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '던킨' and b.is_franchise and m.name = '아메리카노';

-- ===== 설빙 (메뉴 4개) =====
do $$
begin
  if not exists (select 1 from brands b where b.name = '설빙' and b.is_franchise) then
    raise exception '브랜드 설빙 이(가) 없어요. seed_branches.sql 을 먼저 실행하세요.';
  end if;
end;
$$;
update brands b set
  allergen_source_url = null, allergen_data_date = null::date,
  shared_notice = '지점에 따라 판매하지 않는 제품이 있을 수 있음', research_status = 'done', researched_at = now(), research_error = null
where b.name = '설빙' and b.is_franchise;

-- 설빙 / 인절미 설빙
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '인절미 설빙', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '설빙' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '설빙' and b.is_franchise and m.name = '인절미 설빙');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('우유', 'danger', 'AI 추정'), ('대두', 'danger', 'AI 추정'), ('땅콩', 'caution', 'AI 추정'), ('호두', 'caution', 'AI 추정'), ('밀', 'caution', 'AI 추정'), ('알류', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '설빙' and b.is_franchise and m.name = '인절미 설빙';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '설빙' and b.is_franchise and m.name = '인절미 설빙');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('달콤함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '설빙' and b.is_franchise and m.name = '인절미 설빙';

-- 설빙 / 애플망고치즈 설빙
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '애플망고치즈 설빙', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '설빙' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '설빙' and b.is_franchise and m.name = '애플망고치즈 설빙');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('우유', 'danger', 'AI 추정'), ('알류', 'caution', 'AI 추정'), ('밀', 'caution', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('복숭아', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '설빙' and b.is_franchise and m.name = '애플망고치즈 설빙';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '설빙' and b.is_franchise and m.name = '애플망고치즈 설빙');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('달콤함'), ('새콤함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '설빙' and b.is_franchise and m.name = '애플망고치즈 설빙';

-- 설빙 / 딸기 설빙
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '딸기 설빙', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '설빙' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '설빙' and b.is_franchise and m.name = '딸기 설빙');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('우유', 'danger', 'AI 추정'), ('알류', 'caution', 'AI 추정'), ('밀', 'caution', 'AI 추정'), ('대두', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '설빙' and b.is_franchise and m.name = '딸기 설빙';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '설빙' and b.is_franchise and m.name = '딸기 설빙');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('달콤함'), ('새콤함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '설빙' and b.is_franchise and m.name = '딸기 설빙';

-- 설빙 / 인절미 토스트
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '인절미 토스트', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '설빙' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '설빙' and b.is_franchise and m.name = '인절미 토스트');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('밀', 'danger', 'AI 추정'), ('대두', 'danger', 'AI 추정'), ('우유', 'danger', 'AI 추정'), ('알류', 'caution', 'AI 추정'), ('땅콩', 'caution', 'AI 추정'), ('호두', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '설빙' and b.is_franchise and m.name = '인절미 토스트';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '설빙' and b.is_franchise and m.name = '인절미 토스트');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('고소함'), ('달콤함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '설빙' and b.is_franchise and m.name = '인절미 토스트';

-- ===== 공차 (메뉴 4개) =====
do $$
begin
  if not exists (select 1 from brands b where b.name = '공차' and b.is_franchise) then
    raise exception '브랜드 공차 이(가) 없어요. seed_branches.sql 을 먼저 실행하세요.';
  end if;
end;
$$;
update brands b set
  allergen_source_url = null, allergen_data_date = null::date,
  shared_notice = '지점에 따라 판매하지 않는 제품이 있을 수 있음', research_status = 'done', researched_at = now(), research_error = null
where b.name = '공차' and b.is_franchise;

-- 공차 / 블랙 밀크티
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '블랙 밀크티', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '공차' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '공차' and b.is_franchise and m.name = '블랙 밀크티');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('우유', 'danger', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('알류', 'caution', 'AI 추정'), ('밀', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '공차' and b.is_franchise and m.name = '블랙 밀크티';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '공차' and b.is_franchise and m.name = '블랙 밀크티');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('달콤함'), ('고소함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '공차' and b.is_franchise and m.name = '블랙 밀크티';

-- 공차 / 타로 밀크티
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '타로 밀크티', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '공차' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '공차' and b.is_franchise and m.name = '타로 밀크티');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('우유', 'danger', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('알류', 'caution', 'AI 추정'), ('밀', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '공차' and b.is_franchise and m.name = '타로 밀크티';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '공차' and b.is_franchise and m.name = '타로 밀크티');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('달콤함'), ('고소함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '공차' and b.is_franchise and m.name = '타로 밀크티';

-- 공차 / 망고 스무디
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '망고 스무디', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '공차' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '공차' and b.is_franchise and m.name = '망고 스무디');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('우유', 'caution', 'AI 추정'), ('대두', 'caution', 'AI 추정'), ('복숭아', 'caution', 'AI 추정'), ('아황산류', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '공차' and b.is_franchise and m.name = '망고 스무디';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '공차' and b.is_franchise and m.name = '망고 스무디');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('달콤함'), ('새콤함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '공차' and b.is_franchise and m.name = '망고 스무디';

-- 공차 / 자몽 그린티 에이드
insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)
select b.id, '자몽 그린티 에이드', null, 'estimated'::allergen_status, null, '2026-11-24T16:32:20.833Z'::timestamptz, 'AI가 메뉴 이름으로 추정한 정보예요. 가게에 꼭 확인하세요', null, null
from brands b where b.name = '공차' and b.is_franchise
on conflict (brand_id, name) do update set
  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,
  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,
  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;
delete from menu_allergens where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '공차' and b.is_franchise and m.name = '자몽 그린티 에이드');
insert into menu_allergens (menu_id, allergen_id, level, original_text)
select m.id, a.id, v.level::allergen_level, v.original_text
from menus m join brands b on b.id = m.brand_id
cross join (values ('아황산류', 'caution', 'AI 추정')) as v(name, level, original_text)
join allergens a on a.name = v.name
where b.name = '공차' and b.is_franchise and m.name = '자몽 그린티 에이드';
delete from menu_taste_tags where menu_id in (select m.id from menus m join brands b on b.id = m.brand_id where b.name = '공차' and b.is_franchise and m.name = '자몽 그린티 에이드');
insert into menu_taste_tags (menu_id, taste_tag_id)
select m.id, t.id
from menus m join brands b on b.id = m.brand_id
cross join (values ('새콤함'), ('달콤함'), ('쌉싸름함')) as v(name)
join taste_tags t on t.name = v.name
where b.name = '공차' and b.is_franchise and m.name = '자몽 그린티 에이드';

commit;
