-- Kullanicinin kendi hesabini silmesi.
--
-- App Store (5.1.1(v)) ve Google Play, hesap olusturulabilen her uygulamada
-- hesabin uygulama ICINDEN silinebilmesini sart kosuyor. Simdiye kadar
-- yalnizca cikis yapilabiliyordu.
--
-- Istemci auth.users'a dokunamaz; silme icin servis yetkisi gerekir. Bu
-- fonksiyon yalnizca CAGIRANIN kendi satirini siler: kimlik parametre
-- olarak alinmaz, auth.uid()'den okunur, yani baskasinin hesabini silmek
-- icin kullanilamaz.
--
-- Geri kalani yabanci anahtarlar halleder: profiles, cloud_tables (sahibi
-- oldugu tablolar ve onlarin uyelikleri, gunlukleri), table_members
-- (katildigi tablolardaki uyeligi), subscriptions ve deneme kayitlari
-- "on delete cascade" ile gider (canli veritabaninda 2026-10-08'de
-- pg_constraint uzerinden dogrulandi: engelleyen bag yok).
-- table_activity.actor_id ise "set null" olur; baskasinin tablosunda
-- biraktigi kayitlar kalir ama uzerlerindeki ad asagida bosaltilir.
--
-- Bilinen sinir: magaza aboneligi buradan iptal EDILMEZ. Abonelik Apple ya
-- da Google'in elindedir; kullaniciya arayuzde ayrica iptal etmesi
-- soylenir.

create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  target uuid := auth.uid();
begin
  if target is null then
    raise exception using message = 'authentication_required', errcode = 'P0001';
  end if;

  -- Kisinin baskalarinin tablolarinda biraktigi islem kayitlari silinmez:
  -- gunluk tablo sahibine aittir, actor_id de zaten bosa duser. Ama kaydin
  -- uzerindeki ad kisiseldir ve hesapla birlikte gitmelidir. Bos ad,
  -- uygulamada "silinmis hesap" olarak gosterilir.
  update public.table_activity set actor_name = '' where actor_id = target;

  delete from auth.users where id = target;
end;
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

comment on function public.delete_my_account() is
  'Cagiranin kendi hesabini kalici olarak siler. Kimlik parametre olarak
   alinmaz; yalnizca auth.uid() silinir.';
