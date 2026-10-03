-- SQL Editor kurulumu: sohbetten uygulanan ilk 5 adimdan SONRA calistirin.
-- Canli veritabaninda henuz davranis testi yapilmamistir.
begin;

create or replace function public.can_edit_shared_table(target_table_id uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select auth.uid() is not null and exists (
    select 1 from public.cloud_tables t
    where t.id = target_table_id and t.collaboration_enabled
      and (t.owner_id = auth.uid() or exists (
        select 1 from public.table_members m
        where m.table_id = t.id and m.user_id = auth.uid()
          and m.role = 'editor'
      ))
  );
$$;

-- Dahili yardimci: once tablo satirini kilitler, sonra guncel yetkiyi kontrol eder.
-- Kilit alma, yenileme ve kaydetme ayni kilitleme sirasini kullanir.
-- Bu fonksiyon mobil istemciye acik degildir.
create or replace function public.lock_shared_table_for_edit(target_table_id uuid)
returns public.cloud_tables
language plpgsql security definer
set search_path = ''
as $$
declare
  target public.cloud_tables%rowtype;
begin
  if auth.uid() is null then
    raise exception 'authentication_required';
  end if;
  if not public.has_active_premium() then
    raise exception 'premium_required';
  end if;

  select * into target from public.cloud_tables
  where id = target_table_id for update;

  if not found or not public.can_edit_shared_table(target_table_id) then
    raise exception 'shared_table_edit_access_required';
  end if;
  return target;
end;
$$;

-- Varsayilan kilit 90 saniyedir; istemci 30-300 saniye isteyebilir.
create or replace function public.acquire_shared_table_lock(
  target_table_id uuid,
  requested_lease_seconds integer default 90
)
returns jsonb
language plpgsql security definer
set search_path = ''
as $$
declare
  target public.cloud_tables%rowtype;
  active_lock public.table_edit_locks%rowtype;
  lease_seconds integer := least(greatest(
    coalesce(requested_lease_seconds, 90), 30), 300);
  editor_label text;
  checked_at timestamptz;
begin
  target := public.lock_shared_table_for_edit(target_table_id);
  checked_at := clock_timestamp();

  select * into active_lock from public.table_edit_locks
  where table_id = target_table_id;

  -- Ayni hesabin baska cihazindaki aktif kilidi de devralma.
  if found and active_lock.expires_at > checked_at then
    return jsonb_build_object(
      'acquired', false,
      'editor_user_id', active_lock.user_id,
      'editor_name', active_lock.editor_name,
      'expires_at', active_lock.expires_at,
      'revision', target.revision
    );
  end if;

  select nullif(btrim(display_name), '') into editor_label
  from public.profiles where id = auth.uid();

  insert into public.table_edit_locks (
    table_id, user_id, lease_token, editor_name,
    acquired_at, heartbeat_at, expires_at
  ) values (
    target_table_id, auth.uid(), gen_random_uuid(),
    left(coalesce(editor_label, 'User'), 80),
    checked_at, checked_at,
    checked_at + make_interval(secs => lease_seconds)
  )
  on conflict (table_id) do update set
    user_id = excluded.user_id,
    lease_token = excluded.lease_token,
    editor_name = excluded.editor_name,
    acquired_at = excluded.acquired_at,
    heartbeat_at = excluded.heartbeat_at,
    expires_at = excluded.expires_at
  returning * into active_lock;

  return jsonb_build_object(
    'acquired', true,
    'lease_token', active_lock.lease_token,
    'editor_user_id', active_lock.user_id,
    'editor_name', active_lock.editor_name,
    'expires_at', active_lock.expires_at,
    'revision', target.revision
  );
end;
$$;

-- Duzenleme surerken kilidin suresini uzat.
create or replace function public.renew_shared_table_lock(
  target_table_id uuid,
  target_lease_token uuid,
  requested_lease_seconds integer default 90
)
returns timestamptz
language plpgsql security definer
set search_path = ''
as $$
declare
  lease_seconds integer := least(greatest(
    coalesce(requested_lease_seconds, 90), 30), 300);
  renewed_until timestamptz;
  checked_at timestamptz;
begin
  perform public.lock_shared_table_for_edit(target_table_id);
  checked_at := clock_timestamp();

  update public.table_edit_locks
  set heartbeat_at = checked_at,
      expires_at = checked_at + make_interval(secs => lease_seconds)
  where table_id = target_table_id
    and user_id = auth.uid()
    and lease_token = target_lease_token
    and expires_at > checked_at
  returning expires_at into renewed_until;

  if not found then
    raise exception 'shared_table_lock_lost';
  end if;
  return renewed_until;
end;
$$;

-- Iptal veya ekrandan cikis: sadece kendi kilidini birak.
-- Premium bitmis olsa bile kendi kilidini birakabilir.
create or replace function public.release_shared_table_lock(
  target_table_id uuid,
  target_lease_token uuid
)
returns boolean
language plpgsql security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'authentication_required';
  end if;

  perform 1 from public.cloud_tables
  where id = target_table_id for update;

  delete from public.table_edit_locks
  where table_id = target_table_id
    and user_id = auth.uid()
    and lease_token = target_lease_token;
  return found;
end;
$$;

-- Kaydetme: Premium + uyelik + aktif kilit + surum birlikte kontrol edilir.
create or replace function public.update_shared_table(
  target_table_id uuid,
  target_lease_token uuid,
  expected_revision bigint,
  new_name text,
  new_payload jsonb,
  new_schema_version integer default 2
)
returns jsonb
language plpgsql security definer
set search_path = ''
as $$
declare
  target public.cloud_tables%rowtype;
  next_revision bigint;
  saved_at timestamptz;
begin
  target := public.lock_shared_table_for_edit(target_table_id);

  if nullif(btrim(new_name), '') is null
    or jsonb_typeof(new_payload) is distinct from 'object'
    or new_schema_version is null or new_schema_version < 1 then
    raise exception 'invalid_shared_table_payload';
  end if;

  if expected_revision is null
    or target.revision is distinct from expected_revision then
    raise exception 'shared_table_revision_conflict';
  end if;

  if not exists (
    select 1 from public.table_edit_locks
    where table_id = target_table_id
      and user_id = auth.uid()
      and lease_token = target_lease_token
      and expires_at > clock_timestamp()
  ) then
    raise exception 'shared_table_lock_lost';
  end if;

  update public.cloud_tables
  set name = btrim(new_name), payload = new_payload,
      schema_version = new_schema_version, revision = revision + 1
  where id = target_table_id
  returning revision, updated_at into next_revision, saved_at;

  delete from public.table_edit_locks
  where table_id = target_table_id
    and user_id = auth.uid() and lease_token = target_lease_token;

  return jsonb_build_object(
    'table_id', target_table_id,
    'revision', next_revision,
    'updated_at', saved_at
  );
end;
$$;

revoke all on function public.can_edit_shared_table(uuid)
  from public, anon, authenticated;
revoke all on function public.lock_shared_table_for_edit(uuid)
  from public, anon, authenticated;
revoke all on function public.acquire_shared_table_lock(uuid, integer)
  from public, anon, authenticated;
revoke all on function public.renew_shared_table_lock(uuid, uuid, integer)
  from public, anon, authenticated;
revoke all on function public.release_shared_table_lock(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.update_shared_table(uuid, uuid, bigint, text, jsonb, integer)
  from public, anon, authenticated;

grant execute on function public.can_edit_shared_table(uuid) to authenticated;
grant execute on function public.acquire_shared_table_lock(uuid, integer) to authenticated;
grant execute on function public.renew_shared_table_lock(uuid, uuid, integer) to authenticated;
grant execute on function public.release_shared_table_lock(uuid, uuid) to authenticated;
grant execute on function public.update_shared_table(uuid, uuid, bigint, text, jsonb, integer)
  to authenticated;

-- lock_shared_table_for_edit dahili kalir: istemciye EXECUTE verilmez.
commit;
