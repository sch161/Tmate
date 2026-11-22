-- =====================================================================
-- T:MATE schema.sql
-- Supabase SQL Editor 에서 위에서부터 한 번에 실행한다.
-- 구조를 바꾸면 docs/erd.md 도 같이 수정하고 `npm run gen:types` 로 타입을 갱신한다.
--
-- 로그인 방식: 아이디 -> 가짜 이메일(아이디@tmate-app.com) 변환
--   * 프론트에서 signUp / signInWithPassword 시 email = `${username}@tmate-app.com`
--   * 아이디 규칙: 영문 소문자·숫자·밑줄 4~20자 (이메일 앞부분이므로 한글 불가)
--   * Supabase 대시보드 Authentication > Sign In / Providers > Email 에서
--     "Confirm email" 을 꺼야 가입 직후 로그인된다.
--   * 도메인이 거부되면 이 파일의 트리거는 그대로 두고 프론트 상수만 바꾸면 된다.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. 타입
-- ---------------------------------------------------------------------
create type allergen_level as enum ('danger', 'caution');  -- 위험 / 주의

-- ---------------------------------------------------------------------
-- 2. 기준 데이터 (seed.sql 에서 채운다)
-- ---------------------------------------------------------------------
create table food_categories (
  id    smallint generated always as identity primary key,
  name  text not null unique                -- 한식, 중식, 일식, 양식
);

create table taste_tags (
  id    smallint generated always as identity primary key,
  code  text not null unique,               -- spicy, sweet, salty ... (코드용)
  name  text not null unique                -- 매콤함, 달콤함, 짭조름함 ... (화면 표시용)
);

create table allergens (
  id    smallint generated always as identity primary key,
  name  text not null unique                -- 계란, 우유, 콩 ...
);

-- ---------------------------------------------------------------------
-- 3. 사용자
-- ---------------------------------------------------------------------
create table profiles (
  id                uuid primary key references auth.users (id) on delete cascade,
  username          text not null unique
                    check (username ~ '^[a-z0-9_]{4,20}$'),
  nickname          text not null,                 -- 기본값은 아이디, 프로필 수정에서 변경
  region            text,                          -- 예: '서울시 관악구' (restaurants.region 과 같은 형식)
  avatar_url        text,
  onboarding_done   boolean not null default false,
  created_at        timestamptz not null default now()
);

-- 온보딩: 좋아하는 맛 최대 3개 + 비율(합계 100). 개수·합계 검증은 앱/RPC 에서 한다.
create table user_taste_preferences (
  user_id       uuid     not null references profiles (id) on delete cascade,
  taste_tag_id  smallint not null references taste_tags (id),
  ratio         smallint not null check (ratio between 1 and 100),
  primary key (user_id, taste_tag_id)
);

create table user_allergens (
  user_id      uuid     not null references profiles (id) on delete cascade,
  allergen_id  smallint not null references allergens (id),
  primary key (user_id, allergen_id)
);

-- ---------------------------------------------------------------------
-- 4. 가게 / 메뉴
-- ---------------------------------------------------------------------
create table restaurants (
  id           bigint generated always as identity primary key,
  name         text not null,
  address      text not null,
  region       text not null,                      -- 구 단위 필터용. 예: '서울시 구로구'
  phone        text,
  image_url    text,
  category_id  smallint references food_categories (id),
  created_at   timestamptz not null default now()
);
create index restaurants_region_category_idx on restaurants (region, category_id);

create table menus (
  id             bigint generated always as identity primary key,
  restaurant_id  bigint not null references restaurants (id) on delete cascade,
  name           text not null,
  description    text,
  image_url      text,
  unique (restaurant_id, name)
);
create index menus_name_idx on menus (name);

-- 메뉴 자체의 맛 태그 (신규 사용자 추천·일치도 계산에 사용)
create table menu_taste_tags (
  menu_id       bigint   not null references menus (id) on delete cascade,
  taste_tag_id  smallint not null references taste_tags (id),
  primary key (menu_id, taste_tag_id)
);

-- danger = 알레르기 재료 포함(위험), caution = 혼입 가능성(주의)
create table menu_allergens (
  menu_id      bigint   not null references menus (id) on delete cascade,
  allergen_id  smallint not null references allergens (id),
  level        allergen_level not null default 'danger',
  primary key (menu_id, allergen_id)
);

-- ---------------------------------------------------------------------
-- 5. 평가 (유사도 계산의 원천 데이터)
-- ---------------------------------------------------------------------
create table reviews (
  id          bigint generated always as identity primary key,
  user_id     uuid     not null references profiles (id) on delete cascade,
  menu_id     bigint   not null references menus (id) on delete cascade,
  rating      smallint not null check (rating between 1 and 5),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (user_id, menu_id)
);
create index reviews_menu_idx on reviews (menu_id);

create table review_taste_tags (
  review_id     bigint   not null references reviews (id) on delete cascade,
  taste_tag_id  smallint not null references taste_tags (id),
  primary key (review_id, taste_tag_id)
);

-- ---------------------------------------------------------------------
-- 6. 저장(북마크)
-- ---------------------------------------------------------------------
create table saved_restaurants (
  user_id        uuid   not null references profiles (id) on delete cascade,
  restaurant_id  bigint not null references restaurants (id) on delete cascade,
  created_at     timestamptz not null default now(),
  primary key (user_id, restaurant_id)
);

create table saved_menus (
  user_id     uuid   not null references profiles (id) on delete cascade,
  menu_id     bigint not null references menus (id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (user_id, menu_id)
);

-- ---------------------------------------------------------------------
-- 7. 집계 뷰 (가게·메뉴 평점, 가게 입맛 태그)
--    security_invoker: 조회하는 사용자의 RLS 를 그대로 적용한다.
-- ---------------------------------------------------------------------
create view menu_stats with (security_invoker = true) as
select menu_id,
       round(avg(rating)::numeric, 1) as avg_rating,
       count(*)                       as review_count
from reviews
group by menu_id;

create view restaurant_stats with (security_invoker = true) as
select m.restaurant_id,
       round(avg(r.rating)::numeric, 1) as avg_rating,
       count(r.id)                      as review_count
from menus m
join reviews r on r.menu_id = m.id
group by m.restaurant_id;

create view restaurant_taste_tags with (security_invoker = true) as
select distinct m.restaurant_id, mt.taste_tag_id
from menus m
join menu_taste_tags mt on mt.menu_id = m.id;

-- ---------------------------------------------------------------------
-- 8. 가입 시 profiles 자동 생성
--    이메일 앞부분(아이디)을 username, nickname 기본값으로 사용한다.
-- ---------------------------------------------------------------------
create function handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, username, nickname)
  values (
    new.id,
    split_part(new.email, '@', 1),
    split_part(new.email, '@', 1)
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- ---------------------------------------------------------------------
-- 9. RLS 활성화
--    정책(policies.sql)을 만들기 전에는 모든 테이블이 anon/로그인 사용자에게
--    막혀 있다. 키가 공개되어도 데이터가 노출되지 않도록 먼저 켜 둔다.
-- ---------------------------------------------------------------------
alter table food_categories         enable row level security;
alter table taste_tags              enable row level security;
alter table allergens               enable row level security;
alter table profiles                enable row level security;
alter table user_taste_preferences  enable row level security;
alter table user_allergens          enable row level security;
alter table restaurants             enable row level security;
alter table menus                   enable row level security;
alter table menu_taste_tags         enable row level security;
alter table menu_allergens          enable row level security;
alter table reviews                 enable row level security;
alter table review_taste_tags       enable row level security;
alter table saved_restaurants       enable row level security;
alter table saved_menus             enable row level security;