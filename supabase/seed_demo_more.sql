-- =====================================================================
-- T:MATE seed_demo_more.sql  (체험용 데모 사용자 14명 추가 + 데모 사용자 20명이 전체 메뉴를 평가, 멱등)
--
-- 하는 일 (모두 추가만 한다. 기존 사용자·평가는 건드리지 않는다)
--   a. 데모 사용자 demo01~demo14 를 만든다 (비밀번호는 무작위 값이라 로그인할 수 없다). 닉네임은 "데모 ○○러".
--   b. 데모 사용자 20명(seed01~06 + demo01~14)이 메뉴 전체에서 사용자마다 약 30% 를 평가한다. random 을 쓰지 않는다.
--      · 기본 별점 = 메뉴의 맛 태그와 겹치는 사용자 입맛 비율의 합 (50 이상 5점 / 25 이상 4점 / 그 외 3점)에 규칙으로 정한 ±1 편차
--      · 이미 있는 평가(같은 사용자·메뉴)는 그대로 둔다.
--      · 맛 태그는 그 메뉴에 실제로 있는 태그 중 사용자 비율이 높은 순으로 1~2개
--   * 이 평가는 실제 사용자 평가가 아니다. 가게·메뉴 평균 평점과 취향 메이트에 섞여 보인다 (README "체험용 데모 데이터" 참고).
--   * 정리: delete from auth.users where email like 'demo%@tmate-app.com' or email like 'seed%@tmate-app.com';
-- 실행 순서: seed_brand_menus.sql · seed_demo_users.sql · seed_demo_reviews.sql 다음에 실행한다.
-- =====================================================================
begin;

-- a. 데모 사용자 (이미 있으면 건너뛴다)
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
  ('de300000-0000-4000-8000-000000000001'::uuid, 'demo01@tmate-app.com'),
  ('de300000-0000-4000-8000-000000000002'::uuid, 'demo02@tmate-app.com'),
  ('de300000-0000-4000-8000-000000000003'::uuid, 'demo03@tmate-app.com'),
  ('de300000-0000-4000-8000-000000000004'::uuid, 'demo04@tmate-app.com'),
  ('de300000-0000-4000-8000-000000000005'::uuid, 'demo05@tmate-app.com'),
  ('de300000-0000-4000-8000-000000000006'::uuid, 'demo06@tmate-app.com'),
  ('de300000-0000-4000-8000-000000000007'::uuid, 'demo07@tmate-app.com'),
  ('de300000-0000-4000-8000-000000000008'::uuid, 'demo08@tmate-app.com'),
  ('de300000-0000-4000-8000-000000000009'::uuid, 'demo09@tmate-app.com'),
  ('de300000-0000-4000-8000-000000000010'::uuid, 'demo10@tmate-app.com'),
  ('de300000-0000-4000-8000-000000000011'::uuid, 'demo11@tmate-app.com'),
  ('de300000-0000-4000-8000-000000000012'::uuid, 'demo12@tmate-app.com'),
  ('de300000-0000-4000-8000-000000000013'::uuid, 'demo13@tmate-app.com'),
  ('de300000-0000-4000-8000-000000000014'::uuid, 'demo14@tmate-app.com')
) as v(id, email)
where not exists (select 1 from auth.users u where u.email = v.email);

insert into auth.identities (id, user_id, provider_id, provider, identity_data, last_sign_in_at, created_at, updated_at)
select gen_random_uuid(), u.id, u.id::text, 'email',
       jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true, 'phone_verified', false),
       now(), now(), now()
from auth.users u
where u.email like 'demo%@tmate-app.com'
  and not exists (select 1 from auth.identities i where i.user_id = u.id);

update public.profiles p
set nickname = v.nickname, region = v.region, onboarding_done = true
from (values
  ('demo01', '데모 새콤러', '서울시 강남구'),
  ('demo02', '데모 담백러', '서울시 마포구'),
  ('demo03', '데모 느끼러', '서울시 송파구'),
  ('demo04', '데모 쌉쌀러', '서울시 종로구'),
  ('demo05', '데모 맵단러', '서울시 강서구'),
  ('demo06', '데모 고담러', '서울시 노원구'),
  ('demo07', '데모 감짭러', '서울시 영등포구'),
  ('demo08', '데모 달고러', '서울시 서초구'),
  ('demo09', '데모 매감러', '서울시 성동구'),
  ('demo10', '데모 새달러', '서울시 용산구'),
  ('demo11', '데모 담감러', '서울시 은평구'),
  ('demo12', '데모 짭고러', '서울시 동작구'),
  ('demo13', '데모 매새러', '서울시 광진구'),
  ('demo14', '데모 달담러', '서울시 중구')
) as v(username, nickname, region)
where p.username = v.username;

insert into public.user_taste_preferences (user_id, taste_tag_id, ratio)
select p.id, t.id, v.ratio
from (values
  ('demo01', 'sour', 50),
  ('demo01', 'sweet', 30),
  ('demo01', 'umami', 20),
  ('demo02', 'mild', 55),
  ('demo02', 'nutty', 25),
  ('demo02', 'umami', 20),
  ('demo03', 'rich', 45),
  ('demo03', 'nutty', 35),
  ('demo03', 'salty', 20),
  ('demo04', 'bitter', 40),
  ('demo04', 'sweet', 35),
  ('demo04', 'nutty', 25),
  ('demo05', 'spicy', 45),
  ('demo05', 'sweet', 35),
  ('demo05', 'umami', 20),
  ('demo06', 'nutty', 45),
  ('demo06', 'mild', 35),
  ('demo06', 'umami', 20),
  ('demo07', 'umami', 45),
  ('demo07', 'salty', 35),
  ('demo07', 'spicy', 20),
  ('demo08', 'sweet', 50),
  ('demo08', 'nutty', 30),
  ('demo08', 'rich', 20),
  ('demo09', 'spicy', 55),
  ('demo09', 'umami', 30),
  ('demo09', 'sour', 15),
  ('demo10', 'sour', 40),
  ('demo10', 'sweet', 40),
  ('demo10', 'mild', 20),
  ('demo11', 'mild', 45),
  ('demo11', 'umami', 35),
  ('demo11', 'salty', 20),
  ('demo12', 'salty', 45),
  ('demo12', 'nutty', 35),
  ('demo12', 'rich', 20),
  ('demo13', 'spicy', 50),
  ('demo13', 'sour', 30),
  ('demo13', 'salty', 20),
  ('demo14', 'sweet', 45),
  ('demo14', 'mild', 35),
  ('demo14', 'bitter', 20)
) as v(username, tag, ratio)
join public.profiles p on p.username = v.username
join public.taste_tags t on t.code = v.tag
on conflict (user_id, taste_tag_id) do nothing;

-- b. 평가
create temporary table demo_more_plan on commit drop as
with demo_users as (
  select p.id as user_id, row_number() over (order by p.username)::int as u
  from public.profiles p
  where p.username ~ '^(seed0[1-6]|demo(0[1-9]|1[0-4]))$'
),
scored as (
  select du.user_id, du.u, m.id as menu_id,
         coalesce((
           select sum(utp.ratio)
           from public.user_taste_preferences utp
           join public.menu_taste_tags mt on mt.taste_tag_id = utp.taste_tag_id
           where utp.user_id = du.user_id and mt.menu_id = m.id
         ), 0) as score
  from demo_users du
  cross join public.menus m
  join public.brands b on b.id = m.brand_id and b.is_franchise
  -- 사용자마다 다른 메뉴 집합: 메뉴의 약 30% 를 평가한다 (메뉴마다 약 6명)
  where (m.id * 7 + du.u * 13) % 10 < 3
)
select s.user_id, s.u, s.menu_id,
       greatest(1, least(5,
         case when s.score >= 50 then 5 when s.score >= 25 then 4 else 3 end
         + case (s.menu_id * 3 + s.u * 5) % 7 when 0 then -1 when 1 then 1 when 2 then -1 else 0 end
       ))::smallint as rating
from scored s;

insert into public.reviews (user_id, menu_id, rating)
select user_id, menu_id, rating from demo_more_plan
on conflict (user_id, menu_id) do nothing;

insert into public.review_taste_tags (review_id, taste_tag_id)
select r.id, x.taste_tag_id
from demo_more_plan dp
join public.reviews r on r.user_id = dp.user_id and r.menu_id = dp.menu_id
cross join lateral (
  select t.taste_tag_id,
         row_number() over (order by coalesce(utp.ratio, 0) desc, t.taste_tag_id) as rn
  from public.menu_taste_tags t
  left join public.user_taste_preferences utp on utp.user_id = dp.user_id and utp.taste_tag_id = t.taste_tag_id
  where t.menu_id = dp.menu_id
) x
where x.rn = 1 or (x.rn = 2 and (dp.u + dp.menu_id) % 2 = 0)
on conflict (review_id, taste_tag_id) do nothing;

commit;
