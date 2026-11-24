-- =====================================================================
-- 009_match_pair_choices.sql — 궁합 결과의 "통한 취향 / 갈린 취향"용 RPC 1개를 추가한다 (PART 1 문항별 두 사람의 답).
--   테이블·데이터는 건드리지 않는다. create or replace 라 재실행해도 안전하다. functions.sql 의 것과 같다.
-- 실행 순서: 008_match_photo_upload.sql 까지 적용된 DB 에 이 파일 하나만 실행한다. 실행 후 `npm run gen:types`.
-- =====================================================================
begin;

-- 두 사람(p_member_no_a, p_member_no_b)의 PART 1 문항별 답을 나란히 돌려준다 (결과 화면·영수증의 "통한 취향 / 갈린 취향"용).
--   get_match_pair_foods 와 같은 수준으로 연다: 로그인만 확인하고, 방 번호를 아는 사람이 그 방의 답만 본다. 둘 다 검사를 마쳐야 한다.
create or replace function public.get_match_pair_choices(p_code text, p_member_no_a int, p_member_no_b int)
returns table (
  sort_order smallint,
  body text,
  option_a text,
  option_b text,
  a_choice smallint,
  b_choice smallint
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
  select q.sort_order::smallint, q.body, q.option_a, q.option_b, a.choice, b.choice
  from public.match_questions q
  join public.match_answers a on a.room_id = v_room and a.user_id = v_a and a.question_id = q.id
  join public.match_answers b on b.room_id = v_room and b.user_id = v_b and b.question_id = q.id
  order by q.sort_order;
end;
$$;

revoke all on function public.get_match_pair_choices(text, int, int)    from public, anon;
grant execute on function public.get_match_pair_choices(text, int, int) to authenticated;

commit;
