-- Katilim kodu sonradan da gorulebilsin.
--
-- Kod simdiye kadar yalnizca sha256 ozetiyle saklaniyordu, yani uretildigi
-- anda ekranda bir kez goruluyor, sonra kimse -- sahibi dahil --
-- goremiyordu. Kodunu hatirlamayan kullanicinin tek caresi yeni kod
-- uretmekti; o da eskisini gecersiz kildigi icin koda sahip baskalarini
-- disarida birakiyordu.
--
-- Artik duz metin de saklaniyor. Bedeli acik: veritabani sizarsa kodlar da
-- sizar. Kabul edilebilir goruyorum, cunku ayni sizintida tablolarin
-- ICERIGI zaten aciga cikar ve kod tek basina yetmez -- sifreli tablolarda
-- sifre ayrica gerekir, sifre hala yalnizca bcrypt ozetiyle duruyor.
--
-- Kritik nokta: cloud_tables satirini UYELER de okuyabiliyor (katildiklari
-- tabloyu indirebilmek icin). Kodu siradan bir sutun olarak eklemek,
-- katilan herkese kodu vermek olurdu; o zaman sahibin kimi davet ettigi
-- uzerindeki denetimi kaybolurdu. Bu yuzden sutunun SELECT izni
-- authenticated'tan geri aliniyor ve kod yalnizca sahibe, ayri bir
-- fonksiyonla veriliyor.

alter table public.cloud_tables
  add column if not exists join_code text;

-- Istemci bu sutunu hicbir sorguda secemez. Mevcut sorgular sutunlari tek
-- tek saydigi icin (select 'id, owner_id, ...') bu degisiklik onlari
-- etkilemez.
revoke select (join_code) on public.cloud_tables from authenticated, anon;

-- ---------------------------------------------------------------------------
-- Kod uretimi artik duz metni de yaziyor
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
          join_code_hash = digest(plain_code, 'sha256'),
          join_code = plain_code
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
-- Sahibin kodu tekrar okumasi
-- ---------------------------------------------------------------------------

create or replace function public.shared_table_join_code(target_table_id uuid)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  result text;
begin
  if auth.uid() is null then
    raise exception using message = 'authentication_required', errcode = 'P0001';
  end if;

  -- Uyelik degil SAHIPLIK araniyor; katilan kisi kodu goremez.
  select case when collaboration_enabled then join_code else null end
  into result
  from public.cloud_tables
  where id = target_table_id and owner_id = auth.uid();

  -- Satir yoksa da null doner: "sahibi degilsin" ile "kod yok" arasindaki
  -- farki istemciye soylemeye gerek yok, ikisinde de kod gosterilmez.
  return result;
end;
$$;

revoke all on function public.shared_table_join_code(uuid) from public, anon;
grant execute on function public.shared_table_join_code(uuid) to authenticated;

comment on function public.shared_table_join_code(uuid) is
  'Tablonun katilim kodunu yalnizca SAHIBINE doner. Kod cloud_tables.join_code
   sutununda durur ama o sutunun SELECT izni istemciden alinmistir; uyeler
   satiri okuyabildigi icin aksi halde kod katilan herkese gorunurdu.';

-- Bu degisiklikten ONCE uretilmis kodlar duz metin olarak saklanmadi ve geri
-- getirilemez; o tablolarda kod yalnizca yeniden uretilince gorunur olur.
