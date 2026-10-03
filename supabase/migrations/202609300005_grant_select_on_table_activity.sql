-- table_activity icin eksik tablo izni
--
-- Gunluge yalnizca tablo sahibinin erisebilmesi icin RLS politikasi
-- (table_activity_select_owner) yazilmisti, ama TABLO IZNI verilmemisti.
-- Postgres'te bunlar iki ayri kapidir: once grant bakilir, sonra politika.
-- Grant olmadigi icin sahip bile kendi gunlugunu okuyamiyordu:
--   42501 permission denied for table table_activity
--
-- Canli denemede ortaya cikti. Birim testi bunu yakalayamaz; izinler ve
-- politikalar yalnizca gercek veritabaninda calisir.

grant select on public.table_activity to authenticated;

-- Yazma izni bilerek verilmiyor: gunluge yalnizca log_table_activity
-- (security definer) kayit atar. Boylece istemci sahte kayit ekleyemez,
-- mevcut kaydi degistiremez ve silemez.
revoke insert, update, delete on public.table_activity from authenticated;

-- anon rolu bu tabloya hic dokunmaz. Katilan kisiler de 'authenticated'
-- rolunde calisir (anonim oturum acsalar bile); onlari disarida tutan
-- grant degil, yalnizca sahibi gecen RLS politikasidir.
revoke all on public.table_activity from anon;

-- Deneme kayitlari yalnizca security definer fonksiyonlarin isi; istemci
-- baskasinin deneme sayacini ne okuyabilmeli ne de sifirlayabilmeli.
revoke all on public.share_join_attempts from anon, authenticated;

-- Supabase varsayilan hibelerinden kalan gereksiz yetkiler. Ozellikle
-- TRUNCATE onemli: RLS'i hic dinlemez, yani bu yetki dururken gunlugun
-- tamami tek komutla silinebilirdi. PostgREST bu komutu disari acmiyor,
-- yani ulasilabilir bir acik degil; yine de gunlugun degistirilemez olmasi
-- iddiasiyla celisiyor.
revoke truncate, trigger, references on public.table_activity from authenticated;
