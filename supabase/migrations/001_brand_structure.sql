-- =====================================================================
-- 001_brand_structure.sql — 가게·메뉴 1:N 구조 → 브랜드 구조 (파괴적 마이그레이션, 기존 DB 에 한 번만 적용)
--
-- 실행: Supabase SQL Editor 에서 이 파일을 통째로 실행한다. 전체가 하나의 트랜잭션이라 실패하면 모두 되돌아간다.
-- 순서: 001_brand_structure.sql → policies.sql → functions.sql → seed_reference.sql → (SQL 실행 후) npm run gen:types
-- 새로 설치하는 DB 에는 쓰지 않는다 (schema.sql 이 이 마이그레이션 적용 후의 최종 상태다).
--
-- 지우는 데이터 (가상 시드): saved_menus, saved_restaurants, review_taste_tags, reviews,
--                           menu_allergens, menu_taste_tags, menus, restaurants  (restart identity)
-- 건드리지 않는 데이터: auth.*, profiles, user_taste_preferences, user_allergens,
--                      taste_tags, food_categories, allergens (allergens 는 아래에서 19종 표준으로 개편, 기존 id 유지)
-- =====================================================================

begin;

-- 안전장치: 이미 적용된 DB 에서 다시 실행하면 새 데이터를 지우게 되므로 막는다
do $$
begin
  if to_regclass('public.brands') is not null then
    raise exception '이미 브랜드 구조가 적용된 DB 예요. 이 마이그레이션은 한 번만 실행할 수 있어요.';
  end if;
end;
$$;

-- ---------------------------------------------------------------------
-- 1. 가상 데이터 폐기
-- ---------------------------------------------------------------------
truncate table saved_menus, saved_restaurants, review_taste_tags, reviews,
               menu_allergens, menu_taste_tags, menus, restaurants
  restart identity cascade;

-- ---------------------------------------------------------------------
-- 2. 뷰 삭제 (컬럼을 지우기 전에) — 아래에서 다시 만든다
-- ---------------------------------------------------------------------
drop view if exists restaurant_taste_tags;
drop view if exists restaurant_stats;
drop view if exists menu_stats;

-- ---------------------------------------------------------------------
-- 3. 타입·브랜드 테이블
-- ---------------------------------------------------------------------
create type allergen_status as enum ('verified', 'official_extract', 'estimated', 'unknown');

create table brands (
  id                   bigint generated always as identity primary key,
  name                 text not null,
  is_franchise         boolean not null default false,
  category_id          smallint references food_categories (id),
  image_url            text,
  official_domains     text[] not null default '{}',
  allergen_source_url  text,
  allergen_data_date   date,
  shared_notice        text,
  research_status      text not null default 'pending'
                       check (research_status in ('pending', 'running', 'done', 'failed')),
  researched_at        timestamptz,
  research_error       text,
  created_at           timestamptz not null default now()
);
create unique index brands_franchise_name_uidx on brands (name) where is_franchise;

-- ---------------------------------------------------------------------
-- 4. restaurants(지점): brand_id·외부 번호·시도/시군구 추가, category_id 제거 (테이블은 위에서 비웠다)
-- ---------------------------------------------------------------------
alter table restaurants add column brand_id bigint not null references brands (id);
alter table restaurants add column external_id text unique;
alter table restaurants add column sido text;
alter table restaurants add column sigungu text;
drop index if exists restaurants_region_category_idx;
alter table restaurants drop column category_id;
create index restaurants_region_idx on restaurants (region);
create index restaurants_brand_idx on restaurants (brand_id);

-- ---------------------------------------------------------------------
-- 5. menus: restaurant_id → brand_id, 알레르기 출처 컬럼 추가
-- ---------------------------------------------------------------------
alter table menus drop column restaurant_id;   -- unique (restaurant_id, name) 도 함께 사라진다
alter table menus add column brand_id bigint not null references brands (id) on delete cascade;
alter table menus add constraint menus_brand_name_key unique (brand_id, name);
alter table menus add column allergen_status allergen_status not null default 'unknown';
alter table menus add column allergen_source_url text;
alter table menus add column allergen_checked_at timestamptz;
alter table menus add column allergen_note text;
alter table menus add column menu_source_url text;
alter table menus add column menu_source_name text;

alter table menu_allergens add column original_text text;

-- ---------------------------------------------------------------------
-- 6. allergens: 식약처 19종 표준으로 교체 (기존 id 유지 → user_allergens 보존)
--    기존 '계란' → '알류'(표기 계란), '콩' → '대두'(표기 콩). 나머지 기존 이름은 그대로, 부족한 항목만 추가한다.
-- ---------------------------------------------------------------------
alter table allergens add column display_name text;
alter table allergens add column aliases text[] not null default '{}';

update allergens set name = '알류', display_name = '계란' where name = '계란';
update allergens set name = '대두', display_name = '콩'   where name = '콩';

insert into allergens (name)
select s.name
from unnest(array['알류', '우유', '메밀', '땅콩', '대두', '밀', '고등어', '게', '새우', '돼지고기', '복숭아',
                  '토마토', '아황산류', '호두', '닭고기', '쇠고기', '오징어', '조개류', '잣']) as s(name)
on conflict (name) do nothing;

update allergens set display_name = name where display_name is null;
alter table allergens alter column display_name set not null;

-- 별칭 (scripts/research/standard-allergens.json 기준)
update allergens a
set aliases = v.aliases
from (values
  ('알류',     array['난류', '달걀', '계란', '계란류', '알', '달걀류']),
  ('우유',     array['우유류', '밀크']),
  ('대두',     array['콩', '콩류', '대두류']),
  ('밀',       array['소맥', '밀가루']),
  ('땅콩',     array['낙화생', '땅콩류']),
  ('새우',     array['새우류', '대하']),
  ('게',       array['게류', '꽃게']),
  ('조개류',   array['굴', '전복', '홍합', '가리비', '조개', '바지락']),
  ('돼지고기', array['돼지', '돈육']),
  ('닭고기',   array['닭', '계육']),
  ('쇠고기',   array['소고기', '쇠고기류', '소고기류', '우육']),
  ('오징어',   array['오징어류']),
  ('아황산류', array['아황산염', '이산화황', '아황산나트륨']),
  ('호두',     array['호두류']),
  ('잣',       array['잣류'])
) as v(name, aliases)
where a.name = v.name;

-- ---------------------------------------------------------------------
-- 7. 뷰 재생성 (security_invoker)
-- ---------------------------------------------------------------------
create view menu_stats with (security_invoker = true) as
select menu_id,
       round(avg(rating)::numeric, 1) as avg_rating,
       count(*)                       as review_count
from reviews
group by menu_id;

create view brand_stats with (security_invoker = true) as
select m.brand_id,
       round(avg(rv.rating)::numeric, 1) as avg_rating,
       count(rv.id)                      as review_count
from menus m
join reviews rv on rv.menu_id = m.id
group by m.brand_id;

create view restaurant_stats with (security_invoker = true) as
select r.id                              as restaurant_id,
       round(avg(rv.rating)::numeric, 1) as avg_rating,
       count(rv.id)                      as review_count
from restaurants r
join menus m on m.brand_id = r.brand_id
join reviews rv on rv.menu_id = m.id
group by r.id;

create view restaurant_taste_tags with (security_invoker = true) as
select distinct r.id as restaurant_id, mt.taste_tag_id
from restaurants r
join menus m on m.brand_id = r.brand_id
join menu_taste_tags mt on mt.menu_id = m.id;

-- ---------------------------------------------------------------------
-- 8. RLS·권한 (뷰를 다시 만들면 권한이 사라지므로 여기서도 부여한다. policies.sql 이 같은 내용을 멱등으로 다시 적용한다)
-- ---------------------------------------------------------------------
alter table brands enable row level security;

drop policy if exists "brands_select" on brands;
create policy "brands_select" on brands
  for select to authenticated using (true);

revoke all on brands, brand_stats from anon;
grant select on brands, brand_stats, menu_stats, restaurant_stats, restaurant_taste_tags to authenticated;

commit;
