-- Kullanilmayan davet yolunun istemci erisimini kapat.
--
-- Paylasim once "7 gun gecerli tek kullanimlik davet" olarak yazilmisti.
-- Yerini kalici 6 haneli kod aldi (join_shared_table); istemci tarafi
-- kaldirildi ama RPC'ler authenticated rolune acik kaldi.
--
-- Kilit yolundaki kadar ciddi degil: en kotu ihtimalle biri kendi tablosu
-- icin eski tip bir davet uretir, baskasinin verisine erisemez. Yine de
-- cagrilmayan bir yolun acik durmasi icin sebep yok.
--
-- Fonksiyonlar ve tablo dusurulmuyor, yalnizca erisim kapatiliyor; ayni
-- gerekce kilit yolundaki gibi: calisan hicbir govdeyi yeniden yazmadan
-- ayni kazanc elde ediliyor. Bos kabuklar yayindan sonra sakin bir
-- zamanda dusurulur.
--
-- Imzalar pg_proc'tan adla bulunuyor: canli veritabani depodaki
-- migrationlardan uretilemedigi icin arguman listeleri farkli olabilir.

do $$
declare
  fn record;
begin
  for fn in
    select p.oid::regprocedure as signature
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('create_share_invite', 'claim_share_invite')
  loop
    execute format('revoke all on function %s from anon, authenticated', fn.signature);
    raise notice 'istemci erisimi kaldirildi: %', fn.signature;
  end loop;
end $$;

-- Davet satirlarini istemci dogrudan okuyup yazabiliyordu; artik
-- okumasina da yazmasina da gerek yok.
revoke all on public.share_invites from anon, authenticated;
