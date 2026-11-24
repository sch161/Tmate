-- =====================================================================
-- T:MATE seed_reference.sql  (운영에도 쓰는 기준 데이터, 멱등 — 여러 번 실행해도 안전하다)
-- 실행 순서: schema.sql(또는 migrations/001) → policies.sql → functions.sql → 이 파일
-- 내용: 음식 카테고리, 맛 태그 9개, 알레르기 식약처 표준 19종(표기명·별칭 포함)
-- =====================================================================

-- 1. 음식 카테고리
insert into food_categories (name) values
  ('한식'),
  ('중식'),
  ('일식'),
  ('양식'),
  ('카페·디저트')
on conflict (name) do nothing;

-- 2. 맛 태그 9개
-- TODO: 디자이너 확정 목록으로 교체
insert into taste_tags (code, name) values
  ('spicy', '매콤함'),
  ('sweet', '달콤함'),
  ('salty', '짭조름함'),
  ('sour', '새콤함'),
  ('nutty', '고소함'),
  ('mild', '담백함'),
  ('rich', '느끼함'),
  ('bitter', '쌉싸름함'),
  ('umami', '감칠맛')
on conflict (code) do update set name = excluded.name;

-- 3. 알레르기 식약처 표시 대상 19종 (name = 표준 이름, display_name = 화면 표기, aliases = 조사 결과 매핑용 별칭)
--    별칭은 scripts/research/standard-allergens.json 과 같다. 기존 행은 id 를 유지한 채 표기·별칭만 갱신한다.
insert into allergens (name, display_name, aliases) values
  ('알류',     '계란',     array['난류', '달걀', '계란', '계란류', '알', '달걀류']),
  ('우유',     '우유',     array['우유류', '밀크']),
  ('메밀',     '메밀',     array[]::text[]),
  ('땅콩',     '땅콩',     array['낙화생', '땅콩류']),
  ('대두',     '콩',       array['콩', '콩류', '대두류']),
  ('밀',       '밀',       array['소맥', '밀가루']),
  ('고등어',   '고등어',   array[]::text[]),
  ('게',       '게',       array['게류', '꽃게']),
  ('새우',     '새우',     array['새우류', '대하']),
  ('돼지고기', '돼지고기', array['돼지', '돈육']),
  ('복숭아',   '복숭아',   array[]::text[]),
  ('토마토',   '토마토',   array[]::text[]),
  ('아황산류', '아황산류', array['아황산염', '이산화황', '아황산나트륨']),
  ('호두',     '호두',     array['호두류']),
  ('닭고기',   '닭고기',   array['닭', '계육']),
  ('쇠고기',   '쇠고기',   array['소고기', '쇠고기류', '소고기류', '우육']),
  ('오징어',   '오징어',   array['오징어류']),
  ('조개류',   '조개류',   array['굴', '전복', '홍합', '가리비', '조개', '바지락']),
  ('잣',       '잣',       array['잣류'])
on conflict (name) do update set display_name = excluded.display_name, aliases = excluded.aliases;
