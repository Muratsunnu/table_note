create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.cloud_tables (
  id uuid primary key,
  owner_id uuid not null references auth.users(id) on delete cascade,
  table_kind text not null check (table_kind in ('table', 'tally')),
  name text not null,
  payload jsonb not null,
  schema_version integer not null default 2 check (schema_version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.table_members (
  table_id uuid not null references public.cloud_tables(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'viewer' check (role in ('viewer', 'editor')),
  created_at timestamptz not null default now(),
  primary key (table_id, user_id)
);

create table if not exists public.share_invites (
  id uuid primary key default gen_random_uuid(),
  table_id uuid not null references public.cloud_tables(id) on delete cascade,
  created_by uuid not null references auth.users(id) on delete cascade,
  token_hash bytea not null unique,
  role text not null default 'viewer' check (role in ('viewer', 'editor')),
  expires_at timestamptz not null,
  max_uses integer not null default 1 check (max_uses > 0),
  use_count integer not null default 0 check (use_count >= 0),
  created_at timestamptz not null default now()
);

create index if not exists cloud_tables_owner_id_idx
  on public.cloud_tables(owner_id);
create index if not exists table_members_user_id_idx
  on public.table_members(user_id);
create index if not exists share_invites_table_id_idx
  on public.share_invites(table_id);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

drop trigger if exists cloud_tables_set_updated_at on public.cloud_tables;
create trigger cloud_tables_set_updated_at
before update on public.cloud_tables
for each row execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', new.email))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

create or replace function public.is_cloud_table_owner(target_table_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.cloud_tables
    where id = target_table_id and owner_id = auth.uid()
  );
$$;

create or replace function public.is_cloud_table_member(target_table_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.table_members
    where table_id = target_table_id and user_id = auth.uid()
  );
$$;

alter table public.profiles enable row level security;
alter table public.cloud_tables enable row level security;
alter table public.table_members enable row level security;
alter table public.share_invites enable row level security;

revoke all on public.profiles from anon, authenticated;
revoke all on public.cloud_tables from anon, authenticated;
revoke all on public.table_members from anon, authenticated;
revoke all on public.share_invites from anon, authenticated;

grant select, update on public.profiles to authenticated;
grant select, insert, update, delete on public.cloud_tables to authenticated;
grant select, insert, update, delete on public.table_members to authenticated;
grant select, insert, delete on public.share_invites to authenticated;

drop policy if exists profiles_select_self on public.profiles;
create policy profiles_select_self
on public.profiles for select to authenticated
using ((select auth.uid()) = id);

drop policy if exists profiles_update_self on public.profiles;
create policy profiles_update_self
on public.profiles for update to authenticated
using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);

drop policy if exists cloud_tables_select_allowed on public.cloud_tables;
create policy cloud_tables_select_allowed
on public.cloud_tables for select to authenticated
using (
  owner_id = (select auth.uid())
  or public.is_cloud_table_member(id)
);

drop policy if exists cloud_tables_insert_owner on public.cloud_tables;
create policy cloud_tables_insert_owner
on public.cloud_tables for insert to authenticated
with check (owner_id = (select auth.uid()));

drop policy if exists cloud_tables_update_owner on public.cloud_tables;
create policy cloud_tables_update_owner
on public.cloud_tables for update to authenticated
using (owner_id = (select auth.uid()))
with check (owner_id = (select auth.uid()));

drop policy if exists cloud_tables_delete_owner on public.cloud_tables;
create policy cloud_tables_delete_owner
on public.cloud_tables for delete to authenticated
using (owner_id = (select auth.uid()));

drop policy if exists table_members_select_allowed on public.table_members;
create policy table_members_select_allowed
on public.table_members for select to authenticated
using (
  user_id = (select auth.uid())
  or public.is_cloud_table_owner(table_id)
);

drop policy if exists table_members_manage_owner on public.table_members;
create policy table_members_manage_owner
on public.table_members for all to authenticated
using (public.is_cloud_table_owner(table_id))
with check (public.is_cloud_table_owner(table_id));

drop policy if exists share_invites_manage_owner on public.share_invites;
create policy share_invites_manage_owner
on public.share_invites for all to authenticated
using (public.is_cloud_table_owner(table_id))
with check (
  public.is_cloud_table_owner(table_id)
  and created_by = (select auth.uid())
);

create or replace function public.create_share_invite(
  target_table_id uuid,
  valid_for interval default interval '24 hours',
  allowed_uses integer default 1
)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  plain_token text;
begin
  if auth.uid() is null or not public.is_cloud_table_owner(target_table_id) then
    raise exception 'Bu tablo için paylaşım yetkiniz yok';
  end if;
  if valid_for <= interval '0 seconds' or allowed_uses < 1 then
    raise exception 'Geçersiz paylaşım süresi veya kullanım adedi';
  end if;

  plain_token := encode(gen_random_bytes(18), 'hex');
  insert into public.share_invites (
    table_id,
    created_by,
    token_hash,
    expires_at,
    max_uses
  ) values (
    target_table_id,
    auth.uid(),
    digest(plain_token, 'sha256'),
    now() + valid_for,
    allowed_uses
  );
  return plain_token;
end;
$$;

create or replace function public.claim_share_invite(plain_token text)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  invite public.share_invites%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Giriş yapmanız gerekiyor';
  end if;

  select * into invite
  from public.share_invites
  where token_hash = digest(trim(plain_token), 'sha256')
    and expires_at > now()
    and use_count < max_uses
  for update;

  if not found then
    raise exception 'Paylaşım kodu geçersiz veya süresi dolmuş';
  end if;

  insert into public.table_members (table_id, user_id, role)
  values (invite.table_id, auth.uid(), invite.role)
  on conflict (table_id, user_id) do update set role = excluded.role;

  update public.share_invites
  set use_count = use_count + 1
  where id = invite.id;

  return invite.table_id;
end;
$$;

revoke all on function public.is_cloud_table_owner(uuid) from public;
revoke all on function public.is_cloud_table_member(uuid) from public;
revoke all on function public.create_share_invite(uuid, interval, integer) from public;
revoke all on function public.claim_share_invite(text) from public;

grant execute on function public.is_cloud_table_owner(uuid) to authenticated;
grant execute on function public.is_cloud_table_member(uuid) to authenticated;
grant execute on function public.create_share_invite(uuid, interval, integer)
  to authenticated;
grant execute on function public.claim_share_invite(text) to authenticated;
