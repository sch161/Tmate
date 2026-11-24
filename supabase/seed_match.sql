-- =====================================================================
-- T:MATE seed_match.sql  (친구랑 궁합 검사: PART 1 문항 10개 + PART 2 음식 후보 21개)
--
-- PART 1 (match_questions): 둘 중 하나를 고르는 문항. 두 사람이 같은 답을 고른 비율이 궁합 점수다.
-- PART 2 (match_foods)    : 음식 후보. 방을 만들 때 이 중 5개(functions.sql 의 match_food_count)를 무작위로 뽑는다.
--
-- 재실행
--   * 음식은 이름 기준으로 없는 것만 추가한다. 목록에서 뺀 음식은 지우지 않고 is_active = false 로 바꾼다(지난 방의 답 보존).
--   * 문항은 모두 지우고 다시 넣는다 → 그 문항의 답(match_answers)도 함께 지워져 지난 방의 궁합 점수가 사라진다.
--     문구만 고칠 때는 이 파일 대신 update 로 고치고, 행사 도중에는 이 파일을 실행하지 않는다.
-- 실행 순서: migrations/003_match_test.sql → functions.sql → 이 파일
-- =====================================================================
begin;

delete from match_questions;

insert into match_questions (sort_order, body, option_a, option_b) values
  (1,  '치킨 한 마리를 시켰다! 가장 먼저 집을 부위는?',              '닭다리',               '닭가슴살'),
  (2,  '떡볶이 속 가장 맛있는 보물은?',                              '떡',                   '어묵'),
  (3,  '내 혀가 감당할 수 있는 매운맛은?',                           '불닭도 거뜬',          '신라면도 매워'),
  (4,  '붕어빵 아저씨 앞에서의 선택은?',                             '팥붕',                 '슈붕'),
  (5,  '고깃집에서 나의 역할은?',                                    '열심히 굽기',          '열심히 먹기'),
  (6,  '배가 터질 것 같은데 친구가 디저트를 먹자고 한다면?',         '디저트 배는 따로 있다', '제발 그만 먹자'),
  (7,  '처음 보는 신기한 메뉴를 발견했다면?',                        '일단 먹어본다',        '검증된 메뉴가 최고'),
  (8,  '탕수육이 배달 왔다! 당신의 선택은?',                         '부먹',                 '찍먹'),
  (9,  '친구가 내 음식 한 입만 달라고 한다면?',                      '얼마든지 먹어',        '한 입의 크기부터 협상'),
  (10, '가장 참을 수 없는 음식의 상태는?',                           '눅눅한 감자튀김',      '탄산 빠진 콜라');

with wanted(name) as (values
  ('마라탕'), ('민트초코'), ('하와이안 피자'),
  ('고수'), ('오이'), ('가지'),
  ('닭발'), ('곱창'), ('선지해장국'),
  ('번데기'), ('홍어'), ('산낙지'),
  ('두리안'), ('콩국수'), ('평양냉면'),
  ('육회'), ('양꼬치'), ('연어'),
  ('탕후루'), ('로제 떡볶이'), ('두바이 초콜릿')
), added as (
  insert into match_foods (name)
  select w.name from wanted w
  on conflict (name) do update set is_active = true
  returning id
)
update match_foods f
set is_active = false
where f.is_active
  and f.name not in (select w.name from wanted w);

commit;
