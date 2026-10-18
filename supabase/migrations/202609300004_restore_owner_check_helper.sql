-- Eksik sahiplik yardimcisi: public.is_cloud_table_owner
--
-- Canli veritabani, depodaki ilk semadan (202609010001) farkli kurulmus.
-- O semada tanimli is_cloud_table_owner canliya hic gitmemis. Sorun bugune
-- kadar gorunmedi, cunku plpgsql govdeleri olusturulurken degil
-- CALISTIRILIRKEN cozulur: rotate_shared_table_join_code sorunsuz olustu,
-- ilk kez uygulamadan "Paylasimi baslat" butonuna basildiginda
-- 42883 (function does not exist) ile dustu.
--
-- Fonksiyonu yerinde tanimlamak yerine yardimciyi geri getiriyorum, cunku
-- eksik olan yardimcinin kendisi; depodaki baska govdeler de onu cagiriyor
-- (ornegin disable_shared_table_collaboration). Tek tek govde yamalamak
-- ayni hatayi bir sonraki butonda tekrar yasatirdi.
--
-- create or replace oldugu icin yardimci zaten varsa bu betik bir sey
-- degistirmez; mevcut politikalar ve veriler etkilenmez.

create or replace function public.is_cloud_table_owner(target_table_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.cloud_tables
    where id = target_table_id and owner_id = auth.uid()
  );
$$;

revoke all on function public.is_cloud_table_owner(uuid) from public;
grant execute on function public.is_cloud_table_owner(uuid) to authenticated;

comment on function public.is_cloud_table_owner(uuid) is
  'Cagiran kisi bu bulut tablosunun sahibi mi? security definer oldugu icin '
  'cloud_tables politikalarini tetiklemez, boylece politika icinden '
  'cagrildiginda ozyinelemeye yol acmaz.';
