-- pgcrypto bu projede "extensions" semasinda, "public" degil.
--
-- digest / crypt / gen_salt cagiran fonksiyonlarin search_path'i yalnizca
-- "public, pg_temp" oldugu icin bu fonksiyonlar bulunamiyor ve cagri
--   function digest(text, unknown) does not exist
-- diye patliyor. Hata bugune kadar gorulmedi cunku bu yollarin hicbiri
-- uygulamadan cagrilmamisti; katilim ekrani baglanir baglanmaz ortaya cikti.
--
-- Fonksiyonlar imzayla degil, GOVDESINDE pgcrypto cagirmasina bakilarak
-- bulunuyor. Boylece varsayilan parametreli imzalari elle yazmaya calisip
-- yanlis yazma riski kalmiyor ve gozden kacan bir fonksiyon varsa o da
-- kapsama giriyor. Govdelere dokunulmuyor, yalnizca ayar degisiyor.

do $$
declare
  target record;
  touched integer := 0;
begin
  for target in
    select procedure.oid::regprocedure as signature
    from pg_proc procedure
    join pg_namespace space on space.oid = procedure.pronamespace
    where space.nspname = 'public'
      and procedure.prokind = 'f'
      and procedure.prosrc ~ '\m(digest|crypt|gen_salt)\s*\('
  loop
    execute format(
      'alter function %s set search_path = public, extensions, pg_temp',
      target.signature
    );
    touched := touched + 1;
    raise notice 'search_path guncellendi: %', target.signature;
  end loop;

  if touched = 0 then
    raise exception
      'pgcrypto kullanan fonksiyon bulunamadi; migrasyonlar eksik olabilir';
  end if;
  raise notice 'toplam % fonksiyon guncellendi', touched;
end
$$;
