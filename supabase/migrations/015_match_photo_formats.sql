-- =====================================================================
-- 015_match_photo_formats.sql — 영수증 사진을 PNG·WebP 로도 받는다 (JPEG 로 내보내지 못하는 브라우저 대응), 길이 한도 400,000자
--   match_print_requests.photo 의 검사 조건을 바꾸고, 사진을 받는 RPC 2개를 갱신한다. 데이터는 건드리지 않는다. 재실행해도 안전하다.
-- 실행 순서: 014_match_pair_places.sql 까지 적용된 DB 에 이 파일 하나만 실행한다.
-- =====================================================================
begin;

alter table match_print_requests drop constraint if exists match_print_requests_photo_check;
alter table match_print_requests add constraint match_print_requests_photo_check check (photo ~ '^data:image/(jpeg|png|webp);base64,' and char_length(photo) <= 400000);

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
  if p_photo is null or p_photo !~ '^data:image/(jpeg|png|webp);base64,' then
    raise exception '사진 형식을 읽지 못했어요. 다시 찍어주세요. (형식: %)', left(coalesce(p_photo, '없음'), 30);
  end if;
  if char_length(p_photo) > 400000 then
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
  if p_photo is null or p_photo !~ '^data:image/(jpeg|png|webp);base64,' then
    raise exception '사진 형식을 읽지 못했어요. 다시 찍어주세요. (형식: %)', left(coalesce(p_photo, '없음'), 30);
  end if;
  if char_length(p_photo) > 400000 then
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

commit;
