-- Kullanilmayan kilit RPC'lerinin istemci erisimini kapat.
--
-- Ortak calisma once "tabloyu kilitle, tamamini gonder, kilidi birak"
-- seklinde tasarlanmisti. Satir bazli senkron bunun yerini aldi ve istemci
-- tarafi kaldirildi, ama RPC'ler authenticated rolune acik kaldi.
--
-- Acik kalmasinin somut bedeli var: kendi aboneligi olan ve tabloda
-- duzenleme yetkisi bulunan biri acquire_shared_table_lock'u dogrudan
-- cagirip 300 saniyelik kilit koyabilir, renew ile de sinirsiz uzatabilir.
-- O kilit dururken apply_shared_table_rows HERKESI reddeder
-- (shared_table_locked_by_other) -- tablonun sahibi dahil. Uygulamada bu
-- kilidi gosteren ya da kaldiran bir ekran yok; sahibin tek caresi
-- paylasimi kapatmak olurdu.
--
-- Tabloyu ve fonksiyonlari dusurmek yerine yalnizca erisim kapatiliyor.
-- Dusurmek, apply_shared_table_rows ile
-- disable_shared_table_collaboration'i yeniden yazmayi gerektirir; yani
-- canli olarak dogrulanmis senkron akisina dokunmayi. Kazanc ise ayni:
-- cagrilamayan bir fonksiyon zarar veremez.
--
-- Imzalar adla bulunuyor, elle yazilmiyor: canli veritabani depodaki
-- migrationlardan uretilmedigi icin arguman listeleri farkli olabilir.

do $$
declare
  fn record;
begin
  for fn in
    select p.oid::regprocedure as signature
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in (
        'acquire_shared_table_lock',
        'renew_shared_table_lock',
        'release_shared_table_lock',
        'lock_shared_table_for_edit'
      )
  loop
    execute format('revoke all on function %s from anon, authenticated', fn.signature);
    raise notice 'istemci erisimi kaldirildi: %', fn.signature;
  end loop;
end $$;

-- Kilit satirlarini okuyan istemci kodu da kaldirildi (watchSharedTableLock).
revoke all on public.table_edit_locks from anon, authenticated;

-- Birakilmis kilit satiri kalmis olabilir. Icerikleri geciciydi ve artik
-- kimse yenisini olusturamaz; yine de veri silmek bu betigin isi degil,
-- yalnizca gosteriliyor.
select table_id, user_id, editor_name, expires_at
from public.table_edit_locks
order by expires_at desc;
