-- Hediye Premium: mağaza satın alması olmadan elle verilen Premium. Uygulama ve
-- sunucu Premium'u yalnızca subscriptions satırından okuduğu için platformu
-- 'gift' olan, bitişi uzak bir satır her cihazda Premium sayılır. Uygulamada
-- kod girme yeri yoktur; hediye yalnızca SQL Editor'den verilir
-- (supabase/manual_setup/09_grant_gift_premium.sql).
do $$
declare
  existing record;
begin
  for existing in
    select conname
    from pg_constraint
    where conrelid = 'public.subscriptions'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%platform%'
  loop
    execute format('alter table public.subscriptions drop constraint %I', existing.conname);
  end loop;
end $$;

alter table public.subscriptions
  add constraint subscriptions_platform_check
  check (platform in ('google_play', 'app_store', 'gift'));
