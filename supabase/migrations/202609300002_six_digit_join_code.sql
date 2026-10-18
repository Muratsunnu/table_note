-- Katilim kodu 6 haneli, yalnizca rakam.
--
-- Telefonda okunabilsin, kolay yazilsin diye. Bedeli guvenlik: 16 haneli
-- onaltilik kodda 1.8e19 ihtimal vardi, 6 hanede 1.000.000 kaliyor. Yani kod
-- artik kaba kuvvetle taranabilir bir aralikta.
--
-- Kullanici basina deneme siniri tek basina yetmez: anonim kimlik bedava
-- oldugu icin saldirgan her 10 denemede yeni bir kimlik alip sayaci sifirlar.
-- Bu yuzden sinir IP basina da uygulaniyor; kimlik degistirmek IP'yi
-- degistirmez.

-- ---------------------------------------------------------------------------
-- 1. Denemelere istemci adresi eklenir
-- ----------------------------------------------------------

alter table public.share_join_attempts
  add column if not exists client_ip text;

create index if not exists share_join_attempts_ip_idx
  on public.share_join_attempts(client_ip, attempted_at desc)
  where client_ip is not null;

-- PostgREST istek basliklarini aktarir; proxy arkasindaki gercek adres
-- x-forwarded-for'un ilk parcasidir.
create or replace function public.request_client_ip()
returns text
language sql
stable
set search_path = public, pg_temp
as $$
  select nullif(
    btrim(
      split_part(
        coalesce(
          current_setting('request.headers', true)::json ->> 'x-forwarded-for',
          ''
        ),
        ',',
        1
      )
    ),
    ''
  );
$$;

-- ---------------------------------------------------------------------------
-- 2. Kod uretimi: 6 hane
-- ---------------------------------------------------------------------------

create or replace function public.rotate_shared_table_join_code(
  target_table_id uuid
)
returns text
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  plain_code text;
  attempts integer := 0;
begin
  if auth.uid() is null then
    raise exception using message = 'authentication_required', errcode = 'P0001';
  end if;
  if not public.is_cloud_table_owner(target_table_id) then
    raise exception using message = 'table_owner_required', errcode = 'P0001';
  end if;
  if not public.has_active_premium_user(auth.uid()) then
    raise exception using message = 'owner_premium_required', errcode = 'P0001';
  end if;

  perform set_config('app.shared_table_write_id', target_table_id::text, true);
  loop
    attempts := attempts + 1;
    -- 000000-999999, bastaki sifirlar korunur.
    plain_code := lpad((floor(random() * 1000000))::integer::text, 6, '0');
    begin
      update public.cloud_tables
      set collaboration_enabled = true,
          join_code_hash = digest(plain_code, 'sha256')
      where id = target_table_id;
      exit;
    exception when unique_violation then
      -- 1.000.000 kodluk alanda cakisma 16 haneliye gore cok daha olasi.
      -- Alan dolmaya baslarsa sonsuz donguye girmek yerine hata verilir.
      if attempts >= 20 then
        raise exception using message = 'join_code_space_exhausted', errcode = 'P0001';
      end if;
    end;
  end loop;

  return plain_code;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. Katilim: 6 hane dogrulamasi ve IP basina sinir
-- ---------------------------------------------------------------------------

create or replace function public.join_shared_table(
  plain_code text,
  plain_password text default null,
  display_name text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  normalized_code text;
  target_table public.cloud_tables%rowtype;
  wanted_name text;
  recent_failures integer;
  caller_ip text;
begin
  if auth.uid() is null then
    raise exception using message = 'authentication_required', errcode = 'P0001';
  end if;

  caller_ip := public.request_client_ip();

  -- Kimlik basina sinir: dogrudan kotuye kullanimi yavaslatir.
  select count(*) into recent_failures
  from public.share_join_attempts
  where user_id = auth.uid()
    and attempted_at > now() - interval '15 minutes';
  if recent_failures >= 10 then
    raise exception using message = 'too_many_attempts', errcode = 'P0001';
  end if;

  -- Adres basina sinir: yeni anonim kimlik almak sayaci sifirlamasin.
  if caller_ip is not null then
    select count(*) into recent_failures
    from public.share_join_attempts
    where client_ip = caller_ip
      and attempted_at > now() - interval '15 minutes';
    if recent_failures >= 30 then
      raise exception using message = 'too_many_attempts', errcode = 'P0001';
    end if;
  end if;

  normalized_code := regexp_replace(coalesce(plain_code, ''), '[-[:space:]]', '', 'g');
  if normalized_code !~ '^[0-9]{6}$' then
    insert into public.share_join_attempts (user_id, client_ip)
    values (auth.uid(), caller_ip);
    raise exception using message = 'invalid_table_code', errcode = 'P0001';
  end if;

  select * into target_table
  from public.cloud_tables
  where collaboration_enabled
    and join_code_hash = digest(normalized_code, 'sha256')
  for update;

  if not found then
    insert into public.share_join_attempts (user_id, client_ip)
    values (auth.uid(), caller_ip);
    raise exception using message = 'invalid_table_code', errcode = 'P0001';
  end if;

  if not public.has_active_premium_user(target_table.owner_id) then
    raise exception using message = 'owner_premium_required', errcode = 'P0001';
  end if;

  if target_table.join_password_hash is not null then
    if plain_password is null
       or crypt(plain_password, target_table.join_password_hash)
          <> target_table.join_password_hash then
      insert into public.share_join_attempts (user_id, client_ip)
      values (auth.uid(), caller_ip);
      raise exception using message = 'invalid_table_password', errcode = 'P0001';
    end if;
  end if;

  delete from public.share_join_attempts where user_id = auth.uid();

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
    raise exception using message = 'display_name_taken', errcode = 'P0001';
  end;

  perform public.log_table_activity(target_table.id, 'joined');

  return jsonb_build_object('tableId', target_table.id,
                            'displayName', wanted_name);
end;
$$;

-- Eskiden uretilmis 16 haneli kodlar artik dogrulamayi gecemez. Ilgili
-- tablolarin sahiplerinin kodu yeniden uretmesi gerekir; veri etkilenmez.
