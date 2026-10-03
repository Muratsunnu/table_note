-- Sohbetten uygulanan 1-6. adimlardan SONRA SQL Editor'de calistirin.
-- Yalnizca bildirim altyapisi: Flutter dinleyicisi table_edit_presence kullanmalidir.
begin;

-- Kilit anahtari ve tablo icerigi bu tabloda BULUNMAZ.
create table if not exists public.table_edit_presence (
  table_id uuid primary key
    references public.cloud_tables(id) on delete cascade,
  user_id uuid not null,
  editor_name text not null,
  expires_at timestamptz not null,
  updated_at timestamptz not null default now()
);

alter table public.table_edit_presence enable row level security;
revoke all on public.table_edit_presence from public, anon, authenticated;
grant select on public.table_edit_presence to authenticated;

drop policy if exists table_edit_presence_select_members
  on public.table_edit_presence;
create policy table_edit_presence_select_members
on public.table_edit_presence for select to authenticated
using (
  (select public.has_active_premium())
  and public.can_access_shared_table(table_id)
);

-- Gercek kilit tablosu istemciye ve Realtime'a acilmaz.
revoke all on public.table_edit_locks from public, anon, authenticated;

-- Kilit degisince anahtar icermeyen bildirim kaydini esitle.
create or replace function public.sync_table_edit_presence()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    -- Kilit birakilmasini DELETE yerine UPDATE ile bildir.
    -- Boylece bildirim satirinin RLS kontrolu uygulanabilir.
    update public.table_edit_presence
    set editor_name = '',
        expires_at = least(old.expires_at, clock_timestamp()),
        updated_at = clock_timestamp()
    where table_id = old.table_id;
    return old;
  end if;

  insert into public.table_edit_presence (
    table_id, user_id, editor_name, expires_at, updated_at
  ) values (
    new.table_id, new.user_id, new.editor_name,
    new.expires_at, clock_timestamp()
  )
  on conflict (table_id) do update set
    user_id = excluded.user_id,
    editor_name = excluded.editor_name,
    expires_at = excluded.expires_at,
    updated_at = excluded.updated_at;

  return new;
end;
$$;

revoke all on function public.sync_table_edit_presence()
  from public, anon, authenticated;

drop trigger if exists table_edit_locks_sync_presence
  on public.table_edit_locks;
create trigger table_edit_locks_sync_presence
after insert or update or delete on public.table_edit_locks
for each row execute function public.sync_table_edit_presence();

-- Kurulumdan once alinmis kilit varsa bildirim tablosuna aktar.
insert into public.table_edit_presence (
  table_id, user_id, editor_name, expires_at, updated_at
)
select table_id, user_id, editor_name, expires_at, clock_timestamp()
from public.table_edit_locks
on conflict (table_id) do update set
  user_id = excluded.user_id,
  editor_name = excluded.editor_name,
  expires_at = excluded.expires_at,
  updated_at = excluded.updated_at;

-- Silinen bir tablo icin eski kayit icerigi yayinlanmasin.
alter table public.table_edit_presence replica identity default;

do $$
begin
  if not exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) then
    raise exception 'supabase_realtime_publication_missing';
  end if;

  -- Eski bir kurulum ham kilit tablosunu yayina actiysa kapat.
  if exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'table_edit_locks'
  ) then
    alter publication supabase_realtime drop table public.table_edit_locks;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'table_edit_presence'
  ) then
    alter publication supabase_realtime add table public.table_edit_presence;
  end if;
end;
$$;

commit;
