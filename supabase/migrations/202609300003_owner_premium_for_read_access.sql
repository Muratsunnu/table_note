-- Okuma yetkisinde Premium sarti SAHIBE bakar, cagirana degil.
--
-- Ortak calisma altyapisi, katilan kisinin de abone oldugu varsayimiyla
-- yazilmisti. Artik katilan hicbir sey odemiyor. Bu degisiklik RPC'lerde
-- yapilmisti ama okuma politikasi atlanmisti.
--
-- Atlanan politikanin sonucu agirdi: katilan kisi katildigi tabloyu
-- OKUYAMIYORDU. Kod dogru, uyelik olusuyor, ama tablo indirilemiyordu.
-- Canli denemede ortaya cikti; hicbir birim testi bunu yakalayamazdi,
-- cunku RLS yalnizca gercek veritabaninda calisir.
--
-- Uyelik kontrolu can_access_shared_table ile yapiliyor: bu fonksiyon
-- security definer oldugu icin table_members'in kendi politikasini
-- tetiklemez. Uyelik sorgusunu buraya acmak, iki politikanin birbirini
-- cagirmasina ve ozyinelemeye yol acardi.

drop policy if exists cloud_tables_select_allowed on public.cloud_tables;
create policy cloud_tables_select_allowed
on public.cloud_tables for select to authenticated
using (
  owner_id = (select auth.uid())
  or (
    public.can_access_shared_table(id)
    -- Tablo, sahibinin aboneligi surdugu surece okunabilir.
    and public.has_active_premium_user(owner_id)
  )
);

-- Not: acquire_shared_table_lock ve renew_shared_table_lock hala cagiranin
-- Premium'una bakiyor. Bunlar yalnizca eski "tek parca gonderim" yolunda
-- kullaniliyor; satir bazli senkron kilit almiyor. Sahip tarafi arayuzu
-- yazilip o yol gercekten denenene kadar govdeleri yeniden yazmak, calisan
-- ama kullanilmayan kodu korumasiz degistirmek olurdu.
