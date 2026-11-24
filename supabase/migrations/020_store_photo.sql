-- =====================================================================
-- 020_store_photo.sql — 내가 추가한 가게에 사진 넣기
--   * Storage 공개 버킷 store-photos 와 올리기 정책(내 폴더에만)을 만든다. 내용은 policies.sql 과 같다.
--   * set_my_store_photo RPC 를 만든다. 본문은 functions.sql 과 같다.
--   * 데이터를 지우지 않는다. 여러 번 실행해도 안전하다.
-- =====================================================================
-- ---------------------------------------------------------------------
-- 가게 사진 버킷 (Storage): 누구나 볼 수 있고, 로그인한 사용자가 자기 폴더(내 id/)에만 올린다
--   600KB 까지, JPEG·PNG 만. 어느 가게의 사진으로 쓸지는 set_my_store_photo 가 확인한다.
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('store-photos', 'store-photos', true, 614400, array['image/jpeg', 'image/png'])
on conflict (id) do update
  set public = excluded.public, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "store_photos_insert_own" on storage.objects;
create policy "store_photos_insert_own" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'store-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);

-- =====================================================================
-- 가게 사진 (내가 추가한 가게)
--   사진 파일은 Storage 의 공개 버킷 store-photos 에 '내 id/가게id-시각.jpg' 로 올린다(권한은 policies.sql).
--   set_my_store_photo 는 내가 추가한 가게인지, 주소가 그 버킷의 내 폴더인지 확인한 뒤 restaurants.image_url 에 적는다.
-- =====================================================================
create or replace function public.set_my_store_photo(p_restaurant_id bigint, p_url text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.calc_my_store_brand(p_restaurant_id);
  if p_url is null or p_url !~ (
    '^https://[a-z0-9]+\.supabase\.co/storage/v1/object/public/store-photos/'
    || auth.uid()::text || '/' || p_restaurant_id::text || '-[0-9]+\.(jpg|png)$'
  ) then
    raise exception '사진 주소가 올바르지 않아요.';
  end if;
  update public.restaurants set image_url = p_url where id = p_restaurant_id;
end;
$$;

revoke all on function public.set_my_store_photo(bigint, text) from public, anon;
grant execute on function public.set_my_store_photo(bigint, text) to authenticated;
