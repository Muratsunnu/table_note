-- Kayit olmadan katilim:
-- 1) Katilan kisi Premium almak zorunda degil; Premium sarti tablo sahibinde.
-- 2) Katilim koduna istege bagli sifre (bcrypt, duz metin hicbir yerde durmaz).
-- 3) Her uyenin ayni tabloda benzersiz bir gorunen adi.
-- 4) Sadece tablo sahibinin okuyabildigi degisiklik gunlugu.

-- ---------------------------------------------------------------------------
-- 1. Premium sarti sahipte
-- ---------------------------------------------------------------------------

-- Katilan kisi anonim olabilir ve odeme yapmaz; parayi tabloyu paylasan
-- kisi oder. Bu yuzden hak kontrolu artik verilen kullaniciya gore yapilir.
create or replace function public.has_active_premium_user(target_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select target_user_id is not null and exists (
    select 1
    from public.subscriptions
    where user_id = target_user_id
      and status in ('active', 'trialing', 'grace_period')
      and expires_at > now()
  );
$$;

comment on function public.has_active_premium_user(uuid) is
  'Verilen kullanicinin aktif Premium hakki var mi. Katilim kontrollerinde
   tablo sahibi icin cagrilir.';

-- ---------------------------------------------------------------------------
-- 2. Istege bagli katilim sifresi
-- ---------------------------------------------------------------------------

alter table public.cloud_tables
  add column if not exists join_password_hash text;

comment on column public.cloud_tables.join_password_hash is
  'bcrypt ozeti. Duz sifre saklanmaz ve istemciye hicbir zaman donmez.';

-- Sifreyi yalnizca tablo sahibi belirleyebilir; null veya bos deger kaldirir.
create or replace function public.set_shared_table_password(
  target_table_id uuid,
  plain_password text
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  target_table public.cloud_tables%rowtype;
  trimmed text;
begin
  if auth.uid() is null then
    raise exception using message = 'authentication_required', errcode = 'P0001';
  end if;

  select * into target_table
  from public.cloud_tables
  where id = target_table_id
  for update;

  if not found or target_table.owner_id <> auth.uid() then
    raise exception using message = 'table_not_found', errcode = 'P0001';
  end if;

  trimmed := nullif(btrim(coalesce(plain_password, '')), '');
  if trimmed is not null and length(trimmed) < 4 then
    raise exception using message = 'password_too_short', errcode = 'P0001';
  end if;

  update public.cloud_tables
  set join_password_hash = case
        when trimmed is null then null
        else crypt(trimmed, gen_salt('bf'))
      end
  where id = target_table_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. Gorunen ad
-- ---------------------------------------------------------------------------

alter table public.table_members
  add column if not exists display_name text;

-- Ayni tabloda iki kisi ayni adi kullanamaz. Buyuk/kucuk harf farki ayri ad
-- sayilmaz; "Ayse" ile "ayse" ayni kisi gibi okunur.
create unique index if not exists table_members_display_name_idx
  on public.table_members(table_id, lower(display_name))
  where display_name is not null;

-- ---------------------------------------------------------------------------
-- 4. Hatali sifre denemeleri
-- ---------------------------------------------------------------------------

-- Kod 16 haneli olsa da sifre kisa olabilir; deneme sayisi sinirlanmazsa
-- sifre kaba kuvvetle bulunur.
create table if not exists public.share_join_attempts (
  user_id uuid not null references auth.users(id) on delete cascade,
  attempted_at timestamptz not null default now()
);

create index if not exists share_join_attempts_user_idx
  on public.share_join_attempts(user_id, attempted_at desc);

alter table public.share_join_attempts enable row level security;
-- Istemci bu tabloyu ne okur ne yazar; yalnizca security definer fonksiyon
-- dokunur. Bu yuzden hicbir policy tanimlanmadi.

-- ---------------------------------------------------------------------------
-- 5. Degisiklik gunlugu
-- ---------------------------------------------------------------------------

create table if not exists public.table_activity (
  id bigint generated always as identity primary key,
  table_id uuid not null references public.cloud_tables(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  -- Kaydin atildigi andaki ad. Kisi adini sonra degistirse de gunluk
  -- o gunku adi gostermeye devam eder.
  actor_name text not null,
  action text not null check (
    action in ('joined', 'left', 'row_added', 'row_updated', 'row_deleted',
               'table_replaced', 'columns_changed')
  ),
  row_id text,
  column_name text,
  old_value text,
  new_value text,
  created_at timestamptz not null default now()
);

create index if not exists table_activity_table_idx
  on public.table_activity(table_id, created_at desc);

alter table public.table_activity enable row level security;

-- Gunlugu yalnizca tablo sahibi okur. Katilan kisi kendi kaydini bile
-- goremez; istenen davranis bu.
drop policy if exists table_activity_select_owner on public.table_activity;
create policy table_activity_select_owner
  on public.table_activity
  for select
  using (
    exists (
      select 1
      from public.cloud_tables
      where cloud_tables.id = table_activity.table_id
        and cloud_tables.owner_id = (select auth.uid())
    )
  );

-- Insert/update/delete icin policy yok: kayitlari yalnizca asagidaki
-- security definer fonksiyon yazar, boylece istemci gunluge sahte kayit
-- atamaz ve mevcut kaydi degistiremez.

create or replace function public.log_table_activity(
  target_table_id uuid,
  action text,
  row_id text default null,
  column_name text default null,
  old_value text default null,
  new_value text default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  actor text;
begin
  if auth.uid() is null then
    raise exception using message = 'authentication_required', errcode = 'P0001';
  end if;

  select coalesce(
           (select member.display_name
            from public.table_members member
            where member.table_id = target_table_id
              and member.user_id = auth.uid()),
           (select profile.display_name
            from public.profiles profile
            where profile.id = auth.uid()),
           'bilinmeyen')
    into actor;

  insert into public.table_activity (
    table_id, actor_id, actor_name, action,
    row_id, column_name, old_value, new_value
  )
  values (
    target_table_id, auth.uid(), actor, action,
    row_id, column_name, old_value, new_value
  );
end;
$$;

-- Gunluge kayit atmak istemcinin isi degil: birisi kendi adina baskasinin
-- yaptigi bir degisikligi yazdirabilirdi. Yalnizca diger security definer
-- fonksiyonlar cagirir; onlar fonksiyon sahibi olarak calistigi icin bu
-- kisitlamadan etkilenmez.
revoke all on function public.log_table_activity(uuid, text, text, text, text, text)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 6. Katilim: sifre, ad ve Premium sartinin yeni hali
-- ---------------------------------------------------------------------------

-- Donus tipi uuid'den jsonb'ye degisiyor ve imza uc parametreli oluyor.
-- Postgres donus tipini "create or replace" ile degistirmeye izin vermez;
-- ayrica eski tek parametreli surum kalirsa tek argumanli cagri belirsiz olur.
drop function if exists public.join_shared_table(text);

create or replace function public.join_shared_table(
  plain_code text,
  plain_password text default null,
  display_name text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  normalized_code text;
  target_table public.cloud_tables%rowtype;
  wanted_name text;
  recent_failures integer;
begin
  if auth.uid() is null then
    raise exception using message = 'authentication_required', errcode = 'P0001';
  end if;

  -- Son 15 dakikada 10 basarisiz deneme: sifreyi kaba kuvvetle aramayi durdurur.
  select count(*) into recent_failures
  from public.share_join_attempts
  where user_id = auth.uid()
    and attempted_at > now() - interval '15 minutes';
  if recent_failures >= 10 then
    raise exception using message = 'too_many_attempts', errcode = 'P0001';
  end if;

  normalized_code := upper(
    regexp_replace(coalesce(plain_code, ''), '[-[:space:]]', '', 'g')
  );
  if length(normalized_code) <> 16
     or normalized_code !~ '^[0-9A-F]{16}$' then
    insert into public.share_join_attempts (user_id) values (auth.uid());
    raise exception using message = 'invalid_table_code', errcode = 'P0001';
  end if;

  select * into target_table
  from public.cloud_tables
  where collaboration_enabled
    and join_code_hash = digest(normalized_code, 'sha256')
  for update;

  if not found then
    insert into public.share_join_attempts (user_id) values (auth.uid());
    raise exception using message = 'invalid_table_code', errcode = 'P0001';
  end if;

  -- Premium sarti artik katilanda degil, tabloyu paylasan kiside.
  if not public.has_active_premium_user(target_table.owner_id) then
    raise exception using message = 'owner_premium_required', errcode = 'P0001';
  end if;

  if target_table.join_password_hash is not null then
    if plain_password is null
       or crypt(plain_password, target_table.join_password_hash)
          <> target_table.join_password_hash then
      insert into public.share_join_attempts (user_id) values (auth.uid());
      raise exception using message = 'invalid_table_password', errcode = 'P0001';
    end if;
  end if;

  -- Basarili giristen sonra o kullanicinin sayaci sifirlanir.
  delete from public.share_join_attempts where user_id = auth.uid();

  -- Sahip kendi tablosuna "katilmaz"; sadece tablo kimligini alir.
  if target_table.owner_id = auth.uid() then
    return jsonb_build_object('tableId', target_table.id, 'displayName', null);
  end if;

  wanted_name := btrim(coalesce(display_name, ''));
  if length(wanted_name) < 2 or length(wanted_name) > 32 then
    raise exception using message = 'invalid_display_name', errcode = 'P0001';
  end if;

  begin
    insert into public.table_members (table_id, user_id, role, display_name)
    values (target_table.id, auth.uid(), 'editor', wanted_name)
    on conflict (table_id, user_id)
      do update set role = 'editor', display_name = wanted_name;
  exception when unique_violation then
    -- Ad o tabloda baskasinda; kullaniciya baska ad sordurulur.
    raise exception using message = 'display_name_taken', errcode = 'P0001';
  end;

  perform public.log_table_activity(target_table.id, 'joined');

  return jsonb_build_object('tableId', target_table.id,
                            'displayName', wanted_name);
end;
$$;

-- ---------------------------------------------------------------------------
-- 7. Sahip icin uye listesi
-- ---------------------------------------------------------------------------

create or replace function public.shared_table_members(target_table_id uuid)
returns table (
  user_id uuid,
  display_name text,
  role text,
  joined_at timestamptz
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select member.user_id, member.display_name, member.role, member.created_at
  from public.table_members member
  join public.cloud_tables owner_table on owner_table.id = member.table_id
  where member.table_id = target_table_id
    and owner_table.owner_id = auth.uid()
  order by member.created_at;
$$;

-- ---------------------------------------------------------------------------
-- 8. Terk edilmis anonim kullanicilarin temizligi
-- ---------------------------------------------------------------------------

-- Anonim kullanicilar kendiliginden silinmez. Kod girip vazgecen her cihaz
-- kalici bir satir birakir ve aylik aktif kullanici sayisina dahil olur.
-- Bu fonksiyon, hicbir tabloya uye olmayan ve 30 gundur oturum acmamis
-- anonim kullanicilari siler. Zamanlanmis gorev olarak calistirilmalidir.
create or replace function public.purge_stale_anonymous_users()
returns integer
language plpgsql
security definer
set search_path = public, pg_temp, auth
as $$
declare
  removed integer;
begin
  with doomed as (
    delete from auth.users
    where is_anonymous
      and coalesce(last_sign_in_at, created_at) < now() - interval '30 days'
      and not exists (
        select 1 from public.table_members
        where table_members.user_id = users.id
      )
      and not exists (
        select 1 from public.cloud_tables
        where cloud_tables.owner_id = users.id
      )
    returning 1
  )
  select count(*) into removed from doomed;
  return removed;
end;
$$;

revoke all on function public.purge_stale_anonymous_users() from public, anon, authenticated;
