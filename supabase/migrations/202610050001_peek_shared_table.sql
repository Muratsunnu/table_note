-- Katilim akisini adim adim sormak icin: kodu tek basina dogrulamak.
--
-- join_shared_table kodu, sifreyi ve adi TEK cagrida aliyor. Bu yuzden
-- arayuz uc alani birden sormak zorundaydi: kullanici sifresiz bir tabloya
-- katilirken bile bos bir sifre kutusu goruyor, kodu yanlissa adini bosuna
-- yaziyordu.
--
-- Bu fonksiyon katilim OLUSTURMAZ. Yalnizca "bu kod gecerli mi, sifre
-- istiyor mu" sorusunu yanitlar, boylece arayuz adimlari sirayla gosterir.
--
-- Hiz siniri join ile aynidir ve ayni sayaci kullanir. Olmasaydi bu
-- fonksiyon bedava bir kod tarayicisina donerdi: 1.000.000 kodluk alanda
-- gecerli olanlari sinirsiz deneyerek bulmak mumkun olurdu.
--
-- Tablo adini geri veriyor. Bu, dogru tabloya girdigini kullaniciya
-- gosteriyor; bedeli, gecerli bir kodu ele geciren birinin tablo adini da
-- ogrenmesi. Kodu bilen kisi zaten katilabildigi icin ek bir sizinti degil.

create or replace function public.peek_shared_table(
  plain_code text,
  plain_password text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  normalized_code text;
  target_table public.cloud_tables%rowtype;
  recent_failures integer;
  caller_ip text;
  needs_password boolean;
  password_ok boolean;
begin
  if auth.uid() is null then
    raise exception using message = 'authentication_required', errcode = 'P0001';
  end if;

  caller_ip := public.request_client_ip();

  select count(*) into recent_failures
  from public.share_join_attempts
  where user_id = auth.uid()
    and attempted_at > now() - interval '15 minutes';
  if recent_failures >= 10 then
    raise exception using message = 'too_many_attempts', errcode = 'P0001';
  end if;

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
    and join_code_hash = digest(normalized_code, 'sha256');

  if not found then
    insert into public.share_join_attempts (user_id, client_ip)
    values (auth.uid(), caller_ip);
    raise exception using message = 'invalid_table_code', errcode = 'P0001';
  end if;

  if not public.has_active_premium_user(target_table.owner_id) then
    raise exception using message = 'owner_premium_required', errcode = 'P0001';
  end if;

  needs_password := target_table.join_password_hash is not null;
  password_ok := not needs_password;

  if needs_password and plain_password is not null then
    if crypt(plain_password, target_table.join_password_hash)
       = target_table.join_password_hash then
      password_ok := true;
    else
      insert into public.share_join_attempts (user_id, client_ip)
      values (auth.uid(), caller_ip);
      raise exception using message = 'invalid_table_password', errcode = 'P0001';
    end if;
  end if;

  return jsonb_build_object(
    'tableName', target_table.name,
    'kind', target_table.table_kind,
    'requiresPassword', needs_password,
    'passwordOk', password_ok
  );
end;
$$;

revoke all on function public.peek_shared_table(text, text) from public, anon;
grant execute on function public.peek_shared_table(text, text) to authenticated;

comment on function public.peek_shared_table(text, text) is
  'Kodu dogrular ama katilim olusturmaz: arayuzun kodu, sifreyi ve adi
   sirayla sorabilmesi icin. Hiz siniri join_shared_table ile ayni sayaci
   kullanir, yoksa bedava bir kod tarayicisi olurdu.';
