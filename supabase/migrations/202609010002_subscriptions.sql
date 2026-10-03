create table if not exists public.subscriptions (
  user_id uuid primary key references auth.users(id) on delete cascade,
  platform text not null check (platform in ('google_play')),
  product_id text not null,
  purchase_token_hash text not null unique,
  status text not null check (status in ('active', 'trialing', 'grace_period', 'expired', 'canceled')),
  expires_at timestamptz not null,
  last_verified_at timestamptz not null default now(),
  store_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.subscriptions enable row level security;
revoke all on public.subscriptions from anon, authenticated;
grant select on public.subscriptions to authenticated;

drop policy if exists subscriptions_select_own on public.subscriptions;
create policy subscriptions_select_own
on public.subscriptions for select to authenticated
using (user_id = (select auth.uid()));

drop trigger if exists subscriptions_set_updated_at on public.subscriptions;
create trigger subscriptions_set_updated_at
before update on public.subscriptions
for each row execute function public.set_updated_at();
