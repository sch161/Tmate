-- =====================================================================
-- 010_match_rank_photos.sql — 랭킹 화면에 손님 사진 띄우기 (동의한 사진만)
--   match_print_requests.show_on_rank 컬럼을 추가하고, request_match_print 에 동의 여부 인자를 더한다(인자가 바뀌어 옛 함수는 지우고 다시 만든다).
--   새 RPC get_match_rank_photos. 기존 데이터는 건드리지 않는다. 재실행해도 안전하다.
-- 실행 순서: 009_match_pair_choices.sql 까지 적용된 DB 에 이 파일 하나만 실행한다. 실행 후 `npm run gen:types`.
-- =====================================================================
begin;

alter table match_print_requests add column if not exists show_on_rank boolean not null default false;

drop function if exists public.request_match_print(text, text);
create or replace function public.request_match_print(p_code text, p_photo text, p_show_on_rank boolean default false)
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
  if p_photo is null or left(p_photo, 23) <> 'data:image/jpeg;base64,' then
    raise exception '사진 형식을 읽지 못했어요. 다시 찍어주세요. (형식: %)', left(coalesce(p_photo, '없음'), 30);
  end if;
  if char_length(p_photo) > 200000 then
    raise exception '사진이 너무 커요. 다시 찍어주세요. (%자)', char_length(p_photo);
  end if;

  -- 하루 지난 요청(사진)은 지운다
  delete from public.match_print_requests r where r.created_at < now() - interval '24 hours';

  insert into public.match_print_requests (room_id, requested_by, photo, show_on_rank)
  values (v_room, v_uid, p_photo, coalesce(p_show_on_rank, false))
  on conflict (room_id)
  do update set requested_by = excluded.requested_by, photo = excluded.photo, show_on_rank = excluded.show_on_rank, created_at = now(), printed_at = null;
end;
$$;

create or replace function public.get_match_rank_photos(p_limit int default 6)
returns table (
  request_id bigint,
  nickname_a text,
  nickname_b text,
  score int,
  photo text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
begin
  if auth.uid() is null then
    raise exception '로그인이 필요합니다.';
  end if;

  return query
  select q.id, pa.nickname, pb.nickname, public.calc_match_score(q.room_id, a.user_id, b.user_id), q.photo
  from public.match_print_requests q
  join public.match_room_members a on a.room_id = q.room_id and a.completed_at is not null
  join public.match_room_members b on b.room_id = q.room_id and b.completed_at is not null and b.member_no > a.member_no
  join public.profiles pa on pa.id = a.user_id
  join public.profiles pb on pb.id = b.user_id
  where q.show_on_rank
    and q.created_at > now() - interval '24 hours'
  order by q.created_at desc
  limit least(greatest(coalesce(p_limit, 6), 1), 12);
end;
$$;

revoke all on function public.request_match_print(text, text, boolean) from public, anon;
revoke all on function public.get_match_rank_photos(int)               from public, anon;
grant execute on function public.request_match_print(text, text, boolean) to authenticated;
grant execute on function public.get_match_rank_photos(int)               to authenticated;

commit;
