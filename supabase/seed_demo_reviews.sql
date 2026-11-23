-- =====================================================================
-- T:MATE seed_demo_reviews.sql  (체험용 데모 사용자 정리·로그인 불가 처리·평가 데이터, 멱등 — 두 번 실행해도 같은 결과)
--
-- 하는 일
--   a. 예전 가상 사용자 seed07~seed12 삭제 (auth.users 삭제 → profiles → 취향·알레르기·평가·저장이 cascade 로 함께 삭제)
--   b. seed01~seed06 비밀번호를 무작위 값으로 덮어써 로그인 불가로 만들고, 로그인 세션도 지운다
--   c. seed01~seed06 닉네임("데모 ○○러")과 입맛 비율을 맞춘다 (닉네임의 맛 = 비율 상위 맛)
--   d. 데모 사용자 6명이 실제 메뉴(맥도날드·롯데리아 각 10개)를 사용자마다 13~14개씩 평가한다. random 을 쓰지 않는다.
--      · 기본 별점 = 메뉴의 맛 태그와 겹치는 사용자 입맛 비율의 합 (70 이상 5점 / 45 이상 4점 / 25 이상 3점 / 1 이상 2점 / 0 이면 1점)
--      · 사용자·메뉴마다 규칙으로 정한 ±1 편차를 약간 준다. 평가하는 메뉴 집합도 사용자마다 다르다.
--      · 맛 태그는 그 메뉴에 실제로 있는 태그 중 사용자 비율이 높은 순으로 1~2개
--   e. user_allergens 는 본인 추천(get_recommended_menus·get_allergy_menus)에만 쓰이므로 방문자 화면에 영향이 없어 손대지 않는다.
--
-- 실행 순서: schema → policies → functions → seed_reference → seed_branches → seed_brand_menus → seed_demo_users → 이 파일
--   * seed_demo_users.sql 의 seed01~seed06 과 seed_brand_menus.sql 의 메뉴 20개가 먼저 있어야 한다. 없으면 예외로 멈춘다.
--   * 행사 후 정리: delete from auth.users where email like 'seed%@tmate-app.com';
-- =====================================================================
begin;

-- ---------------------------------------------------------------------
-- a. seed07~seed12 삭제 (이미 없으면 아무 일도 없다)
-- ---------------------------------------------------------------------
delete from auth.identities
where user_id in (select id from auth.users where email in (
  'seed07@tmate-app.com', 'seed08@tmate-app.com', 'seed09@tmate-app.com',
  'seed10@tmate-app.com', 'seed11@tmate-app.com', 'seed12@tmate-app.com'));
delete from auth.users
where email in (
  'seed07@tmate-app.com', 'seed08@tmate-app.com', 'seed09@tmate-app.com',
  'seed10@tmate-app.com', 'seed11@tmate-app.com', 'seed12@tmate-app.com');

-- 데모 사용자가 없으면 멈춘다
do $$
begin
  if (select count(*) from public.profiles where username in ('seed01','seed02','seed03','seed04','seed05','seed06')) <> 6 then
    raise exception '데모 사용자 seed01~seed06 이(가) 없어요. seed_demo_users.sql 을 먼저 실행하세요.';
  end if;
end;
$$;

-- ---------------------------------------------------------------------
-- b. 로그인 불가: 비밀번호를 무작위 값의 해시로 덮어쓰고(원문은 남지 않는다) 기존 세션을 지운다
-- ---------------------------------------------------------------------
update auth.users
set encrypted_password = extensions.crypt(encode(extensions.gen_random_bytes(32), 'hex'), extensions.gen_salt('bf')),
    updated_at = now()
where email in (
  'seed01@tmate-app.com', 'seed02@tmate-app.com', 'seed03@tmate-app.com',
  'seed04@tmate-app.com', 'seed05@tmate-app.com', 'seed06@tmate-app.com');

delete from auth.sessions
where user_id in (select id from auth.users where email in (
  'seed01@tmate-app.com', 'seed02@tmate-app.com', 'seed03@tmate-app.com',
  'seed04@tmate-app.com', 'seed05@tmate-app.com', 'seed06@tmate-app.com'));

-- ---------------------------------------------------------------------
-- c. 닉네임·입맛 비율 (seed_demo_users.sql 과 같은 값)
-- ---------------------------------------------------------------------
update public.profiles p
set nickname = v.nickname
from (values
  ('seed01', '데모 매콤러'),
  ('seed02', '데모 달콤러'),
  ('seed03', '데모 고소러'),
  ('seed04', '데모 감칠러'),
  ('seed05', '데모 단짠러'),
  ('seed06', '데모 짭짤러')
) as v(username, nickname)
where p.username = v.username;

delete from public.user_taste_preferences
where user_id in (select id from public.profiles where username in ('seed01','seed02','seed03','seed04','seed05','seed06'));

insert into public.user_taste_preferences (user_id, taste_tag_id, ratio)
select p.id, t.id, v.ratio
from (values
  ('seed01', 'spicy', 50), ('seed01', 'salty', 30), ('seed01', 'umami', 20),
  ('seed02', 'sweet', 55), ('seed02', 'salty', 25), ('seed02', 'umami', 20),
  ('seed03', 'nutty', 55), ('seed03', 'salty', 25), ('seed03', 'sweet', 20),
  ('seed04', 'umami', 50), ('seed04', 'nutty', 30), ('seed04', 'sweet', 20),
  ('seed05', 'salty', 45), ('seed05', 'sweet', 40), ('seed05', 'nutty', 15),
  ('seed06', 'salty', 60), ('seed06', 'spicy', 25), ('seed06', 'umami', 15)
) as v(username, tag, ratio)
join public.profiles p on p.username = v.username
join public.taste_tags t on t.code = v.tag;

-- ---------------------------------------------------------------------
-- d. 평가. 먼저 데모 사용자의 평가를 모두 지우고(review_taste_tags 는 cascade) 규칙대로 다시 넣는다.
-- ---------------------------------------------------------------------
delete from public.reviews
where user_id in (select id from public.profiles where username in ('seed01','seed02','seed03','seed04','seed05','seed06'));

create temp table demo_plan on commit drop as
with demo_menus (idx, brand, menu) as (values
  (1,  '맥도날드', '빅맥'),
  (2,  '맥도날드', '맥스파이시 상하이버거'),
  (3,  '맥도날드', '1955 버거'),
  (4,  '맥도날드', '맥치킨'),
  (5,  '맥도날드', '더블 불고기버거'),
  (6,  '맥도날드', '불고기버거'),
  (7,  '맥도날드', '슈슈버거'),
  (8,  '맥도날드', '슈비버거'),
  (9,  '맥도날드', '쿼터파운더치즈'),
  (10, '맥도날드', '베이컨 토마토 디럭스'),
  (11, '롯데리아', '한우불고기버거 세트'),
  (12, '롯데리아', '리아 불고기 세트'),
  (13, '롯데리아', '리아 새우 세트'),
  (14, '롯데리아', '리아 사각새우 더블 세트'),
  (15, '롯데리아', '모짜렐라 인 더 버거 베이컨 세트'),
  (16, '롯데리아', '전주비빔라이스버거 세트'),
  (17, '롯데리아', '더블엑스투버거 세트'),
  (18, '롯데리아', '핫크리스피치킨버거 세트'),
  (19, '롯데리아', '클래식치즈버거 세트'),
  (20, '롯데리아', '데리버거 세트')
),
menu_ref as (
  select d.idx, m.id as menu_id
  from demo_menus d
  join public.brands b on b.name = d.brand and b.is_franchise
  join public.menus m on m.brand_id = b.id and m.name = d.menu
),
demo_users as (
  select p.id as user_id, substr(p.username, 5)::int as u
  from public.profiles p
  where p.username in ('seed01','seed02','seed03','seed04','seed05','seed06')
),
scored as (
  select du.user_id, du.u, mr.idx, mr.menu_id,
         coalesce((
           select sum(utp.ratio)
           from public.user_taste_preferences utp
           join public.menu_taste_tags mt on mt.taste_tag_id = utp.taste_tag_id
           where utp.user_id = du.user_id and mt.menu_id = mr.menu_id
         ), 0) as score
  from demo_users du
  cross join menu_ref mr
  -- 사용자마다 다른 메뉴 집합: 조건에 걸리는 메뉴(사용자당 6~7개)는 평가하지 않는다. 메뉴마다 4명이 평가한다.
  where (mr.idx + 2 * du.u) % 3 <> 0
)
select s.user_id, s.u, s.idx, s.menu_id, s.score,
       greatest(1, least(5,
         case when s.score >= 70 then 5
              when s.score >= 45 then 4
              when s.score >= 25 then 3
              when s.score >= 1  then 2
              else 1 end
         + case (s.idx * 3 + s.u * 5) % 7 when 0 then -1 when 1 then 1 else 0 end
       ))::smallint as rating
from scored s;

do $$
begin
  if (select count(distinct menu_id) from demo_plan) <> 20 then
    raise exception '데모 메뉴 20개를 모두 찾지 못했어요. seed_brand_menus.sql 을 먼저 실행하세요.';
  end if;
end;
$$;

insert into public.reviews (user_id, menu_id, rating)
select user_id, menu_id, rating from demo_plan;

-- 맛 태그: 그 메뉴에 실제로 있는 태그 중 사용자 비율이 높은 순으로 1개, 일부는 2개
insert into public.review_taste_tags (review_id, taste_tag_id)
select r.id, x.taste_tag_id
from demo_plan dp
join public.reviews r on r.user_id = dp.user_id and r.menu_id = dp.menu_id
cross join lateral (
  select t.taste_tag_id,
         row_number() over (order by coalesce(utp.ratio, 0) desc, t.taste_tag_id) as rn
  from public.menu_taste_tags t
  left join public.user_taste_preferences utp on utp.user_id = dp.user_id and utp.taste_tag_id = t.taste_tag_id
  where t.menu_id = dp.menu_id
) x
where x.rn = 1 or (x.rn = 2 and (dp.u + dp.idx) % 2 = 0);

commit;
