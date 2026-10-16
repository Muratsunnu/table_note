-- Gunluge cetele eylemleri de yazilabilsin.
--
-- table_activity.action bir CHECK kisitiyla sinirli ve liste yalnizca tablo
-- eylemlerini tanıyordu. Cetele senkronu ilk denemede bu yuzden dustu:
--   new row for relation "table_activity" violates check constraint
--   "table_activity_action_check"
--
-- Hatanin sinsi yani sunucu fonksiyonunun kendisinin kusursuz calismasiydi;
-- islem son anda, gunluge yazarken geri alindi. Yani cetele degisikligi
-- buluta hic ulasmiyordu ve sebebi senkron kodunda degil, bir yil once
-- yazilmis bir kisitta duruyordu.
--
-- Liste daraltilmiyor, yalnizca genisletiliyor: mevcut kayitlarin hepsi
-- gecerli kalir.

alter table public.table_activity
  drop constraint if exists table_activity_action_check;

alter table public.table_activity
  add constraint table_activity_action_check check (
    action in (
      -- Tablo
      'joined', 'left', 'row_added', 'row_updated', 'row_deleted',
      'table_replaced', 'columns_changed',
      -- Cetele
      'item_added', 'item_renamed', 'item_deleted', 'mark_changed'
    )
  );
