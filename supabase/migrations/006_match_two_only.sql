-- =====================================================================
-- 006_match_two_only.sql — 궁합 검사 방을 2명(둘만의 궁합)으로 제한한다.
--   calc_setting 의 match_room_max 를 6 → 2 로 바꾸고, join_match_room 의 안내 문구를 바꾼다.
--   * 테이블·데이터는 건드리지 않는다. 이미 3명 이상 들어간 방은 그대로 남는다(새로 들어오는 것만 막는다).
--   * create or replace 라 재실행해도 안전하다. 아래 함수는 functions.sql 의 것과 같다.
-- 실행 순서: functions.sql 이 이미 적용된 DB 에 이 파일 하나만 실행한다 (005_taste_auto_adjust.sql 다음).
-- =====================================================================
begin;

create or replace function public.calc_setting(p_key text)
returns numeric
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_value numeric;
begin
  if auth.uid() is null then
    raise exception '로그인이 필요합니다.';
  end if;

  v_value := case p_key
    when 'min_common'         then 3
    when 'mate_similarity'    then 0.7
    when 'collab_min_reviews' then 5
    when 'collab_weight'      then 5
    when 'content_weight'     then 5
    when 'taste_learn_per_review' then 0.07
    when 'taste_learn_max'        then 0.7
    when 'match_room_max'       then 2
    when 'match_food_count'     then 5
    when 'match_room_keep_days' then 7
  end;

  if v_value is null then
    raise exception '알 수 없는 설정 값이에요: %', p_key;
  end if;
  return v_value;
end;
$$;

create or replace function public.join_match_room(p_code text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_room bigint;
  v_members int;
  v_next int;
begin
  if v_uid is null then
    raise exception '로그인이 필요합니다.';
  end if;
  if p_code is null or p_code !~ '^[0-9]{4}$' then
    raise exception '방 번호는 숫자 4자리예요.';
  end if;

  -- 같은 방에 동시에 들어와도 member_no 가 겹치지 않도록 방 행을 잠근다
  select r.id into v_room from public.match_rooms r where r.code = p_code for update;
  if v_room is null then
    raise exception '없는 방 번호예요. 번호를 다시 확인해주세요.';
  end if;
  if exists (select 1 from public.match_room_members m where m.room_id = v_room and m.user_id = v_uid) then
    return;
  end if;

  select count(*), coalesce(max(m.member_no), 0) + 1
  into v_members, v_next
  from public.match_room_members m
  where m.room_id = v_room;
  if v_members >= public.calc_setting('match_room_max') then
    raise exception '이미 두 명이 들어온 방이에요. 새 방을 만들어주세요.';
  end if;

  insert into public.match_room_members (room_id, user_id, member_no) values (v_room, v_uid, v_next);
end;
$$;

commit;
