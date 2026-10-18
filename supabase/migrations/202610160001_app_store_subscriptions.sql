-- Abonelikler App Store'dan da gelir. Canli veritabaninda kisitin adi
-- depodakinden farkli olabilir; platform kisiti adina bakilmadan bulunur.
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
  check (platform in ('google_play', 'app_store'));

-- Sonuc: platform kisitinin yeni hali.
select conname, pg_get_constraintdef(oid) as definition
from pg_constraint
where conrelid = 'public.subscriptions'::regclass
  and contype = 'c';
