-- =====================================================================
-- 004_match_print.sql — 맛궁합 영수증 인쇄(부스 진행자용) RPC 2개를 추가한다.
--   get_match_room_pairs(p_code)                                  : 방 번호로 그 방에서 둘 다 검사를 마친 두 사람 조합과 궁합 점수
--   get_match_pair_foods(p_code, p_member_no_a, p_member_no_b)    : 그 두 사람의 음식별 답 (영수증의 음식 카드용)
--   * 테이블·데이터는 건드리지 않는다. create or replace 라 재실행해도 안전하다.
--   * 기존 궁합 검사 RPC 는 방 멤버만 부를 수 있다. 이 두 함수는 방 멤버가 아닌 진행자가 방 번호로 읽기 위한 것이라 로그인만 확인한다.
--     돌려주는 것은 닉네임·방 안 번호(member_no)·궁합 점수·그 방 음식에 대한 답뿐이다 (사용자 id 는 돌려주지 않는다).
-- 실행 순서: 003_match_test.sql 과 functions.sql(궁합 검사 RPC)이 이미 적용된 DB 에 이 파일 하나만 실행한다.
--   (functions.sql 을 통째로 다시 실행해도 같은 결과다. 두 함수가 functions.sql 에도 들어 있다.)
--   실행 후 `npm run gen:types` 로 src/types/database.types.ts 를 다시 만든다.
-- =====================================================================
begin;

-- 영수증 인쇄(부스 진행자용): 방 번호로 그 방에서 둘 다 검사를 마친 두 사람 조합과 궁합 점수.
--   진행자는 방 멤버가 아니므로 calc_match_room_id(멤버 확인)를 쓰지 않는다. 로그인만 확인한다.
--   돌려주는 것은 닉네임·방 안 번호(member_no)·궁합 점수뿐이다 (get_match_ranking 과 같은 수준).
create or replace function public.get_match_room_pairs(p_code text)
returns table (
  member_no_a smallint,
  member_no_b smallint,
  nickname_a text,
  nickname_b text,
  score int
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_room bigint;
begin
  if auth.uid() is null then
    raise exception '로그인이 필요합니다.';
  end if;
  if p_code is null or p_code !~ '^[0-9]{4}$' then
    raise exception '방 번호는 숫자 4자리예요.';
  end if;

  select r.id into v_room from public.match_rooms r where r.code = p_code;
  if v_room is null then
    raise exception '없는 방 번호예요. 번호를 다시 확인해주세요.';
  end if;

  return query
  select x.member_no_a, x.member_no_b, pa.nickname, pb.nickname, x.score
  from (
    select a.member_no as member_no_a,
           b.member_no as member_no_b,
           a.user_id as user_a,
           b.user_id as user_b,
           public.calc_match_score(v_room, a.user_id, b.user_id) as score
    from public.match_room_members a
    join public.match_room_members b on b.room_id = a.room_id and b.member_no > a.member_no
    where a.room_id = v_room
      and a.completed_at is not null
      and b.completed_at is not null
  ) x
  join public.profiles pa on pa.id = x.user_a
  join public.profiles pb on pb.id = x.user_b
  where x.score is not null
  order by x.member_no_a, x.member_no_b;
end;
$$;

-- 영수증 인쇄(부스 진행자용): 그 방의 음식에 대한 두 사람(p_member_no_a, p_member_no_b)의 답을 나란히 돌려준다.
--   get_match_compare 의 진행자용이다(호출자가 방 멤버가 아니어도 된다). 둘 다 검사를 마쳐야 한다.
create or replace function public.get_match_pair_foods(p_code text, p_member_no_a int, p_member_no_b int)
returns table (
  food_name text,
  a_eaten boolean,
  a_rating smallint,
  a_want_try boolean,
  b_eaten boolean,
  b_rating smallint,
  b_want_try boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_room bigint;
  v_a uuid;
  v_b uuid;
begin
  if auth.uid() is null then
    raise exception '로그인이 필요합니다.';
  end if;
  if p_code is null or p_code !~ '^[0-9]{4}$' then
    raise exception '방 번호는 숫자 4자리예요.';
  end if;

  select r.id into v_room from public.match_rooms r where r.code = p_code;
  if v_room is null then
    raise exception '없는 방 번호예요. 번호를 다시 확인해주세요.';
  end if;

  select m.user_id into v_a
  from public.match_room_members m
  where m.room_id = v_room and m.member_no = p_member_no_a and m.completed_at is not null;
  select m.user_id into v_b
  from public.match_room_members m
  where m.room_id = v_room and m.member_no = p_member_no_b and m.completed_at is not null;
  if v_a is null or v_b is null or v_a = v_b then
    raise exception '두 사람 모두 검사를 마쳐야 결과를 볼 수 있어요.';
  end if;

  return query
  select f.name, a.eaten, a.rating, a.want_try, b.eaten, b.rating, b.want_try
  from public.match_room_foods rf
  join public.match_foods f on f.id = rf.food_id
  join public.match_food_answers a on a.room_id = v_room and a.user_id = v_a and a.food_id = rf.food_id
  join public.match_food_answers b on b.room_id = v_room and b.user_id = v_b and b.food_id = rf.food_id
  where rf.room_id = v_room
  order by rf.sort_order;
end;
$$;

revoke all on function public.get_match_room_pairs(text)                from public, anon;
revoke all on function public.get_match_pair_foods(text, int, int)      from public, anon;
grant execute on function public.get_match_room_pairs(text)             to authenticated;
grant execute on function public.get_match_pair_foods(text, int, int)   to authenticated;

commit;
