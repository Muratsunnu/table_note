-- Katilanlar icin rol: goruntuleyen / duzenleyen.
--
-- Bugune kadar kodla katilan herkes duzenleyebiliyordu. table_members.role
-- sutunu ve yazma fonksiyonlarindaki denetim (can_edit_shared_table) zaten
-- vardi, ama katilim herkesi 'editor' yaptigi icin ayrim hic kullanilmiyordu;
-- rolu degistirmenin ya da duzenleme yetkisi istemenin de bir yolu yoktu.
--
-- Bu dosyadan sonra:
--   * Yeni katilan kisi 'viewer' olur: tabloyu gorur, degistiremez.
--   * Rolu yalnizca tablo sahibi degistirir (set_shared_member_role).
--   * Goruntuleyen kisi duzenleme yetkisi isteyebilir
--     (request_shared_edit_access); sahip onaylar ya da reddeder.
--   * Simdiye kadar katilmis olanlar duzenleyen olarak KALIR. Elinde olan
--     yetkiyi kimse bu degisiklik yuzunden kaybetmez.

-- ---------------------------------------------------------------------------
-- 1. Talep durumu
-- ---------------------------------------------------------------------------

alter table public.table_members
  add column if not exists edit_requested_at timestamptz,
  add column if not exists edit_request_open boolean not null default false;

comment on column public.table_members.edit_requested_at is
  'Son duzenleme yetkisi talebinin zamani. Talep kapansa da durur; ayni
   kisinin pes pese talep gondermesini sinirlamak icin kullanilir.';
comment on column public.table_members.edit_request_open is
  'Sahibin yanitini bekleyen bir talep var mi.';

-- ---------------------------------------------------------------------------
-- 2. Rol ve talep alanlari yalnizca asagidaki fonksiyonlardan degisir
-- ---------------------------------------------------------------------------

-- Katilim fonksiyonu satiri 'editor' diye yazar, yeniden katilan kisiyi de
-- 'editor' yapar. O buyuk fonksiyonu yeniden tanimlamak yerine kurali burada
-- koyuyoruz: bu alanlara kim, hangi yoldan yazarsa yazsin, izinli fonksiyon
-- disinda yeni uye 'viewer' olur ve mevcut uyenin rolu degismez. Boylece
-- ileride eklenecek bir yazma yolu da kurali sessizce delemez.
create or replace function public.guard_table_member_role()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if coalesce(current_setting('app.member_role_write', true), '') = 'on' then
    return new;
  end if;

  if tg_op = 'INSERT' then
    new.role := 'viewer';
    new.edit_requested_at := null;
    new.edit_request_open := false;
  else
    new.role := old.role;
    new.edit_requested_at := old.edit_requested_at;
    new.edit_request_open := old.edit_request_open;
  end if;
  return new;
end;
$$;

drop trigger if exists table_members_guard_role on public.table_members;
create trigger table_members_guard_role
before insert or update on public.table_members
for each row execute function public.guard_table_member_role();

-- ---------------------------------------------------------------------------
-- 3. Degisikligi acik ekranlara duyurmak
-- ---------------------------------------------------------------------------

-- Acik ekranlar cloud_tables satirinin surumunu canli izliyor. Rol ya da
-- talep degistiginde surum bir artirilir; herkes kendi yetkisini yeniden
-- sorar. Satirlar ve sutunlar degismez.
create or replace function public.touch_shared_table(target_table_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  perform set_config('app.shared_table_write_id', target_table_id::text, true);
  update public.cloud_tables
  set revision = revision + 1
  where id = target_table_id;
end;
$$;
revoke all on function public.touch_shared_table(uuid)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 4. Islem gecmisine iki yeni kayit turu
-- ---------------------------------------------------------------------------

alter table public.table_activity
  drop constraint if exists table_activity_action_check;
alter table public.table_activity
  add constraint table_activity_action_check check (
    action in (
      'joined', 'left',
      'row_added', 'row_updated', 'row_deleted',
      'table_replaced', 'columns_changed',
      'item_added', 'item_renamed', 'item_deleted', 'mark_changed',
      'role_changed', 'edit_requested'
    )
  );

-- ---------------------------------------------------------------------------
-- 5. Sahip rol verir (ya da talebi reddeder)
-- ---------------------------------------------------------------------------

-- Ayni rolu yeniden vermek acik talebi kapatir; "reddet" budur.
create or replace function public.set_shared_member_role(
  target_table_id uuid,
  member_user_id uuid,
  new_role text
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  previous_role text;
  member_name text;
begin
  if auth.uid() is null then
    raise exception using message = 'authentication_required', errcode = 'P0001';
  end if;
  if not public.is_cloud_table_owner(target_table_id) then
    raise exception using message = 'table_owner_required', errcode = 'P0001';
  end if;
  if new_role is null or new_role not in ('viewer', 'editor') then
    raise exception using message = 'invalid_member_role', errcode = 'P0001';
  end if;

  select member.role, member.display_name
    into previous_role, member_name
  from public.table_members member
  where member.table_id = target_table_id
    and member.user_id = member_user_id
  for update;

  if not found then
    raise exception using message = 'member_not_found', errcode = 'P0001';
  end if;

  perform set_config('app.member_role_write', 'on', true);
  update public.table_members
  set role = new_role,
      edit_request_open = false
  where table_id = target_table_id
    and user_id = member_user_id;
  perform set_config('app.member_role_write', 'off', true);

  if previous_role is distinct from new_role then
    perform public.log_table_activity(
      target_table_id, 'role_changed', null,
      coalesce(member_name, ''), previous_role, new_role
    );
  end if;

  perform public.touch_shared_table(target_table_id);
end;
$$;
revoke all on function public.set_shared_member_role(uuid, uuid, text)
  from public, anon;
grant execute on function public.set_shared_member_role(uuid, uuid, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 6. Goruntuleyen kisi duzenleme yetkisi ister
-- ---------------------------------------------------------------------------

create or replace function public.request_shared_edit_access(
  target_table_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  member public.table_members%rowtype;
begin
  if auth.uid() is null then
    raise exception using message = 'authentication_required', errcode = 'P0001';
  end if;

  select * into member
  from public.table_members
  where table_id = target_table_id
    and user_id = auth.uid()
  for update;

  if not found then
    raise exception using message = 'table_not_found', errcode = 'P0001';
  end if;

  -- Zaten duzenleyebiliyorsa ya da talebi bekliyorsa yapilacak bir sey yok.
  if member.role = 'editor' then
    return jsonb_build_object(
      'role', 'editor', 'editRequested', false, 'pendingRequests', 0
    );
  end if;
  if member.edit_request_open then
    return jsonb_build_object(
      'role', 'viewer', 'editRequested', true, 'pendingRequests', 0
    );
  end if;

  -- Reddedilen kisi ayni talebi pes pese gonderip sahibi rahatsiz etmesin.
  if member.edit_requested_at is not null
     and member.edit_requested_at > now() - interval '10 minutes' then
    raise exception using message = 'too_many_attempts', errcode = 'P0001';
  end if;

  perform set_config('app.member_role_write', 'on', true);
  update public.table_members
  set edit_requested_at = now(),
      edit_request_open = true
  where table_id = target_table_id
    and user_id = auth.uid();
  perform set_config('app.member_role_write', 'off', true);

  perform public.log_table_activity(target_table_id, 'edit_requested');
  perform public.touch_shared_table(target_table_id);

  return jsonb_build_object(
    'role', 'viewer', 'editRequested', true, 'pendingRequests', 0
  );
end;
$$;
revoke all on function public.request_shared_edit_access(uuid)
  from public, anon;
grant execute on function public.request_shared_edit_access(uuid)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 7. Herkes kendi yetkisini sorar
-- ---------------------------------------------------------------------------

-- Sahip icin bekleyen talep sayisini da doner; arayuzdeki rozet bundan gelir.
create or replace function public.shared_table_access(target_table_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  member public.table_members%rowtype;
begin
  if auth.uid() is null then
    raise exception using message = 'authentication_required', errcode = 'P0001';
  end if;

  if public.is_cloud_table_owner(target_table_id) then
    return jsonb_build_object(
      'role', 'owner',
      'editRequested', false,
      'pendingRequests', (
        select count(*)
        from public.table_members
        where table_id = target_table_id
          and edit_request_open
      )
    );
  end if;

  select * into member
  from public.table_members
  where table_id = target_table_id
    and user_id = auth.uid();

  if not found then
    return jsonb_build_object(
      'role', null, 'editRequested', false, 'pendingRequests', 0
    );
  end if;

  return jsonb_build_object(
    'role', member.role,
    'editRequested', member.edit_request_open,
    'pendingRequests', 0
  );
end;
$$;
revoke all on function public.shared_table_access(uuid) from public, anon;
grant execute on function public.shared_table_access(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 8. Sahip icin uye listesi: rol ve talep ile
-- ---------------------------------------------------------------------------

-- shared_table_members'in donus tipi degistirilemedigi icin (Postgres buna
-- "create or replace" ile izin vermez) yeni bir ad. Eskisi yerinde durur.
create or replace function public.shared_table_member_roles(
  target_table_id uuid
)
returns table (
  user_id uuid,
  display_name text,
  role text,
  joined_at timestamptz,
  edit_request_open boolean,
  edit_requested_at timestamptz
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select member.user_id, member.display_name, member.role, member.created_at,
         member.edit_request_open, member.edit_requested_at
  from public.table_members member
  join public.cloud_tables owner_table on owner_table.id = member.table_id
  where member.table_id = target_table_id
    and owner_table.owner_id = auth.uid()
  -- Yanit bekleyenler ustte.
  order by member.edit_request_open desc, member.created_at;
$$;
revoke all on function public.shared_table_member_roles(uuid)
  from public, anon;
grant execute on function public.shared_table_member_roles(uuid)
  to authenticated;
