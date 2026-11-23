-- =====================================================================
-- T:MATE seed_demo_users.sql  (체험용 데모 사용자, 로그인 불가, 행사 후 삭제)
--
-- 체험 행사에서 취향 메이트·협업 추천이 보이도록 만든 가상 사용자 6명(seed01~seed06)이다.
-- 비밀번호는 만들 때마다 외부에 알려지지 않는 무작위 값으로 정하므로 로그인할 수 없다.
-- 평가(reviews)는 seed_demo_reviews.sql 이 넣는다. 닉네임은 모두 "데모"로 시작한다.
--
-- 실행 순서: schema.sql(또는 migrations/001) → policies.sql → functions.sql → seed_reference.sql
--            → seed_branches.sql → seed_brand_menus.sql → 이 파일 → seed_demo_reviews.sql
--   * seed_reference.sql 이 먼저 실행되어 있어야 합니다 (taste_tags·allergens 를 이름으로 참조).
--
-- 데모 사용자: seed01~seed06 (이메일 seedNN@tmate-app.com)
--   데모 매콤러 / 데모 달콤러 / 데모 고소러 / 데모 감칠러 / 데모 단짠러 / 데모 짭짤러
--   알레르기: seed02 알류, seed05 우유·땅콩 (본인 추천에만 쓰이므로 방문자 화면에는 영향 없음)
--
-- 재실행: 먼저 아래 한 줄로 데모 사용자를 지운 뒤(profiles·user_*·reviews 가 cascade 로 함께 삭제) 다시 실행합니다.
--   delete from auth.users where email like 'seed%@tmate-app.com';
-- 행사 후 삭제: 위 한 줄만 실행하면 데모 사용자와 그 취향·알레르기·평가 데이터가 모두 사라집니다.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 6. 데모 사용자 6명
--    auth.users 에 직접 넣으면 handle_new_user 트리거가 profiles 를 만든다. (username = 이메일 앞부분)
--    비밀번호는 무작위 값의 bcrypt 해시다 (pgcrypto 는 Supabase 에서 extensions 스키마). 원문은 어디에도 남지 않는다.
-- ---------------------------------------------------------------------
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  email_change_token_current, phone_change, phone_change_token, reauthentication_token
)
select
  '00000000-0000-0000-0000-000000000000', v.id, 'authenticated', 'authenticated', v.email,
  extensions.crypt(encode(extensions.gen_random_bytes(32), 'hex'), extensions.gen_salt('bf')),
  now(), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
  now(), now(),
  '', '', '', '',
  '', '', '', ''
from (values
  ('5eed0000-0000-4000-8000-000000000001'::uuid, 'seed01@tmate-app.com'),
  ('5eed0000-0000-4000-8000-000000000002'::uuid, 'seed02@tmate-app.com'),
  ('5eed0000-0000-4000-8000-000000000003'::uuid, 'seed03@tmate-app.com'),
  ('5eed0000-0000-4000-8000-000000000004'::uuid, 'seed04@tmate-app.com'),
  ('5eed0000-0000-4000-8000-000000000005'::uuid, 'seed05@tmate-app.com'),
  ('5eed0000-0000-4000-8000-000000000006'::uuid, 'seed06@tmate-app.com')
) as v(id, email);

-- 이메일 로그인용 identity (provider 'email', provider_id = 사용자 id)
insert into auth.identities (id, user_id, provider_id, provider, identity_data, last_sign_in_at, created_at, updated_at)
select gen_random_uuid(), u.id, u.id::text, 'email',
       jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true, 'phone_verified', false),
       now(), now(), now()
from auth.users u
where u.email like 'seed%@tmate-app.com';

-- 트리거가 만든 profiles 를 채운다 (닉네임, 지역 구로구/관악구 번갈아, 온보딩 완료)
update profiles p
set nickname = v.nickname, region = v.region, onboarding_done = true
from (values
  ('seed01', '데모 매콤러', '서울시 구로구'),
  ('seed02', '데모 달콤러', '서울시 관악구'),
  ('seed03', '데모 고소러', '서울시 구로구'),
  ('seed04', '데모 감칠러', '서울시 관악구'),
  ('seed05', '데모 단짠러', '서울시 구로구'),
  ('seed06', '데모 짭짤러', '서울시 관악구')
) as v(username, nickname, region)
where p.username = v.username;

-- ---------------------------------------------------------------------
-- 7. 입맛 비율 (사용자별 합계 100). 닉네임의 맛이 비율 상위 맛이다.
--    쓰는 맛은 실제 메뉴의 맛 태그(매콤함·달콤함·짭조름함·고소함·감칠맛)뿐이다.
--    seed_demo_reviews.sql 이 같은 값으로 다시 맞춘다 (옛 데이터가 남은 DB 용).
-- ---------------------------------------------------------------------
insert into user_taste_preferences (user_id, taste_tag_id, ratio)
select p.id, t.id, v.ratio
from (values
  ('seed01', 'spicy', 50),
  ('seed01', 'salty', 30),
  ('seed01', 'umami', 20),
  ('seed02', 'sweet', 55),
  ('seed02', 'salty', 25),
  ('seed02', 'umami', 20),
  ('seed03', 'nutty', 55),
  ('seed03', 'salty', 25),
  ('seed03', 'sweet', 20),
  ('seed04', 'umami', 50),
  ('seed04', 'nutty', 30),
  ('seed04', 'sweet', 20),
  ('seed05', 'salty', 45),
  ('seed05', 'sweet', 40),
  ('seed05', 'nutty', 15),
  ('seed06', 'salty', 60),
  ('seed06', 'spicy', 25),
  ('seed06', 'umami', 15)
) as v(username, tag, ratio)
join profiles p on p.username = v.username
join taste_tags t on t.code = v.tag;

-- user_allergens (3행, 2명)
insert into user_allergens (user_id, allergen_id)
select p.id, a.id
from (values
  ('seed02', '알류'),
  ('seed05', '우유'),
  ('seed05', '땅콩')
) as v(username, allergen)
join profiles p on p.username = v.username
join allergens a on a.name = v.allergen;
