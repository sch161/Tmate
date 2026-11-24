-- =====================================================================
-- 011_match_photo_token.sql — 다른 폰으로 사진 보내기 (PC 에서 검사한 손님이 화면의 QR 을 폰으로 찍어 사진을 올린다)
--   표 match_photo_tokens 와 RPC 3개(내부 1개)를 추가한다. 기존 데이터는 건드리지 않는다. 재실행해도 안전하다.
--   upload_match_photo_by_token · get_match_photo_token_info 는 로그인하지 않은 폰(anon)도 부를 수 있다 (30분짜리 token 이 권한이다).
-- 실행 순서: 010_match_rank_photos.sql 까지 적용된 DB 에 이 파일 하나만 실행한다. 실행 후 `npm run gen:types`.
-- =====================================================================
begin;

create table if not exists match_photo_tokens (
  token       uuid primary key default gen_random_uuid(),
  room_id     bigint not null references match_rooms (id) on delete cascade,
  created_by  uuid not null references profiles (id) on delete cascade,
  created_at  timestamptz not null default now()
);

alter table match_photo_tokens enable row level security;
revoke all on match_photo_tokens from anon, authenticated;

-- 내부: 유효한 token 이면 방 id, 아니면 예외 (30분 지나면 무효)
create or replace function public.calc_match_photo_token_room(p_token uuid)
returns bigint
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_room bigint;
begin
  select t.room_id into v_room
  from public.match_photo_tokens t
  where t.token = p_token and t.created_at > now() - interval '30 minutes';
  if v_room is null then
    raise exception 'QR 코드가 만료됐어요. 결과 화면에서 QR 을 다시 띄워주세요.';
  end if;
  return v_room;
end;
$$;

create or replace function public.create_match_photo_token(p_code text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_room bigint;
  v_token uuid;
begin
  v_room := public.calc_match_room_id(p_code);
  if (select count(*) from public.match_room_members m where m.room_id = v_room and m.completed_at is not null) < 2 then
    raise exception '두 사람 모두 검사를 마쳐야 사진을 올릴 수 있어요.';
  end if;
  -- 오래된 표는 지운다
  delete from public.match_photo_tokens t where t.created_at < now() - interval '1 day';
  insert into public.match_photo_tokens (room_id, created_by) values (v_room, v_uid) returning token into v_token;
  return v_token;
end;
$$;

create or replace function public.get_match_photo_token_info(p_token uuid)
returns table (nickname_a text, nickname_b text, score int)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_room bigint := public.calc_match_photo_token_room(p_token);
begin
  return query
  select pa.nickname, pb.nickname,
         -- 로그인하지 않은 폰도 부르므로 calc_match_score(로그인 필요) 대신 같은 식을 직접 쓴다: 같은 답을 고른 문항 비율
         (
           select round(100.0 * count(*) filter (where x.choice = y.choice) / nullif(count(*), 0))::int
           from public.match_answers x
           join public.match_answers y on y.room_id = x.room_id and y.question_id = x.question_id and y.user_id = b.user_id
           where x.room_id = v_room and x.user_id = a.user_id
         )
  from public.match_room_members a
  join public.match_room_members b on b.room_id = a.room_id and b.member_no > a.member_no and b.completed_at is not null
  join public.profiles pa on pa.id = a.user_id
  join public.profiles pb on pb.id = b.user_id
  where a.room_id = v_room and a.completed_at is not null
  limit 1;
end;
$$;

create or replace function public.upload_match_photo_by_token(p_token uuid, p_photo text, p_show_on_rank boolean default false)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room bigint := public.calc_match_photo_token_room(p_token);
  v_by uuid;
begin
  if p_photo is null or left(p_photo, 23) <> 'data:image/jpeg;base64,' then
    raise exception '사진 형식을 읽지 못했어요. 다시 찍어주세요. (형식: %)', left(coalesce(p_photo, '없음'), 30);
  end if;
  if char_length(p_photo) > 200000 then
    raise exception '사진이 너무 커요. 다시 찍어주세요. (%자)', char_length(p_photo);
  end if;
  select t.created_by into v_by from public.match_photo_tokens t where t.token = p_token;

  delete from public.match_print_requests r where r.created_at < now() - interval '24 hours';

  insert into public.match_print_requests (room_id, requested_by, photo, show_on_rank)
  values (v_room, v_by, p_photo, coalesce(p_show_on_rank, false))
  on conflict (room_id)
  do update set requested_by = excluded.requested_by, photo = excluded.photo, show_on_rank = excluded.show_on_rank, created_at = now(), printed_at = null;
end;
$$;

revoke all on function public.calc_match_photo_token_room(uuid)                   from public, anon, authenticated;
revoke all on function public.create_match_photo_token(text)                      from public, anon;
revoke all on function public.get_match_photo_token_info(uuid)                    from public;
revoke all on function public.upload_match_photo_by_token(uuid, text, boolean)    from public;
grant execute on function public.create_match_photo_token(text)                   to authenticated;
grant execute on function public.get_match_photo_token_info(uuid)                 to anon, authenticated;
grant execute on function public.upload_match_photo_by_token(uuid, text, boolean) to anon, authenticated;

commit;
