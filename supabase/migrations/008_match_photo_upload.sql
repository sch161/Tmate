-- =====================================================================
-- 008_match_photo_upload.sql — 궁합 영수증 사진 올리기 (손님 폰 → 진행자 인쇄 화면)
--   표 match_print_requests · match_print_settings 와 RPC 4개(내부 1개)를 추가한다. 기존 데이터는 건드리지 않는다. 재실행해도 안전하다.
--   실행 후 진행자 번호를 한 번 넣는다(저장소에는 두지 않는다): insert into match_print_settings (passcode) values ('원하는 번호 6자 이상');
-- 실행 순서: 007_store_add.sql 까지 적용된 DB 에 이 파일 하나만 실행한다. 실행 후 `npm run gen:types`.
-- =====================================================================
begin;

create table if not exists match_print_requests (
  id            bigint generated always as identity primary key,
  room_id       bigint not null unique references match_rooms (id) on delete cascade,
  requested_by  uuid not null references profiles (id) on delete cascade,
  photo         text not null check (photo like 'data:image/jpeg;base64,%' and char_length(photo) <= 200000),
  created_at    timestamptz not null default now(),
  printed_at    timestamptz
);

-- 진행자 번호(인쇄 화면에서 한 번 입력). 값은 저장소에 두지 않고 DB 에만 넣는다: insert into match_print_settings (passcode) values ('...');
create table if not exists match_print_settings (
  id        boolean primary key default true check (id),
  passcode  text not null check (char_length(passcode) >= 6)
);

alter table match_print_requests enable row level security;
alter table match_print_settings enable row level security;
revoke all on match_print_requests, match_print_settings from anon, authenticated;

-- 내부: 진행자 번호 확인. 틀리면 예외
create or replace function public.calc_match_print_staff(p_passcode text)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception '로그인이 필요합니다.';
  end if;
  if p_passcode is null or not exists (select 1 from public.match_print_settings s where s.passcode = p_passcode) then
    raise exception '진행자 번호가 맞지 않아요.';
  end if;
end;
$$;

-- 손님: 사진과 함께 영수증 인쇄를 요청한다
create or replace function public.request_match_print(p_code text, p_photo text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_room bigint;
begin
  v_room := public.calc_match_room_id(p_code);
  if (select count(*) from public.match_room_members m where m.room_id = v_room and m.completed_at is not null) < 2 then
    raise exception '두 사람 모두 검사를 마쳐야 영수증을 뽑을 수 있어요.';
  end if;
  if p_photo is null or p_photo not like 'data:image/jpeg;base64,%' or char_length(p_photo) > 200000 then
    raise exception '사진을 다시 찍어주세요.';
  end if;

  -- 하루 지난 요청(사진)은 지운다
  delete from public.match_print_requests r where r.created_at < now() - interval '24 hours';

  insert into public.match_print_requests (room_id, requested_by, photo)
  values (v_room, v_uid, p_photo)
  on conflict (room_id)
  do update set requested_by = excluded.requested_by, photo = excluded.photo, created_at = now(), printed_at = null;
end;
$$;

-- 진행자: 인쇄 대기 목록 (사진은 빼고). 아직 안 뽑은 것 먼저, 오래된 순
create or replace function public.get_match_print_queue(p_passcode text)
returns table (
  request_id bigint,
  code text,
  member_no_a smallint,
  member_no_b smallint,
  nickname_a text,
  nickname_b text,
  score int,
  requested_at timestamptz,
  printed_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
begin
  perform public.calc_match_print_staff(p_passcode);

  return query
  select q.id, r.code, a.member_no, b.member_no, pa.nickname, pb.nickname,
         public.calc_match_score(q.room_id, a.user_id, b.user_id), q.created_at, q.printed_at
  from public.match_print_requests q
  join public.match_rooms r on r.id = q.room_id
  join public.match_room_members a on a.room_id = q.room_id and a.completed_at is not null
  join public.match_room_members b on b.room_id = q.room_id and b.completed_at is not null and b.member_no > a.member_no
  join public.profiles pa on pa.id = a.user_id
  join public.profiles pb on pb.id = b.user_id
  where q.created_at > now() - interval '24 hours'
  order by (q.printed_at is not null), q.created_at;
end;
$$;

-- 진행자: 요청 1건의 사진 (data URL)
create or replace function public.get_match_print_photo(p_passcode text, p_request_id bigint)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform public.calc_match_print_staff(p_passcode);
  return (select q.photo from public.match_print_requests q where q.id = p_request_id);
end;
$$;

-- 진행자: 인쇄를 마친 요청으로 표시한다
create or replace function public.mark_match_printed(p_passcode text, p_request_id bigint)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.calc_match_print_staff(p_passcode);
  update public.match_print_requests set printed_at = now() where id = p_request_id;
end;
$$;

revoke all on function public.calc_match_print_staff(text)             from public, anon, authenticated;
revoke all on function public.request_match_print(text, text)          from public, anon;
revoke all on function public.get_match_print_queue(text)              from public, anon;
revoke all on function public.get_match_print_photo(text, bigint)      from public, anon;
revoke all on function public.mark_match_printed(text, bigint)         from public, anon;
grant execute on function public.request_match_print(text, text)       to authenticated;
grant execute on function public.get_match_print_queue(text)           to authenticated;
grant execute on function public.get_match_print_photo(text, bigint)   to authenticated;
grant execute on function public.mark_match_printed(text, bigint)      to authenticated;

commit;
