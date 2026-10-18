-- Yapi degisikliklerinin buluta gitmesi.
--
-- Simdiye kadar yalnizca SATIRLAR ve OGELER senkronlaniyordu. Sutun eklemek,
-- cetelede durum ya da tarih araligi degistirmek karsi tarafa hic ulasmiyordu.
-- Bu yalnizca eksik bir ozellik degil, sessiz bir bozulma yoluydu: sutun
-- sayisi iki tarafta farklilasinca satir birlestirmeleri yanlis uzunlukta
-- satirlar yazmaya baslardi.
--
-- Yapiyi yalnizca SAHIP degistirebilir. Iki kisinin es zamanli sutun
-- degisikligini birlestirmek icin islem donusumu gerekirdi; bu uygulamanin
-- ihtiyacina gore cok agir. Sahiplik modeli zaten kurulu: kodu o uretiyor,
-- aboneligi o odiyor.
--
-- Onemli tasarim karari: yapi gonderimi SATIRLARI TASIMAZ. Istemcinin
-- elindeki yuku butun halinde yazmak daha kolay olurdu, ama o sirada
-- katilan birinin kaydettigi satir sahibin eski kopyasinda bulunmadigi icin
-- silinirdi. Bunun yerine sunucu yalnizca sutunlari degistirip mevcut
-- satirlarin boyunu kendisi ayarlar; hangi satirin var oldugu hic
-- tartisilmaz, dolayisiyla surum yarisi da olusmaz.

-- ---------------------------------------------------------------------------
-- 1. Tablo sutunlari
-- ---------------------------------------------------------------------------

create or replace function public.apply_shared_table_columns(
  target_table_id uuid,
  new_name text,
  new_columns jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_table public.cloud_tables%rowtype;
  table_payload jsonb;
  old_rows jsonb;
  new_rows jsonb := '[]'::jsonb;
  old_row jsonb;
  built jsonb;
  row_position integer := 0;
  column_index integer;
  column_json jsonb;
  -- Hangi sutunlarin "eski" oldugunu istemci bildirmez; sunucu kendi
  -- sayisini zaten biliyor ve boylece arada bir yaris da olusmaz.
  original_column_count integer;
  cell text;
  next_revision bigint;
  saved_at timestamptz;
begin
  if auth.uid() is null then
    raise exception using message = 'authentication_required', errcode = 'P0001';
  end if;
  if jsonb_typeof(new_columns) <> 'array' or jsonb_array_length(new_columns) = 0 then
    raise exception using message = 'invalid_shared_table_payload', errcode = 'P0001';
  end if;

  select * into current_table
  from public.cloud_tables
  where id = target_table_id
  for update;

  if not found then
    raise exception using message = 'table_not_found', errcode = 'P0001';
  end if;
  if current_table.owner_id <> auth.uid() then
    raise exception using message = 'table_owner_required', errcode = 'P0001';
  end if;
  if not public.has_active_premium_user(current_table.owner_id) then
    raise exception using message = 'owner_premium_required', errcode = 'P0001';
  end if;

  table_payload := current_table.payload;
  old_rows := coalesce(table_payload->'rows', '[]'::jsonb);
  original_column_count := jsonb_array_length(
    coalesce(table_payload->'columns', '[]'::jsonb));

  for old_row in select * from jsonb_array_elements(old_rows) loop
    row_position := row_position + 1;
    built := '[]'::jsonb;
    for column_index in 0 .. jsonb_array_length(new_columns) - 1 loop
      if column_index < original_column_count
         and column_index < jsonb_array_length(old_row) then
        cell := old_row->>column_index;
      else
        -- Yeni sutunun varsayilani. Istemcideki kuralin aynisi:
        -- columnType 1 sabit deger, 5 sira numarasi, digerleri bos.
        column_json := new_columns->column_index;
        cell := case
          when (column_json->>'columnType') = '1'
               and column_json->'constantValue' is not null
               and jsonb_typeof(column_json->'constantValue') <> 'null'
            then column_json->>'constantValue'
          when (column_json->>'columnType') = '5' then row_position::text
          else ''
        end;
      end if;
      built := built || to_jsonb(coalesce(cell, ''));
    end loop;
    new_rows := new_rows || jsonb_build_array(built);
  end loop;

  table_payload := jsonb_set(table_payload, '{columns}', new_columns);
  table_payload := jsonb_set(table_payload, '{rows}', new_rows);
  if nullif(btrim(new_name), '') is not null then
    table_payload := jsonb_set(table_payload, '{tableName}', to_jsonb(btrim(new_name)));
  end if;

  perform set_config('app.shared_table_write_id', target_table_id::text, true);
  update public.cloud_tables
  set name = coalesce(nullif(btrim(new_name), ''), name),
      payload = table_payload,
      revision = revision + 1
  where id = target_table_id
  returning revision, updated_at into next_revision, saved_at;

  perform public.log_table_activity(target_table_id, 'columns_changed');

  return jsonb_build_object(
    'table_id', target_table_id, 'revision', next_revision,
    'updated_at', saved_at, 'applied', '[]'::jsonb,
    'conflicts', '[]'::jsonb, 'payload', table_payload);
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. Cetele yapisi
-- ---------------------------------------------------------------------------
-- Burada satirlara dokunmak gerekmiyor: isaretler gun anahtariyla saklandigi
-- icin tarih araligini daraltmak veriyi silmez, yalnizca gosterilmeyeni
-- gizler. Durum silmek ise gecmis isaretleri oldugu gibi birakir; uygulama
-- tanimadigi kodu zaten bos gosteriyor.

create or replace function public.apply_shared_tally_structure(
  target_table_id uuid,
  new_name text,
  new_statuses jsonb,
  new_start text,
  new_end text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_table public.cloud_tables%rowtype;
  table_payload jsonb;
  next_revision bigint;
  saved_at timestamptz;
begin
  if auth.uid() is null then
    raise exception using message = 'authentication_required', errcode = 'P0001';
  end if;
  if jsonb_typeof(new_statuses) <> 'array' then
    raise exception using message = 'invalid_shared_table_payload', errcode = 'P0001';
  end if;

  select * into current_table
  from public.cloud_tables
  where id = target_table_id
  for update;

  if not found then
    raise exception using message = 'table_not_found', errcode = 'P0001';
  end if;
  if current_table.owner_id <> auth.uid() then
    raise exception using message = 'table_owner_required', errcode = 'P0001';
  end if;
  if not public.has_active_premium_user(current_table.owner_id) then
    raise exception using message = 'owner_premium_required', errcode = 'P0001';
  end if;

  table_payload := current_table.payload;
  table_payload := jsonb_set(table_payload, '{statuses}', new_statuses);
  if nullif(btrim(coalesce(new_start, '')), '') is not null then
    table_payload := jsonb_set(table_payload, '{startDate}', to_jsonb(new_start));
  end if;
  if nullif(btrim(coalesce(new_end, '')), '') is not null then
    table_payload := jsonb_set(table_payload, '{endDate}', to_jsonb(new_end));
  end if;
  if nullif(btrim(coalesce(new_name, '')), '') is not null then
    table_payload := jsonb_set(table_payload, '{tableName}', to_jsonb(btrim(new_name)));
  end if;

  perform set_config('app.shared_table_write_id', target_table_id::text, true);
  update public.cloud_tables
  set name = coalesce(nullif(btrim(new_name), ''), name),
      payload = table_payload,
      revision = revision + 1
  where id = target_table_id
  returning revision, updated_at into next_revision, saved_at;

  perform public.log_table_activity(target_table_id, 'columns_changed');

  return jsonb_build_object(
    'table_id', target_table_id, 'revision', next_revision,
    'updated_at', saved_at, 'applied', '[]'::jsonb,
    'conflicts', '[]'::jsonb, 'payload', table_payload);
end;
$$;

revoke all on function public.apply_shared_table_columns(uuid, text, jsonb)
  from public, anon;
grant execute on function public.apply_shared_table_columns(uuid, text, jsonb)
  to authenticated;
revoke all on function public.apply_shared_tally_structure(uuid, text, jsonb, text, text)
  from public, anon;
grant execute on function public.apply_shared_tally_structure(uuid, text, jsonb, text, text)
  to authenticated;
