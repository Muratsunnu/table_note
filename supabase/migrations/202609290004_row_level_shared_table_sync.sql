-- Satir bazli ortak duzenleme.
--
-- Bugune kadar ortak tabloya yazmak icin once ozel kilit alinirdi ve tablo
-- tek parca halinde gonderilirdi. Istenen akis farkli: sahip her degisikligi
-- aninda gonderir, katilan kisi birikmis degisikliklerini bir butonla atar.
-- Tek parca gonderim bunu kaldiramaz; katilanin gonderimi, arada sahibin
-- yaptiklarini silerdi.
--
-- Bu yuzden yazma artik satir satir. Cakisma yalnizca AYNI satira iki kisi
-- dokundugunda olur; farkli satirlar sessizce birlesir.
--
-- Cakisma tespiti satir basina "gordugun deger hala ayni mi" kontroluyle
-- yapilir: her islem, duzenleyenin basladigi degerleri (base) tasir. Sunucu
-- kayittakiyle karsilastirir, farkliysa o satiri UYGULAMAZ ve geri bildirir.
-- Boylece ek bir surum alanina gerek kalmaz ve kimsenin yazdigi kaybolmaz.

-- ---------------------------------------------------------------------------
-- 1. Premium sarti burada da sahibe gecer
-- ---------------------------------------------------------------------------

-- update_shared_table cagiranin Premium'una bakiyordu; katilan kisi odemedigi
-- icin bu yanlisti. Sart tablonun sahibinde.
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

  if not public.has_active_premium_user(current_table.owner_id) then
    raise exception using message = 'owner_premium_required', errcode = 'P0001';
  end if;
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

  perform public.log_table_activity(target_table_id, 'table_replaced');

  return jsonb_build_object(
    'table_id', target_table_id,
    'revision', next_revision,
    'updated_at', saved_at
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. Satir islemlerini uygula
-- ---------------------------------------------------------------------------

-- operations: [
--   {"op":"upsert","rowId":"...","values":["a","b"],"base":["a","x"]},
--   {"op":"delete","rowId":"...","base":["a","b"]}
-- ]
-- "base" null ise satirin yeni oldugu varsayilir.
create or replace function public.apply_shared_table_rows(
  target_table_id uuid,
  operations jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_table public.cloud_tables%rowtype;
  table_payload jsonb;
  rows_json jsonb;
  ids_json jsonb;
  columns_json jsonb;
  operation jsonb;
  op_kind text;
  op_row_id text;
  op_values jsonb;
  op_base jsonb;
  row_index integer;
  stored_row jsonb;
  applied jsonb := '[]'::jsonb;
  conflicts jsonb := '[]'::jsonb;
  column_index integer;
  column_name text;
  old_cell text;
  new_cell text;
  next_revision bigint;
  saved_at timestamptz;
begin
  if auth.uid() is null then
    raise exception using message = 'authentication_required', errcode = 'P0001';
  end if;
  if not public.can_edit_shared_table(target_table_id) then
    raise exception using message = 'shared_table_edit_access_required', errcode = 'P0001';
  end if;
  if jsonb_typeof(operations) <> 'array' then
    raise exception using message = 'invalid_shared_table_payload', errcode = 'P0001';
  end if;
  if jsonb_array_length(operations) = 0 then
    select revision, updated_at into next_revision, saved_at
    from public.cloud_tables where id = target_table_id;
    return jsonb_build_object(
      'table_id', target_table_id, 'revision', next_revision,
      'updated_at', saved_at, 'applied', '[]'::jsonb,
      'conflicts', '[]'::jsonb);
  end if;

  select * into current_table
  from public.cloud_tables
  where id = target_table_id
  for update;

  if not found then
    raise exception using message = 'table_not_found', errcode = 'P0001';
  end if;
  if not public.has_active_premium_user(current_table.owner_id) then
    raise exception using message = 'owner_premium_required', errcode = 'P0001';
  end if;
  -- Baskasi yapi degisikligi icin ozel kilidi tutuyorsa araya girilmez;
  -- sutunlar degisirken satirlari birlestirmek anlamsiz olurdu.
  if exists (
    select 1 from public.table_edit_locks
    where table_id = target_table_id
      and user_id <> auth.uid()
      and expires_at > now()
  ) then
    raise exception using message = 'shared_table_locked_by_other', errcode = 'P0001';
  end if;

  table_payload := current_table.payload;
  rows_json := coalesce(table_payload->'rows', '[]'::jsonb);
  ids_json := table_payload->'rowIds';
  columns_json := coalesce(table_payload->'columns', '[]'::jsonb);

  -- Satir kimligi olmayan eski bir yuk satir bazli birlestirilemez; istemci
  -- once tabloyu bir kez tam olarak gondermelidir.
  if ids_json is null or jsonb_typeof(ids_json) <> 'array'
     or jsonb_array_length(ids_json) <> jsonb_array_length(rows_json) then
    raise exception using message = 'shared_table_needs_upgrade', errcode = 'P0001';
  end if;

  for operation in select * from jsonb_array_elements(operations) loop
    op_kind := operation->>'op';
    op_row_id := operation->>'rowId';
    op_values := operation->'values';
    op_base := case when operation->'base' = 'null'::jsonb then null
                    else operation->'base' end;

    if op_row_id is null or op_kind not in ('upsert', 'delete') then
      raise exception using message = 'invalid_shared_table_payload', errcode = 'P0001';
    end if;

    select idx - 1 into row_index
    from jsonb_array_elements_text(ids_json) with ordinality as entry(value, idx)
    where entry.value = op_row_id
    limit 1;

    if row_index is null then
      -- Satir kayitta yok.
      if op_kind = 'delete' then
        -- Baskasi zaten silmis; istenen sonuc olustu.
        applied := applied || to_jsonb(op_row_id);
        continue;
      end if;
      if op_base is not null then
        -- Duzenleyen mevcut bir satiri guncelledigini saniyordu ama satir
        -- silinmis. Sessizce geri eklemek silme islemini geri alirdi.
        conflicts := conflicts || jsonb_build_object(
          'rowId', op_row_id, 'reason', 'deleted', 'current', null);
        continue;
      end if;
      rows_json := rows_json || jsonb_build_array(op_values);
      ids_json := ids_json || to_jsonb(op_row_id);
      applied := applied || to_jsonb(op_row_id);
      perform public.log_table_activity(
        target_table_id, 'row_added', op_row_id, null, null, op_values::text);
      continue;
    end if;

    stored_row := rows_json->row_index;

    -- Cakisma: duzenleyenin gordugu deger artik kayitta yok.
    if op_base is not null and stored_row is distinct from op_base then
      conflicts := conflicts || jsonb_build_object(
        'rowId', op_row_id, 'reason', 'changed', 'current', stored_row);
      continue;
    end if;

    if op_kind = 'delete' then
      rows_json := rows_json - row_index;
      ids_json := ids_json - row_index;
      applied := applied || to_jsonb(op_row_id);
      perform public.log_table_activity(
        target_table_id, 'row_deleted', op_row_id, null, stored_row::text, null);
      continue;
    end if;

    -- Guncelleme: hangi sutunlarin degistigi tek tek gunluge yazilir, cunku
    -- sahibin gormek istedigi sey "neyi degistirdi".
    for column_index in 0 .. greatest(
          jsonb_array_length(coalesce(stored_row, '[]'::jsonb)),
          jsonb_array_length(coalesce(op_values, '[]'::jsonb))) - 1 loop
      old_cell := stored_row->>column_index;
      new_cell := op_values->>column_index;
      if old_cell is distinct from new_cell then
        column_name := coalesce(
          columns_json->column_index->>'name', column_index::text);
        perform public.log_table_activity(
          target_table_id, 'row_updated', op_row_id, column_name,
          old_cell, new_cell);
      end if;
    end loop;

    rows_json := jsonb_set(rows_json, array[row_index::text], op_values);
    applied := applied || to_jsonb(op_row_id);
  end loop;

  table_payload := jsonb_set(table_payload, '{rows}', rows_json);
  table_payload := jsonb_set(table_payload, '{rowIds}', ids_json);

  perform set_config('app.shared_table_write_id', target_table_id::text, true);
  update public.cloud_tables
  set payload = table_payload,
      revision = revision + 1
  where id = target_table_id
  returning revision, updated_at into next_revision, saved_at;

  return jsonb_build_object(
    'table_id', target_table_id,
    'revision', next_revision,
    'updated_at', saved_at,
    'applied', applied,
    'conflicts', conflicts,
    'payload', table_payload
  );
end;
$$;

comment on function public.apply_shared_table_rows(uuid, jsonb) is
  'Satir islemlerini birlestirerek uygular. Kilit gerekmez: farkli satirlara
   dokunan iki kisi birbirini beklemez. Ayni satirda cakisma olursa o satir
   uygulanmaz ve conflicts icinde kayittaki hali geri doner.';
