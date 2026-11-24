-- =====================================================================
-- 003_match_test.sql — 친구랑 궁합 검사용 테이블 7개를 추가한다.
--   match_questions, match_foods, match_rooms, match_room_foods, match_room_members, match_answers, match_food_answers
--   * 기존 테이블·데이터는 건드리지 않는다. create table if not exists 라 재실행해도 안전하다.
--   * 이 테이블들은 클라이언트에 직접 열지 않는다(RLS 켜고 권한 회수). functions.sql 의 RPC 로만 읽고 쓴다.
-- 실행 순서: 이 파일 → functions.sql (통째로 재실행, 궁합 검사 RPC 가 들어 있다) → seed_match.sql (문항·음식)
--   실행 후 `npm run gen:types` 로 src/types/database.types.ts 를 다시 만든다.
-- =====================================================================
begin;

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

revoke all on match_questions, match_foods, match_rooms, match_room_foods, match_room_members, match_answers, match_food_answers from anon, authenticated;

commit;
