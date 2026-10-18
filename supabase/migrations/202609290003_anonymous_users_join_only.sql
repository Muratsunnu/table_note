-- Anonim kimlik yalnizca katilmak icindir.
--
-- Panelde anonim girisi acmak, "authenticated" rolunu bedava dagitmak
-- demektir. Supabase bu yuzden captcha oneriyor; captcha ise mobilde
-- hem zahmetli hem kullaniciyi yoruyor. Onun yerine anonim kimligin ne
-- yapabilecegini daraltiyoruz: katilir, duzenler, ama sahip olamaz.
--
-- Boylece biri sinirsiz anonim hesap acsa bile yeni veri yigamaz; sadece
-- kendisine verilmis bir koda katilabilir. Kod + istege bagli sifre + hatali
-- deneme siniri zaten join_shared_table icinde.

create or replace function public.is_anonymous_caller()
returns boolean
language sql
stable
set search_path = public, pg_temp
as $$
  select coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false);
$$;

comment on function public.is_anonymous_caller() is
  'Cagiran kisi kayitsiz (anonim) bir oturum mu kullaniyor.';

-- Sahiplik anonim kimlige kapali. Katilma, duzenleme ve okuma etkilenmez;
-- onlar table_members uzerinden yurur.
drop policy if exists cloud_tables_insert_owner on public.cloud_tables;
create policy cloud_tables_insert_owner
on public.cloud_tables for insert to authenticated
with check (
  owner_id = (select auth.uid())
  and not public.is_anonymous_caller()
);

-- Anonim bir kullanici bir sekilde tablo sahibi olduysa (ornegin bu kural
-- konmadan once), onu guncelleyemesin; silebilsin ki verisini temizleyebilsin.
drop policy if exists cloud_tables_update_owner on public.cloud_tables;
create policy cloud_tables_update_owner
on public.cloud_tables for update to authenticated
using (owner_id = (select auth.uid()))
with check (
  owner_id = (select auth.uid())
  and not public.is_anonymous_caller()
);
