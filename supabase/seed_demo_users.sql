-- =====================================================================
-- T:MATE seed_demo_users.sql  (개발용 가상 사용자)
--
-- !!! 경고: 개발용 가상 사용자입니다. 비밀번호가 공개되어 있으므로 배포 전 반드시 삭제하세요 !!!
-- 평가(reviews) 데이터는 여기에 없습니다. 실제 브랜드·메뉴가 들어온 뒤 별도로 만듭니다.
--
-- 실행 순서: schema.sql(또는 migrations/001) → policies.sql → functions.sql → seed_reference.sql → 이 파일
--   * seed_reference.sql 이 먼저 실행되어 있어야 합니다 (taste_tags·allergens 를 이름으로 참조).
--   * 가상 사용자는 이메일 확인 완료 상태로 들어가므로 Email 확인 설정과 무관하게 로그인됩니다.
--
-- 가상 사용자: seed01 ~ seed12 (이메일 seedNN@tmate-app.com, 비밀번호 tmate-seed-1234)
--   매운맛파 seed01~04 / 단짠파 seed05~08 / 담백파 seed09~12
--   알레르기: seed02 알류, seed05 우유·땅콩, seed08 새우, seed11 복숭아·대두
--
-- 재실행: 먼저 아래 한 줄로 가상 사용자를 지운 뒤(profiles·user_* 가 cascade 로 함께 삭제) 다시 실행합니다.
--   delete from auth.users where email like 'seed%@tmate-app.com';
-- 배포 전 삭제: 위 한 줄만 실행하면 가상 사용자와 그 취향·알레르기 데이터가 모두 사라집니다.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 6. 가상 사용자 12명
--    auth.users 에 직접 넣으면 handle_new_user 트리거가 profiles 를 만든다. (username = 이메일 앞부분)
--    비밀번호 해시는 pgcrypto(extensions 스키마)로 만든다. 로그인에 필요한 컬럼을 모두 채운다.
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
  extensions.crypt('tmate-seed-1234', extensions.gen_salt('bf')),
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
  ('5eed0000-0000-4000-8000-000000000006'::uuid, 'seed06@tmate-app.com'),
  ('5eed0000-0000-4000-8000-000000000007'::uuid, 'seed07@tmate-app.com'),
  ('5eed0000-0000-4000-8000-000000000008'::uuid, 'seed08@tmate-app.com'),
  ('5eed0000-0000-4000-8000-000000000009'::uuid, 'seed09@tmate-app.com'),
  ('5eed0000-0000-4000-8000-000000000010'::uuid, 'seed10@tmate-app.com'),
  ('5eed0000-0000-4000-8000-000000000011'::uuid, 'seed11@tmate-app.com'),
  ('5eed0000-0000-4000-8000-000000000012'::uuid, 'seed12@tmate-app.com')
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
  ('seed01', '매운고수', '서울시 구로구'),
  ('seed02', '불꽃혀', '서울시 관악구'),
  ('seed03', '칼칼러버', '서울시 구로구'),
  ('seed04', '마라토너', '서울시 관악구'),
  ('seed05', '단짠단짠', '서울시 구로구'),
  ('seed06', '달콤짭짤', '서울시 관악구'),
  ('seed07', '간장마니아', '서울시 구로구'),
  ('seed08', '꿀짠러', '서울시 관악구'),
  ('seed09', '담백한하루', '서울시 구로구'),
  ('seed10', '순한맛러버', '서울시 관악구'),
  ('seed11', '슴슴이', '서울시 구로구'),
  ('seed12', '깔끔입맛', '서울시 관악구')
) as v(username, nickname, region)
where p.username = v.username;

-- ---------------------------------------------------------------------
-- 7. 취향 클러스터: 매운맛파 seed01~04 / 단짠파 seed05~08 / 담백파 seed09~12
--    user_taste_preferences (33행, 사용자별 ratio 합계 100)
-- ---------------------------------------------------------------------
insert into user_taste_preferences (user_id, taste_tag_id, ratio)
select p.id, t.id, v.ratio
from (values
  ('seed01', 'spicy', 60),
  ('seed01', 'sweet', 25),
  ('seed01', 'umami', 15),
  ('seed02', 'spicy', 50),
  ('seed02', 'umami', 30),
  ('seed02', 'salty', 20),
  ('seed03', 'spicy', 70),
  ('seed03', 'sweet', 30),
  ('seed04', 'spicy', 45),
  ('seed04', 'sweet', 35),
  ('seed04', 'rich', 20),
  ('seed05', 'sweet', 45),
  ('seed05', 'salty', 55),
  ('seed06', 'salty', 50),
  ('seed06', 'sweet', 30),
  ('seed06', 'rich', 20),
  ('seed07', 'salty', 60),
  ('seed07', 'umami', 25),
  ('seed07', 'sweet', 15),
  ('seed08', 'sweet', 50),
  ('seed08', 'salty', 30),
  ('seed08', 'nutty', 20),
  ('seed09', 'mild', 50),
  ('seed09', 'nutty', 30),
  ('seed09', 'umami', 20),
  ('seed10', 'mild', 60),
  ('seed10', 'sour', 40),
  ('seed11', 'mild', 45),
  ('seed11', 'nutty', 35),
  ('seed11', 'bitter', 20),
  ('seed12', 'nutty', 40),
  ('seed12', 'mild', 40),
  ('seed12', 'sour', 20)
) as v(username, tag, ratio)
join profiles p on p.username = v.username
join taste_tags t on t.code = v.tag;

-- user_allergens (6행, 4명)
insert into user_allergens (user_id, allergen_id)
select p.id, a.id
from (values
  ('seed02', '알류'),
  ('seed05', '우유'),
  ('seed05', '땅콩'),
  ('seed08', '새우'),
  ('seed11', '복숭아'),
  ('seed11', '대두')
) as v(username, allergen)
join profiles p on p.username = v.username
join allergens a on a.name = v.allergen;
