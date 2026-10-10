-- Ortak tablolarda anlik guncelleme.
--
-- Simdiye kadar sunucudaki hal yalnizca tablo acildiginda ve gonderim
-- yanitiyla iniyordu. Karsi taraf tam sen bakarken kaydederse ekraninda
-- eski veri kaliyordu. Bu, satir eklemede gercek bir karisiklik sebebi:
-- diger kisinin ekledigi satiri gormeden kendi satirini ekleyen kullanici
-- ayni sira numarasini uretir.
--
-- Cozumun sunucu tarafi tek satir: cloud_tables'i canli yayina eklemek.
-- Istemci kendi satirina abone olup surum degisince indiriyor.
--
-- Guvenlik tarafinda yeni bir sey yok: canli yayin da RLS'e uyar, yani
-- kullanici zaten SELECT edebildigi satirlarin degisimini gorur.
-- cloud_tables_select_allowed politikasi sahibe ve uyelere aciktir.
--
-- replica identity tam yapilmiyor: varsayilan (birincil anahtar) yeterli,
-- cunku istemciye yalnizca yeni satir lazim, eski hali degil. Tam kimlik
-- her guncellemede eski satirin tamamini da WAL'a yazardi; payload buyuk
-- bir JSON oldugu icin bu iki katı trafik demek olurdu.

do $$
begin
  if exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) and not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'cloud_tables'
  ) then
    alter publication supabase_realtime add table public.cloud_tables;
  end if;
end;
$$;
