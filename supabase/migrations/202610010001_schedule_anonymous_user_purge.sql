-- Anonim kullanici temizligini zamanla.
--
-- purge_stale_anonymous_users() 202609290001'de yazilmisti ama hicbir yerden
-- cagrilmiyordu; yani yazildigi gunden beri hic calismadi. Kod girip vazgecen
-- her cihaz kalici bir anonim kullanici birakiyor ve aylik aktif kullanici
-- sayisina dahil oluyor.
--
-- Fonksiyon yalnizca su ucunu birden saglayan satirlari siler: anonim olacak,
-- 30 gundur oturum acmamis olacak, hicbir tabloya uye ve hicbir tablonun
-- sahibi olmayacak. Yani erisimi olan kimse silinmez.
--
-- auth.users'a bagli her sey "on delete cascade"; tek istisna
-- table_activity.actor_id, o "set null". Boylece kullanici silinse de
-- degisiklik gecmisi okunur kalir: actor_name kaydin atildigi andaki adi
-- zaten kopyaliyor.

create extension if not exists pg_cron;

-- Betik tekrar calistirilabilsin diye ayni isimli is once kaldirilir.
select cron.unschedule('purge-stale-anonymous-users')
where exists (
  select 1 from cron.job where jobname = 'purge-stale-anonymous-users'
);

-- Her gun 03:20 UTC (Turkiye saatiyle 06:20): kimsenin tablo duzenlemedigi
-- bir saat. Gunluk yeterli, cunku esik 30 gun.
select cron.schedule(
  'purge-stale-anonymous-users',
  '20 3 * * *',
  $job$select public.purge_stale_anonymous_users();$job$
);
