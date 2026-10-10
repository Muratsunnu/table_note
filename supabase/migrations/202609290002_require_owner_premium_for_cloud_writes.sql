-- Buluta yazmak icin sunucu tarafinda Premium sarti.
--
-- Bugune kadar Premium yalnizca arayuzde kontrol ediliyordu: veritabani,
-- giris yapmis herkesin kendi adina tablo yuklemesine izin veriyordu.
-- Anonim giris acildigi icin kimlik edinmek bedava hale geldi ve bu acik
-- artik ucuz sekilde sömürülebilir.
--
-- Kural sahibe bakar, yazan kisiye degil: ortak tabloya katilan kisi
-- Premium almaz, tablonun yasamasini saglayan sahibin hakkidir.

create or replace function public.require_owner_premium_for_cloud_write()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if public.has_active_premium_user(new.owner_id) then
    return new;
  end if;

  -- Hakki biten kullanicinin mevcut verisi yerinde kalir; yalnizca yeni
  -- yazma durur. Silme bu tetikleyiciye hic ugramaz, cunku insani olan
  -- kullanicinin kendi verisini her zaman kaldirabilmesidir.
  raise exception using message = 'owner_premium_required', errcode = 'P0001';
end;
$$;

drop trigger if exists cloud_tables_require_owner_premium on public.cloud_tables;
create trigger cloud_tables_require_owner_premium
before insert or update on public.cloud_tables
for each row execute function public.require_owner_premium_for_cloud_write();
