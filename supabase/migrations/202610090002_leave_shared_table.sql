-- Katilinan tablodan ayrilma.
--
-- Kodla katilan kisinin cikabilecegi bir yol yoktu. Tabloyu kendi cihazindan
-- silebiliyordu ama uyeligi sunucuda kaliyordu: sahibin listesinde gorunmeye
-- devam ediyor, tabloya erisimi suruyor, o tabloda kullandigi adi da baska
-- kimse alamiyordu.
--
-- Kisi yalnizca KENDI uyeligini siler; kimlik parametre olarak alinmaz.
-- Sahip ayrilamaz: onun yolu paylasimi kapatmaktir.

create or replace function public.leave_shared_table(target_table_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  is_member boolean;
begin
  if auth.uid() is null then
    raise exception using message = 'authentication_required', errcode = 'P0001';
  end if;
  if public.is_cloud_table_owner(target_table_id) then
    raise exception using message = 'table_owner_cannot_leave', errcode = 'P0001';
  end if;

  select exists (
    select 1
    from public.table_members
    where table_id = target_table_id
      and user_id = auth.uid()
  ) into is_member;

  -- Zaten uye degilse (sahip paylasimi kapatmis, tablo silinmis ya da daha
  -- once ayrilinmis) yapilacak bir sey yok; hata vermek kisiyi cihazindaki
  -- kopyadan kurtulamaz halde birakirdi.
  if not is_member then
    return;
  end if;

  -- Kayit, uyelik silinmeden once atilir: gecmisteki ad uyelik satirindan
  -- okunuyor.
  perform public.log_table_activity(target_table_id, 'left');

  delete from public.table_members
  where table_id = target_table_id
    and user_id = auth.uid();

  -- Sahibin acik ekrani uye listesini ve bekleyen talep sayisini tazelesin.
  -- Duyuru basarisiz olsa da (ornegin sahibin aboneligi bitmisse) ayrilma
  -- gecerlidir: kisi her zaman cikabilmeli.
  begin
    perform public.touch_shared_table(target_table_id);
  exception when others then
    null;
  end;
end;
$$;
revoke all on function public.leave_shared_table(uuid) from public, anon;
grant execute on function public.leave_shared_table(uuid) to authenticated;

comment on function public.leave_shared_table(uuid) is
  'Cagiranin bu tablodaki uyeligini siler. Yalnizca kendi uyeligi; sahip
   icin hata verir.';
