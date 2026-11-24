-- 용도: RLS(Row Level Security) 활성화 및 정책 정의
-- 규칙: 이 파일을 바꾸면 docs/erd.md 와 src/types/database.types.ts(npm run gen:types)도 같은 PR 에서 갱신한다.
--
-- 실행: schema.sql(또는 migrations/001_brand_structure.sql) 적용 후 Supabase SQL Editor 에서 한 번에 실행한다. (RLS 활성화는 schema.sql 에 이미 있다)
-- 원칙: 모든 정책은 `to authenticated` 만 만든다. anon(비로그인)은 정책이 없으므로 어떤 테이블도 읽거나 쓸 수 없다.
-- 재실행: 가능. grant/revoke 는 멱등이고, 정책은 모두 drop policy if exists 후 create 한다.

-- ---------------------------------------------------------------------
-- 0. 테이블 권한 (GRANT)
--    Supabase 새 프로젝트는 public 테이블에 authenticated 의 기본 권한을 주지 않는다.
--    권한이 없으면 RLS 정책을 보기도 전에 `permission denied for table` 이 나므로, 필요한 권한만 명시적으로 준다.
--    RLS 는 "어떤 행"을, GRANT 는 "어떤 동작"을 허용한다. 둘 다 있어야 동작한다.
--    모두 authenticated 에게만 주고 anon 에는 주지 않는다. grant/revoke 는 멱등이라 재실행해도 안전하다.
-- ---------------------------------------------------------------------
-- 불필요한 권한 회수: truncate 는 RLS 를 우회하고, references·trigger 는 클라이언트가 쓸 일이 없다
revoke references, trigger, truncate on all tables in schema public from anon, authenticated;

-- 기준 데이터·브랜드·가게·메뉴: 읽기만 (쓰기는 클라이언트에 열지 않는다)
grant select on food_categories, taste_tags, allergens, brands, restaurants, menus, menu_taste_tags, menu_allergens
  to authenticated;
-- 브랜드·집계 뷰는 anon 에 주지 않는다 (Supabase 기본 권한이 있더라도 회수)
revoke all on brands, brand_stats from anon;

-- profiles: 조회만 부여한다. 수정은 table-level update 없이 아래 컬럼 권한으로만 허용한다 (username·id·created_at 변경 불가)
--   순서 주의: 먼저 table-level update 를 회수(컬럼 권한도 함께 지워짐)한 뒤 컬럼 권한을 준다.
grant select on profiles to authenticated;
revoke update on profiles from authenticated;
grant update (nickname, region, avatar_url, onboarding_done) on profiles to authenticated;

-- 본인 데이터·평가: 조회/추가/수정/삭제 (행 단위 제한은 아래 RLS 정책이 담당)
grant select, insert, update, delete
  on user_taste_preferences, user_allergens, saved_restaurants, saved_menus, reviews
  to authenticated;

-- 평가 맛 태그: 수정은 삭제 후 재추가하므로 update 는 주지 않는다
grant select, insert, delete on review_taste_tags to authenticated;

-- 집계 뷰(security_invoker): 조회하는 사용자의 권한·RLS 가 그대로 적용되므로 뷰에도 select 가 필요하다
grant select on menu_stats, brand_stats, restaurant_stats, restaurant_taste_tags to authenticated;

-- ---------------------------------------------------------------------
-- 1. 기준 데이터 / 가게 / 메뉴: 로그인 사용자는 읽기만 가능 (쓰기는 클라이언트에 열지 않는다)
-- ---------------------------------------------------------------------
-- 음식 카테고리: 홈 필터에 필요하므로 로그인 사용자 전체 조회 허용
drop policy if exists "food_categories_select" on food_categories;
create policy "food_categories_select" on food_categories
  for select to authenticated using (true);

-- 맛 태그: 온보딩·칩 표시에 필요하므로 조회 허용
drop policy if exists "taste_tags_select" on taste_tags;
create policy "taste_tags_select" on taste_tags
  for select to authenticated using (true);

-- 알레르기 목록: 온보딩·메뉴 상세에 필요하므로 조회 허용
drop policy if exists "allergens_select" on allergens;
create policy "allergens_select" on allergens
  for select to authenticated using (true);

-- 브랜드: 가게 카드·상세에 필요하므로 로그인 사용자 전체 조회 허용 (쓰기는 서버 측 조사/import 로만)
drop policy if exists "brands_select" on brands;
create policy "brands_select" on brands
  for select to authenticated using (true);

-- 가게(지점): 모든 로그인 사용자가 목록·상세를 볼 수 있어야 한다
drop policy if exists "restaurants_select" on restaurants;
create policy "restaurants_select" on restaurants
  for select to authenticated using (true);

-- 메뉴: 가게 상세·평가 화면에 필요하므로 조회 허용
drop policy if exists "menus_select" on menus;
create policy "menus_select" on menus
  for select to authenticated using (true);

-- 메뉴 맛 태그: 일치도 계산·칩 표시에 필요하므로 조회 허용
drop policy if exists "menu_taste_tags_select" on menu_taste_tags;
create policy "menu_taste_tags_select" on menu_taste_tags
  for select to authenticated using (true);

-- 메뉴 알레르기 정보: 알레르기 경고 표시에 필요하므로 조회 허용
drop policy if exists "menu_allergens_select" on menu_allergens;
create policy "menu_allergens_select" on menu_allergens
  for select to authenticated using (true);

-- ---------------------------------------------------------------------
-- 2. profiles: 본인 행만 조회·수정. insert 는 가입 트리거, delete 는 auth.users 삭제(cascade)로만 일어난다.
-- ---------------------------------------------------------------------
-- 다른 사용자의 아이디·닉네임 등 식별 정보가 새지 않도록 본인 행만 조회한다
drop policy if exists "profiles_select_own" on profiles;
create policy "profiles_select_own" on profiles
  for select to authenticated using (id = (select auth.uid()));

-- 본인 행만 수정한다. 수정 가능한 컬럼은 아래 grant 로 다시 한 번 제한한다
drop policy if exists "profiles_update_own" on profiles;
create policy "profiles_update_own" on profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- 수정 가능한 컬럼 제한(username 변경 불가)은 위 "0. 테이블 권한" 섹션의 컬럼 권한이 담당한다

-- ---------------------------------------------------------------------
-- 3. 본인 데이터 전용 테이블: 본인 행만 select / insert / update / delete
-- ---------------------------------------------------------------------
-- 입맛 선택·비율: 본인 것만 조회
drop policy if exists "user_taste_preferences_select_own" on user_taste_preferences;
create policy "user_taste_preferences_select_own" on user_taste_preferences
  for select to authenticated using (user_id = (select auth.uid()));
-- 입맛 선택·비율: 본인 이름으로만 추가 (with check 로 남의 user_id 삽입 차단)
drop policy if exists "user_taste_preferences_insert_own" on user_taste_preferences;
create policy "user_taste_preferences_insert_own" on user_taste_preferences
  for insert to authenticated with check (user_id = (select auth.uid()));
-- 입맛 선택·비율: 본인 것만 수정하고, 수정 후에도 본인 소유여야 한다
drop policy if exists "user_taste_preferences_update_own" on user_taste_preferences;
create policy "user_taste_preferences_update_own" on user_taste_preferences
  for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
-- 입맛 선택·비율: 본인 것만 삭제 (온보딩 재설정)
drop policy if exists "user_taste_preferences_delete_own" on user_taste_preferences;
create policy "user_taste_preferences_delete_own" on user_taste_preferences
  for delete to authenticated using (user_id = (select auth.uid()));

-- 사용자 알레르기: 본인 것만 조회 (민감한 건강 정보)
drop policy if exists "user_allergens_select_own" on user_allergens;
create policy "user_allergens_select_own" on user_allergens
  for select to authenticated using (user_id = (select auth.uid()));
-- 사용자 알레르기: 본인 이름으로만 추가
drop policy if exists "user_allergens_insert_own" on user_allergens;
create policy "user_allergens_insert_own" on user_allergens
  for insert to authenticated with check (user_id = (select auth.uid()));
-- 사용자 알레르기: 본인 것만 수정
drop policy if exists "user_allergens_update_own" on user_allergens;
create policy "user_allergens_update_own" on user_allergens
  for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
-- 사용자 알레르기: 본인 것만 삭제
drop policy if exists "user_allergens_delete_own" on user_allergens;
create policy "user_allergens_delete_own" on user_allergens
  for delete to authenticated using (user_id = (select auth.uid()));

-- 저장한 가게: 본인 것만 조회
drop policy if exists "saved_restaurants_select_own" on saved_restaurants;
create policy "saved_restaurants_select_own" on saved_restaurants
  for select to authenticated using (user_id = (select auth.uid()));
-- 저장한 가게: 본인 이름으로만 저장
drop policy if exists "saved_restaurants_insert_own" on saved_restaurants;
create policy "saved_restaurants_insert_own" on saved_restaurants
  for insert to authenticated with check (user_id = (select auth.uid()));
-- 저장한 가게: 본인 것만 수정
drop policy if exists "saved_restaurants_update_own" on saved_restaurants;
create policy "saved_restaurants_update_own" on saved_restaurants
  for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
-- 저장한 가게: 본인 것만 저장 해제
drop policy if exists "saved_restaurants_delete_own" on saved_restaurants;
create policy "saved_restaurants_delete_own" on saved_restaurants
  for delete to authenticated using (user_id = (select auth.uid()));

-- 저장한 메뉴: 본인 것만 조회
drop policy if exists "saved_menus_select_own" on saved_menus;
create policy "saved_menus_select_own" on saved_menus
  for select to authenticated using (user_id = (select auth.uid()));
-- 저장한 메뉴: 본인 이름으로만 저장
drop policy if exists "saved_menus_insert_own" on saved_menus;
create policy "saved_menus_insert_own" on saved_menus
  for insert to authenticated with check (user_id = (select auth.uid()));
-- 저장한 메뉴: 본인 것만 수정
drop policy if exists "saved_menus_update_own" on saved_menus;
create policy "saved_menus_update_own" on saved_menus
  for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
-- 저장한 메뉴: 본인 것만 저장 해제
drop policy if exists "saved_menus_delete_own" on saved_menus;
create policy "saved_menus_delete_own" on saved_menus
  for delete to authenticated using (user_id = (select auth.uid()));

-- ---------------------------------------------------------------------
-- 4. reviews / review_taste_tags
-- ---------------------------------------------------------------------
-- 평가: 가게·메뉴 평점 뷰(security_invoker)가 전체 평가를 읽어야 평균이 맞으므로 로그인 사용자 전체에게 조회를 연다.
--       작성자 식별 정보(아이디·닉네임)는 profiles 정책이 막고 있다.
drop policy if exists "reviews_select_all" on reviews;
create policy "reviews_select_all" on reviews
  for select to authenticated using (true);
-- 평가: 본인 이름으로만 작성
drop policy if exists "reviews_insert_own" on reviews;
create policy "reviews_insert_own" on reviews
  for insert to authenticated with check (user_id = (select auth.uid()));
-- 평가: 본인 평가만 수정하고, 수정 후에도 본인 소유여야 한다
drop policy if exists "reviews_update_own" on reviews;
create policy "reviews_update_own" on reviews
  for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
-- 평가: 본인 평가만 삭제
drop policy if exists "reviews_delete_own" on reviews;
create policy "reviews_delete_own" on reviews
  for delete to authenticated using (user_id = (select auth.uid()));

-- 평가 맛 태그: 메뉴별 맛 집계에 쓰이므로 로그인 사용자 전체 조회 허용
drop policy if exists "review_taste_tags_select_all" on review_taste_tags;
create policy "review_taste_tags_select_all" on review_taste_tags
  for select to authenticated using (true);
-- 평가 맛 태그: 부모 평가가 본인 것일 때만 추가 (남의 평가에 태그를 붙이지 못하게)
drop policy if exists "review_taste_tags_insert_own" on review_taste_tags;
create policy "review_taste_tags_insert_own" on review_taste_tags
  for insert to authenticated
  with check (exists (
    select 1 from reviews r
    where r.id = review_taste_tags.review_id and r.user_id = (select auth.uid())
  ));
-- 평가 맛 태그: 부모 평가가 본인 것일 때만 삭제 (태그 수정은 삭제 후 재추가)
drop policy if exists "review_taste_tags_delete_own" on review_taste_tags;
create policy "review_taste_tags_delete_own" on review_taste_tags
  for delete to authenticated
  using (exists (
    select 1 from reviews r
    where r.id = review_taste_tags.review_id and r.user_id = (select auth.uid())
  ));

-- ---------------------------------------------------------------------
-- RLS 검증 (SQL Editor 에서 아래 주석을 풀어 한 블록씩 실행. 끝에 rollback 으로 되돌린다)
--   <A>, <B> 는 seed_demo_users.sql 의 가상 사용자 uuid 로 바꾼다. 예: seed01 = 5eed0000-0000-4000-8000-000000000001
--   user_allergens 에 행이 있는 사용자를 A 로 쓴다. (seed_demo_users.sql 기준 seed02 = 000000000002)
-- ---------------------------------------------------------------------
-- begin;
--   set local role authenticated;
--   select set_config('request.jwt.claims', '{"sub":"<A 사용자 uuid>","role":"authenticated"}', true);
--
--   -- (1) A 본인 알레르기: 1행 이상 보여야 한다
--   select * from user_allergens where user_id = '<A 사용자 uuid>';
--   -- (2) 다른 사용자 B 의 알레르기: 0행이어야 한다
--   select * from user_allergens where user_id = '<B 사용자 uuid>';
--   -- (3) 필터 없이 조회해도 본인 행만 나와야 한다 (count = A 의 행 수)
--   select count(*) from user_allergens;
--   -- (4) profiles 는 본인 1행만 (다른 사용자 조회 0행)
--   select id, username from profiles;
--   -- (5) username 수정은 거부되어야 한다 (permission denied for table profiles)
--   update profiles set username = 'hacker01' where id = '<A 사용자 uuid>';
-- rollback;
--
-- anon(비로그인) 확인: 0행이어야 한다 (정책이 없음)
-- begin;
--   set local role anon;
--   select count(*) from restaurants;
-- rollback;

-- ---------------------------------------------------------------------
-- 궁합 검사 테이블 (match_*)
--    클라이언트에 직접 열지 않는다. 권한과 정책을 주지 않고(RLS 는 schema.sql 에서 켠다) functions.sql 의 RPC 로만 읽고 쓴다.
--    RPC 는 같은 방 사람의 닉네임·궁합 점수·그 방 음식에 대한 답만 돌려준다.
-- ---------------------------------------------------------------------
revoke all on match_questions, match_foods, match_rooms, match_room_foods, match_room_members, match_answers, match_food_answers from anon, authenticated;

-- ---------------------------------------------------------------------
-- 가게 추가 요청 기록 (store_add_attempts)
--    클라이언트에 직접 열지 않는다. functions.sql 의 RPC(begin_store_add)로만 쓴다.
-- ---------------------------------------------------------------------
revoke all on store_add_attempts from anon, authenticated;

-- ---------------------------------------------------------------------
-- 궁합 영수증 사진·진행자 번호 (match_print_requests, match_print_settings)
--    클라이언트에 직접 열지 않는다. functions.sql 의 RPC 로만 읽고 쓴다.
-- ---------------------------------------------------------------------
revoke all on match_print_requests, match_print_settings from anon, authenticated;

-- 다른 폰으로 사진 보내기 표 (match_photo_tokens): 클라이언트에 직접 열지 않는다
revoke all on match_photo_tokens from anon, authenticated;
