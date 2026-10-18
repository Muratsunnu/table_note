-- Premium ortak tablo altyapisi:
-- kalici katilim kodu, sunucu tarafli Premium kontrolu, sureli duzenleme
-- kilidi ve iyimser surum kontrolu.

alter table public.cloud_tables
  add column if not exists revision bigint not null default 1
    check (revision > 0),
  add column if not exists collaboration_enabled boolean not null default false,
  add column if not exists join_code_hash bytea;

create unique index if not exists cloud_tables_join_code_hash_idx
  on public.cloud_tables(join_code_hash)
  where join_code_hash is not null;

create table if not exists public.table_edit_locks (
  table_id uuid primary key references public.cloud_tables(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  lease_token uuid not null unique,
  editor_name text not null,
  acquired_at timestamptz not null default now(),
  heartbeat_at timestamptz not null default now(),
  expires_at timestamptz not null
);

create index if not exists table_edit_locks_expires_at_idx
  on public.table_edit_locks(expires_at);

create or replace function public.has_active_premium()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select auth.uid() is not null and exists (
    select 1
    from public.subscriptions
    where user_id = auth.uid()
      and status in ('active', 'trialing', 'grace_period')
      and expires_at > now()
  );
$$;

create or replace function public.can_access_shared_table(target_table_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.cloud_tables table_record
    where table_record.id = target_table_id
      and table_record.collaboration_enabled
      and (
        table_record.owner_id = auth.uid()
        or exists (
          select 1
          from public.table_members member_record
          where member_record.table_id = table_record.id
            and member_record.user_id = auth.uid()
        )
      )
  );
$$;

create or replace function public.can_edit_shared_table(target_table_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.cloud_tables table_record
    where table_record.id = target_table_id
      and table_record.collaboration_enabled
      and (
        table_record.owner_id = auth.uid()
        or exists (
          select 1
          from public.table_members member_record
          where member_record.table_id = table_record.id
            and member_record.user_id = auth.uid()
            and member_record.role = 'editor'
        )
      )
  );
$$;

-- Ortak calisma acikken payload yalnizca kilit ve surum kontrolu yapan RPC ile
-- degistirilebilir. Boylece eski/malicious istemciler kilidi atlayamaz.
create or replace function public.protect_collaborative_table_write()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if tg_op = 'INSERT' then
    if new.collaboration_enabled
       or new.join_code_hash is not null
       or new.revision <> 1 then
      raise exception using message = 'shared_table_rpc_required', errcode = 'P0001';
    end if;
    return new;
  end if;

  if (
    new.collaboration_enabled is distinct from old.collaboration_enabled
    or new.join_code_hash is distinct from old.join_code_hash
    or new.revision is distinct from old.revision
    or (
      old.collaboration_enabled
      and (
        new.name is distinct from old.name
        or new.payload is distinct from old.payload
        or new.schema_version is distinct from old.schema_version
      )
    )
  ) and coalesce(current_setting('app.shared_table_write_id', true), '')
      <> old.id::text then
    raise exception using message = 'shared_table_rpc_required', errcode = 'P0001';
  end if;
  return new;
end;
$$;

drop trigger if exists cloud_tables_protect_collaborative_write
  on public.cloud_tables;
create trigger cloud_tables_protect_collaborative_write
before insert or update on public.cloud_tables
for each row execute function public.protect_collaborative_table_write();

alter table public.table_edit_locks enable row level security;
revoke all on public.table_edit_locks from anon, authenticated;
grant select on public.table_edit_locks to authenticated;

drop policy if exists table_edit_locks_select_members
  on public.table_edit_locks;
create policy table_edit_locks_select_members
on public.table_edit_locks for select to authenticated
using (
  public.has_active_premium()
  and public.can_access_shared_table(table_id)
);

-- Eski tek kullanimlik davetlerle uye olanlar da Premium olmadan ortak tabloyu
-- okuyamaz. Tablo sahibi kendi yedegine erismeye devam eder.
drop policy if exists cloud_tables_select_allowed on public.cloud_tables;
create policy cloud_tables_select_allowed
on public.cloud_tables for select to authenticated
using (
  owner_id = (select auth.uid())
  or (
    public.has_active_premium()
    and public.is_cloud_table_member(id)
  )
);

create or replace function public.rotate_shared_table_join_code(
  target_table_id uuid
)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  plain_code text;
  compact_code text;
begin
  if auth.uid() is null then
    raise exception using message = 'authentication_required', errcode = 'P0001';
  end if;
  if not public.has_active_premium() then
    raise exception using message = 'premium_required', errcode = 'P0001';
  end if;
  if not public.is_cloud_table_owner(target_table_id) then
    raise exception using message = 'table_owner_required', errcode = 'P0001';
  end if;

  perform set_config('app.shared_table_write_id', target_table_id::text, true);
  loop
    compact_code := upper(encode(gen_random_bytes(8), 'hex'));
    plain_code := substring(compact_code, 1, 4) || '-'
      || substring(compact_code, 5, 4) || '-'
      || substring(compact_code, 9, 4) || '-'
      || substring(compact_code, 13, 4);
    begin
      update public.cloud_tables
      set collaboration_enabled = true,
          join_code_hash = digest(compact_code, 'sha256')
      where id = target_table_id;
      exit;
    exception when unique_violation then
      -- Son derece dusuk ihtimalli kod cakismasinda yeni kod uret.
    end;
  end loop;

  return plain_code;
end;
$$;

create or replace function public.disable_shared_table_collaboration(
  target_table_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null then
    raise exception using message = 'authentication_required', errcode = 'P0001';
  end if;
  if not public.is_cloud_table_owner(target_table_id) then
    raise exception using message = 'table_owner_required', errcode = 'P0001';
  end if;

  perform set_config('app.shared_table_write_id', target_table_id::text, true);
  update public.cloud_tables
  set collaboration_enabled = false,
      join_code_hash = null
  where id = target_table_id;
  delete from public.table_edit_locks where table_id = target_table_id;
end;
$$;

create or replace function public.join_shared_table(plain_code text)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  normalized_code text;
  target_table public.cloud_tables%rowtype;
begin
  if auth.uid() is null then
    raise exception using message = 'authentication_required', errcode = 'P0001';
  end if;
  if not public.has_active_premium() then
    raise exception using message = 'premium_required', errcode = 'P0001';
  end if;

  normalized_code := upper(
    regexp_replace(coalesce(plain_code, ''), '[-[:space:]]', '', 'g')
  );
  if length(normalized_code) <> 16
     or normalized_code !~ '^[0-9A-F]{16}$' then
    raise exception using message = 'invalid_table_code', errcode = 'P0001';
  end if;

  select * into target_table
  from public.cloud_tables
  where collaboration_enabled
    and join_code_hash = digest(normalized_code, 'sha256')
  for update;

  if not found then
    raise exception using message = 'invalid_table_code', errcode = 'P0001';
  end if;

  if target_table.owner_id <> auth.uid() then
    insert into public.table_members (table_id, user_id, role)
    values (target_table.id, auth.uid(), 'editor')
    on conflict (table_id, user_id) do update set role = 'editor';
  end if;

  return target_table.id;
end;
$$;

create or replace function public.acquire_shared_table_lock(
  target_table_id uuid,
  requested_lease_seconds integer default 90
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  active_lock public.table_edit_locks%rowtype;
  current_revision bigint;
  new_lease_token uuid := gen_random_uuid();
  lease_seconds integer := least(greatest(coalesce(requested_lease_seconds, 90), 30), 300);
  resolved_editor_name text;
begin
  if auth.uid() is null then
    raise exception using message = 'authentication_required', errcode = 'P0001';
  end if;
  if not public.has_active_premium() then
    raise exception using message = 'premium_required', errcode = 'P0001';
  end if;
  if not public.can_edit_shared_table(target_table_id) then
    raise exception using message = 'shared_table_edit_access_required', errcode = 'P0001';
  end if;

  select revision into current_revision
  from public.cloud_tables
  where id = target_table_id
  for update;

  select coalesce(
    nullif(trim(profile.display_name), ''),
    nullif(split_part(coalesce(auth.jwt() ->> 'email', ''), '@', 1), ''),
    'Kullanici'
  ) into resolved_editor_name
  from (select 1) seed
  left join public.profiles profile on profile.id = auth.uid();

  insert into public.table_edit_locks (
    table_id, user_id, lease_token, editor_name, acquired_at,
    heartbeat_at, expires_at
  ) values (
    target_table_id, auth.uid(), new_lease_token,
    left(resolved_editor_name, 80), now(), now(),
    now() + make_interval(secs => lease_seconds)
  )
  on conflict (table_id) do update
  set user_id = excluded.user_id,
      lease_token = excluded.lease_token,
      editor_name = excluded.editor_name,
      acquired_at = excluded.acquired_at,
      heartbeat_at = excluded.heartbeat_at,
      expires_at = excluded.expires_at
  where public.table_edit_locks.expires_at <= now()
     or public.table_edit_locks.user_id = auth.uid()
  returning * into active_lock;

  if found then
    return jsonb_build_object(
      'acquired', true,
      'lease_token', active_lock.lease_token,
      'editor_user_id', active_lock.user_id,
      'editor_name', active_lock.editor_name,
      'expires_at', active_lock.expires_at,
      'revision', current_revision
    );
  end if;

  select * into active_lock
  from public.table_edit_locks
  where table_id = target_table_id;

  return jsonb_build_object(
    'acquired', false,
    'editor_user_id', active_lock.user_id,
    'editor_name', active_lock.editor_name,
    'expires_at', active_lock.expires_at,
    'revision', current_revision
  );
end;
$$;

create or replace function public.renew_shared_table_lock(
  target_table_id uuid,
  target_lease_token uuid,
  requested_lease_seconds integer default 90
)
returns timestamptz
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  renewed_until timestamptz;
  lease_seconds integer := least(greatest(coalesce(requested_lease_seconds, 90), 30), 300);
begin
  if not public.has_active_premium() then
    raise exception using message = 'premium_required', errcode = 'P0001';
  end if;

  update public.table_edit_locks
  set heartbeat_at = now(),
      expires_at = now() + make_interval(secs => lease_seconds)
  where table_id = target_table_id
    and user_id = auth.uid()
    and lease_token = target_lease_token
    and expires_at > now()
  returning expires_at into renewed_until;

  if not found then
    raise exception using message = 'shared_table_lock_lost', errcode = 'P0001';
  end if;
  return renewed_until;
end;
$$;

create or replace function public.release_shared_table_lock(
  target_table_id uuid,
  target_lease_token uuid
)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  delete from public.table_edit_locks
  where table_id = target_table_id
    and user_id = auth.uid()
    and lease_token = target_lease_token;
  return found;
end;
$$;

create or replace function public.update_shared_table(
  target_table_id uuid,
  target_lease_token uuid,
  expected_revision bigint,
  new_name text,
  new_payload jsonb,
  new_schema_version integer default 2
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_table public.cloud_tables%rowtype;
  next_revision bigint;
  saved_at timestamptz;
begin
  if auth.uid() is null then
    raise exception using message = 'authentication_required', errcode = 'P0001';
  end if;
  if not public.has_active_premium() then
    raise exception using message = 'premium_required', errcode = 'P0001';
  end if;
  if not public.can_edit_shared_table(target_table_id) then
    raise exception using message = 'shared_table_edit_access_required', errcode = 'P0001';
  end if;
  if nullif(trim(new_name), '') is null
     or jsonb_typeof(new_payload) <> 'object'
     or new_schema_version < 1 then
    raise exception using message = 'invalid_shared_table_payload', errcode = 'P0001';
  end if;

  select * into current_table
  from public.cloud_tables
  where id = target_table_id
  for update;

  if current_table.revision <> expected_revision then
    raise exception using message = 'shared_table_revision_conflict', errcode = 'P0001';
  end if;
  if not exists (
    select 1 from public.table_edit_locks
    where table_id = target_table_id
      and user_id = auth.uid()
      and lease_token = target_lease_token
      and expires_at > now()
  ) then
    raise exception using message = 'shared_table_lock_lost', errcode = 'P0001';
  end if;

  perform set_config('app.shared_table_write_id', target_table_id::text, true);
  update public.cloud_tables
  set name = trim(new_name),
      payload = new_payload,
      schema_version = new_schema_version,
      revision = revision + 1
  where id = target_table_id
  returning revision, updated_at into next_revision, saved_at;

  delete from public.table_edit_locks
  where table_id = target_table_id
    and user_id = auth.uid()
    and lease_token = target_lease_token;

  return jsonb_build_object(
    'table_id', target_table_id,
    'revision', next_revision,
    'updated_at', saved_at
  );
end;
$$;

revoke all on function public.has_active_premium() from public;
revoke all on function public.can_access_shared_table(uuid) from public;
revoke all on function public.can_edit_shared_table(uuid) from public;
revoke all on function public.rotate_shared_table_join_code(uuid) from public;
revoke all on function public.disable_shared_table_collaboration(uuid) from public;
revoke all on function public.join_shared_table(text) from public;
revoke all on function public.acquire_shared_table_lock(uuid, integer) from public;
revoke all on function public.renew_shared_table_lock(uuid, uuid, integer) from public;
revoke all on function public.release_shared_table_lock(uuid, uuid) from public;
revoke all on function public.update_shared_table(uuid, uuid, bigint, text, jsonb, integer) from public;

grant execute on function public.has_active_premium() to authenticated;
grant execute on function public.can_access_shared_table(uuid) to authenticated;
grant execute on function public.can_edit_shared_table(uuid) to authenticated;
grant execute on function public.rotate_shared_table_join_code(uuid) to authenticated;
grant execute on function public.disable_shared_table_collaboration(uuid) to authenticated;
grant execute on function public.join_shared_table(text) to authenticated;
grant execute on function public.acquire_shared_table_lock(uuid, integer) to authenticated;
grant execute on function public.renew_shared_table_lock(uuid, uuid, integer) to authenticated;
grant execute on function public.release_shared_table_lock(uuid, uuid) to authenticated;
grant execute on function public.update_shared_table(uuid, uuid, bigint, text, jsonb, integer) to authenticated;

alter table public.table_edit_locks replica identity full;
do $$
begin
  if exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) and not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'table_edit_locks'
  ) then
    alter publication supabase_realtime add table public.table_edit_locks;
  end if;
end;
$$;
