-- =====================================================================
-- 012_match_print_stats.sql — 진행자용 오늘 현황 RPC 1개 추가 (검사를 마친 팀 수, 인쇄 대기·인쇄한 수)
--   테이블·데이터는 건드리지 않는다. create or replace 라 재실행해도 안전하다. functions.sql 의 것과 같다.
-- 실행 순서: 011_match_photo_token.sql 까지 적용된 DB 에 이 파일 하나만 실행한다. 실행 후 `npm run gen:types`.
-- =====================================================================
begin;

-- 진행자: 오늘(최근 24시간) 현황 — 검사를 마친 팀 수, 사진을 올린 팀 중 인쇄 대기·인쇄한 수 (용지·줄을 가늠하는 용도)
create or replace function public.get_match_print_stats(p_passcode text)
returns table (teams int, waiting int, printed int)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform public.calc_match_print_staff(p_passcode);

  return query
  select
    (
      select count(*)::int from (
        select m.room_id
        from public.match_room_members m
        where m.completed_at > now() - interval '24 hours'
        group by m.room_id
        having count(*) >= 2
      ) t
    ),
    (select count(*)::int from public.match_print_requests q where q.created_at > now() - interval '24 hours' and q.printed_at is null),
    (select count(*)::int from public.match_print_requests q where q.created_at > now() - interval '24 hours' and q.printed_at is not null);
end;
$$;

revoke all on function public.get_match_print_stats(text)    from public, anon;
grant execute on function public.get_match_print_stats(text) to authenticated;

commit;
