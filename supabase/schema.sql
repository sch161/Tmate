-- =====================================================================
-- T:MATE schema.sql  (새로 설치할 때 쓰는 최종 상태)
-- 실행 순서(새 프로젝트): schema.sql → policies.sql → functions.sql → seed_reference.sql (→ 개발용 seed_demo_users.sql)
-- 이미 옛 구조(가게·메뉴 1:N)가 있는 DB 는 이 파일이 아니라 supabase/migrations/001_brand_structure.sql 을 한 번만 적용한다.
-- 구조를 바꾸면 docs/erd.md 도 같이 수정하고 `npm run gen:types` 로 타입을 갱신한다.
--
-- 구조 요약
--   brands(브랜드) 1 ── N restaurants(지점, 공공데이터)
--   brands(브랜드) 1 ── N menus(브랜드 공통 메뉴·알레르기). 개인 식당은 가게 1개 = 브랜드 1개(1:1)
--   평가(reviews)는 메뉴(=브랜드 메뉴)에 붙으므로 같은 브랜드의 모든 지점이 평점·메뉴·알레르기를 공유한다.
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
create type allergen_level as enum ('danger', 'caution');  -- 위험(함유) / 주의(혼입 가능)

-- 알레르기 정보의 신뢰 단계
--   verified          공식 페이지 본문을 직접 확인
--   official_extract  공식 도메인 검색 결과 발췌에서 읽음 (본문 재확인 못 함)
--   estimated         일반 조리법 기준 추정
--   unknown           정보 없음
create type allergen_status as enum ('verified', 'official_extract', 'estimated', 'unknown');

-- ---------------------------------------------------------------------
-- 2. 기준 데이터 (seed_reference.sql 에서 채운다)
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

-- 식약처 알레르기 표시 대상 19종 표준. name 은 표준 이름, display_name 은 화면 표기, aliases 는 조사 결과 매핑용 별칭
create table allergens (
  id            smallint generated always as identity primary key,
  name          text not null unique,       -- 알류, 우유, 메밀, ... (표준 이름)
  display_name  text not null,              -- 화면 표기 (알류 → '계란', 대두 → '콩', 나머지는 name 과 같음)
  aliases       text[] not null default '{}'  -- 난류, 달걀, 계란 ...
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
-- 4. 브랜드 / 가게(지점) / 메뉴
-- ---------------------------------------------------------------------
-- 브랜드: 메뉴·알레르기를 한 번만 조사해 모든 지점이 공유한다. 개인 식당은 가게 1개 = 브랜드 1개(is_franchise = false)
create table brands (
  id                   bigint generated always as identity primary key,
  name                 text not null,
  is_franchise         boolean not null default false,
  category_id          smallint references food_categories (id),
  image_url            text,
  official_domains     text[] not null default '{}',   -- 공식 사이트 도메인 (http 접두사 없이)
  allergen_source_url  text,                           -- 공식 알레르기 페이지
  allergen_data_date   date,                           -- 공식 표 기준일
  shared_notice        text,                           -- 조리기구 공유 등 브랜드 공지
  research_status      text not null default 'pending'
                       check (research_status in ('pending', 'running', 'done', 'failed')),
  researched_at        timestamptz,
  research_error       text,
  created_by           uuid references profiles (id) on delete set null,  -- 사용자가 추가한 가게면 추가한 사람 (공공데이터·조사 브랜드는 null)
  created_at           timestamptz not null default now()
);
-- 프랜차이즈 이름은 중복 불가 (개인 식당은 같은 이름이 여러 곳일 수 있다)
create unique index brands_franchise_name_uidx on brands (name) where is_franchise;

-- 지점. 공공데이터(소상공인 상가정보)에서 전국 지점을 가져온다.
create table restaurants (
  id           bigint generated always as identity primary key,
  brand_id     bigint not null references brands (id),
  external_id  text unique,                        -- 공공데이터 상가업소번호 등 외부 고유번호
  name         text not null,
  address      text not null,
  sido         text,
  sigungu      text,
  region       text not null,                      -- 구 단위 필터용. 예: '서울시 구로구'
  phone        text,
  image_url    text,
  created_at   timestamptz not null default now()
);
create index restaurants_region_idx on restaurants (region);
create index restaurants_brand_idx on restaurants (brand_id);

-- 메뉴는 브랜드 소속이다 (같은 브랜드의 모든 지점이 공유)
create table menus (
  id                   bigint generated always as identity primary key,
  brand_id             bigint not null references brands (id) on delete cascade,
  name                 text not null,
  description          text,
  image_url            text,
  allergen_status      allergen_status not null default 'unknown',
  allergen_source_url  text,                           -- 이 메뉴의 알레르기 정보 출처
  allergen_checked_at  timestamptz,
  allergen_note        text,                           -- 예: '세트 기준 표기'
  menu_source_url      text,                           -- 메뉴 자체의 출처 (비공식일 수 있음)
  menu_source_name     text,                           -- 비공식 출처 표시용 이름
  constraint menus_brand_name_key unique (brand_id, name)
);
create index menus_name_idx on menus (name);

-- 메뉴 자체의 맛 태그 (신규 사용자 추천·일치도 계산에 사용)
create table menu_taste_tags (
  menu_id       bigint   not null references menus (id) on delete cascade,
  taste_tag_id  smallint not null references taste_tags (id),
  primary key (menu_id, taste_tag_id)
);

-- danger = 알레르기 재료 포함(위험, 조사의 contains), caution = 혼입 가능성(주의, 조사의 may_contain)
-- 알레르기 정보가 없는 메뉴는 행을 만들지 않고 menus.allergen_status = 'unknown' 으로 표시한다.
create table menu_allergens (
  menu_id        bigint   not null references menus (id) on delete cascade,
  allergen_id    smallint not null references allergens (id),
  level          allergen_level not null default 'danger',
  original_text  text,                             -- 공식 원문 표기 보존 (예: '난류 / 달걀')
  primary key (menu_id, allergen_id)
);

-- ---------------------------------------------------------------------
-- 5. 평가 (유사도 계산의 원천 데이터). 평가 단위는 브랜드 메뉴다.
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
-- 7. 집계 뷰 (메뉴·브랜드·지점 평점, 지점 입맛 태그)
--    security_invoker: 조회하는 사용자의 RLS 를 그대로 적용한다.
--    지점이 많으므로 목록 RPC 는 지점 뷰 대신 brand_stats 를 브랜드 단위로 조회한다.
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

-- 지점별 집계: 소속 브랜드 메뉴의 평가
create view restaurant_stats with (security_invoker = true) as
select r.id                              as restaurant_id,
       round(avg(rv.rating)::numeric, 1) as avg_rating,
       count(rv.id)                      as review_count
from restaurants r
join menus m on m.brand_id = r.brand_id
join reviews rv on rv.menu_id = m.id
group by r.id;

-- 지점별 입맛 태그: 소속 브랜드 메뉴 태그의 합집합
create view restaurant_taste_tags with (security_invoker = true) as
select distinct r.id as restaurant_id, mt.taste_tag_id
from restaurants r
join menus m on m.brand_id = r.brand_id
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
alter table brands                  enable row level security;
alter table restaurants             enable row level security;
alter table menus                   enable row level security;
alter table menu_taste_tags         enable row level security;
alter table menu_allergens          enable row level security;
alter table reviews                 enable row level security;
alter table review_taste_tags       enable row level security;
alter table saved_restaurants       enable row level security;
alter table saved_menus             enable row level security;

-- ---------------------------------------------------------------------
-- 10. 친구랑 궁합 검사 (행사 체험용)
--     PART 1: 둘 중 하나 문항 → 같은 답 비율이 궁합 점수 / PART 2: 방마다 무작위 음식 → 먹어봤는지·별점 → 결과 카드
--     이 테이블들은 클라이언트에 직접 열지 않는다. RLS 를 켜고 권한·정책을 주지 않으며, functions.sql 의 RPC 로만 읽고 쓴다.
-- ---------------------------------------------------------------------
-- PART 1 문항: 둘 중 하나를 고른다 (A=1, B=2). 같은 답을 고른 비율이 궁합 점수다.
create table if not exists match_questions (
  id          smallint generated always as identity primary key,
  sort_order  smallint not null,
  body        text not null,
  option_a    text not null,
  option_b    text not null,
  is_active   boolean not null default true    -- false 면 새 검사에 나오지 않는다
);

-- PART 2 음식 후보: 방을 만들 때 이 중에서 무작위로 몇 개를 뽑는다
create table if not exists match_foods (
  id         smallint generated always as identity primary key,
  name       text not null unique,
  is_active  boolean not null default true
);

-- 방: 같이 온 친구끼리 같은 4자리 번호로 묶는다. 검사 한 번 = 방 하나 (다시 검사하려면 새 방을 만든다)
create table if not exists match_rooms (
  id          bigint generated always as identity primary key,
  code        text not null unique check (code ~ '^[0-9]{4}$'),
  created_by  uuid not null references profiles (id) on delete cascade,
  created_at  timestamptz not null default now()
);

-- 그 방에서 나올 음식: 방을 만들 때 정해지므로 같은 방 친구에게는 같은 음식이 나온다
create table if not exists match_room_foods (
  room_id     bigint   not null references match_rooms (id) on delete cascade,
  food_id     smallint not null references match_foods (id) on delete cascade,
  sort_order  smallint not null,
  primary key (room_id, food_id)
);

-- member_no: 방 안에서의 번호(들어온 순서). 다른 사람을 가리킬 때 사용자 id 대신 쓴다
create table if not exists match_room_members (
  room_id       bigint   not null references match_rooms (id) on delete cascade,
  user_id       uuid     not null references profiles (id) on delete cascade,
  member_no     smallint not null,
  joined_at     timestamptz not null default now(),
  completed_at  timestamptz,                     -- 검사를 마친 시각 (null 이면 아직 안 함)
  primary key (room_id, user_id),
  unique (room_id, member_no)
);

create table if not exists match_answers (
  room_id      bigint   not null,
  user_id      uuid     not null,
  question_id  smallint not null references match_questions (id) on delete cascade,
  choice       smallint not null check (choice in (1, 2)),
  primary key (room_id, user_id, question_id),
  foreign key (room_id, user_id) references match_room_members (room_id, user_id) on delete cascade
);

-- 먹어봤으면 별점(rating), 안 먹어봤으면 먹어보고 싶은지(want_try)를 받는다. 안 먹어본 음식은 궁합 점수에 쓰지 않는다
create table if not exists match_food_answers (
  room_id   bigint   not null,
  user_id   uuid     not null,
  food_id   smallint not null references match_foods (id) on delete cascade,
  eaten     boolean  not null,
  rating    smallint check (rating between 1 and 5),
  want_try  boolean,
  primary key (room_id, user_id, food_id),
  foreign key (room_id, user_id) references match_room_members (room_id, user_id) on delete cascade,
  check ((eaten and rating is not null and want_try is null) or (not eaten and rating is null and want_try is not null))
);

alter table match_questions      enable row level security;
alter table match_foods          enable row level security;
alter table match_rooms          enable row level security;
alter table match_room_foods     enable row level security;
alter table match_room_members   enable row level security;
alter table match_answers        enable row level security;
alter table match_food_answers   enable row level security;

-- ---------------------------------------------------------------------
-- 11. 가게 추가 (사용자가 직접 추가하는 개인 식당)
--   가게·메뉴는 brands(created_by)·restaurants·menus 에 들어간다. 이 표는 AI 추정 요청 횟수를 세는 용도다(하루 한도).
--   클라이언트에 직접 열지 않는다. functions.sql 의 RPC(begin_store_add)로만 쓴다.
-- ---------------------------------------------------------------------
create table if not exists store_add_attempts (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references profiles (id) on delete cascade,
  created_at  timestamptz not null default now()
);
create index if not exists store_add_attempts_user_idx on store_add_attempts (user_id, created_at);

alter table store_add_attempts enable row level security;

-- ---------------------------------------------------------------------
-- 12. 궁합 영수증 사진 올리기 (손님 폰 → 진행자 인쇄 화면)
--   손님이 결과 화면에서 찍은 사진(가로 480 JPEG 를 data URL 로)과 인쇄 요청을 방마다 1건 둔다. 하루가 지난 요청은 새 요청이 올 때 지운다.
--   클라이언트에 직접 열지 않는다. functions.sql 의 RPC 로만 읽고 쓴다. 진행자용 RPC 는 진행자 번호가 맞아야 한다.
-- ---------------------------------------------------------------------
create table if not exists match_print_requests (
  id            bigint generated always as identity primary key,
  room_id       bigint not null unique references match_rooms (id) on delete cascade,
  requested_by  uuid not null references profiles (id) on delete cascade,
  photo         text not null check (photo like 'data:image/jpeg;base64,%' and char_length(photo) <= 200000),
  show_on_rank  boolean not null default false,   -- 손님이 랭킹 화면에 사진을 띄워도 된다고 한 경우만 true
  created_at    timestamptz not null default now(),
  printed_at    timestamptz
);

-- 진행자 번호(인쇄 화면에서 한 번 입력). 값은 저장소에 두지 않고 DB 에만 넣는다: insert into match_print_settings (passcode) values ('...');
create table if not exists match_print_settings (
  id        boolean primary key default true check (id),
  passcode  text not null check (char_length(passcode) >= 6)
);

alter table match_print_requests enable row level security;
alter table match_print_settings enable row level security;

-- ---------------------------------------------------------------------
-- 13. 다른 폰으로 사진 보내기 (PC 에서 검사한 손님: 화면의 QR 을 폰으로 찍어 사진을 올린다)
--   QR 주소에 들어가는 일회용에 가까운 표(token). 30분 동안만 쓸 수 있고, 로그인하지 않은 폰도 이 표로 그 방의 사진 1건만 올릴 수 있다.
--   클라이언트에 직접 열지 않는다. functions.sql 의 RPC 로만 읽고 쓴다.
-- ---------------------------------------------------------------------
create table if not exists match_photo_tokens (
  token       uuid primary key default gen_random_uuid(),
  room_id     bigint not null references match_rooms (id) on delete cascade,
  created_by  uuid not null references profiles (id) on delete cascade,
  created_at  timestamptz not null default now()
);

alter table match_photo_tokens enable row level security;
