-- Cetelelerde satir bazli ortak calisma.
--
-- Tablonun apply_shared_table_rows'unun karsiligi, ama birlestirme bir yerde
-- bilerek ayriliyor: OGE degil GUN duzeyinde. Iki kisi ayni kisiye bakip biri
-- Pazartesi'yi, digeri Sali'yi isaretler; ogenin tamamini karsilastirsaydik bu
-- ikisi cakisirdi, oysa birbirinin isini hic bozmuyorlar. Islem yalnizca
-- gercekten dokunulan gunleri (days) ve o gunlerin dokunulmadan onceki halini
-- (dayBase) tasir. Cakisma yalnizca ayni ogenin AYNI gununde olur.
--
-- Oge kimligi istemci modelinde zaten vardi, yani tablolardaki rowIds gocune
-- benzer bir sey gerekmedi.

create or replace function public.apply_shared_tally_items(
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
  items_json jsonb;
  operation jsonb;
  op_kind text;
  op_item_id text;
  op_is_new boolean;
  op_days jsonb;
  op_day_base jsonb;
  op_name text;
  op_name_base text;
  item_index integer;
  stored_item jsonb;
  stored_entries jsonb;
  day_key text;
  old_mark text;
  new_mark text;
  conflicted boolean;
  applied jsonb := '[]'::jsonb;
  conflicts jsonb := '[]'::jsonb;
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

  select * into current_table
  from public.cloud_tables
  where id = target_table_id
  for update;

  if not found then
    raise exception using message = 'table_not_found', errcode = 'P0001';
  end if;
  if current_table.table_kind <> 'tally' then
    raise exception using message = 'invalid_shared_table_payload', errcode = 'P0001';
  end if;
  if not public.has_active_premium_user(current_table.owner_id) then
    raise exception using message = 'owner_premium_required', errcode = 'P0001';
  end if;

  table_payload := current_table.payload;
  items_json := coalesce(table_payload->'items', '[]'::jsonb);

  if jsonb_array_length(operations) = 0 then
    return jsonb_build_object(
      'table_id', target_table_id, 'revision', current_table.revision,
      'updated_at', current_table.updated_at, 'applied', '[]'::jsonb,
      'conflicts', '[]'::jsonb, 'payload', table_payload);
  end if;

  for operation in select * from jsonb_array_elements(operations) loop
    op_kind := operation->>'op';
    op_item_id := operation->>'itemId';
    op_is_new := coalesce((operation->>'isNew')::boolean, false);
    op_days := coalesce(operation->'days', '{}'::jsonb);
    op_day_base := coalesce(operation->'dayBase', '{}'::jsonb);
    op_name := operation->>'name';
    op_name_base := operation->>'nameBase';

    if op_item_id is null or op_kind not in ('upsert', 'delete') then
      raise exception using message = 'invalid_shared_table_payload', errcode = 'P0001';
    end if;

    select idx - 1 into item_index
    from jsonb_array_elements(items_json) with ordinality as entry(value, idx)
    where entry.value->>'id' = op_item_id
    limit 1;

    if item_index is null then
      if op_kind = 'delete' then
        -- Baskasi zaten silmis; istenen sonuc olustu.
        applied := applied || to_jsonb(op_item_id);
        continue;
      end if;
      if not op_is_new then
        -- Duzenleyen var olan bir ogeyi guncelledigini saniyordu ama oge
        -- silinmis. Sessizce geri eklemek silmeyi geri alirdi.
        conflicts := conflicts || jsonb_build_object(
          'itemId', op_item_id, 'reason', 'deleted', 'current', null);
        continue;
      end if;
      items_json := items_json || jsonb_build_array(jsonb_build_object(
        'id', op_item_id,
        'name', coalesce(op_name, ''),
        -- Isareti kaldirilmis gunler (null) yeni ogede hic yazilmaz.
        'entries', coalesce(
          (select jsonb_object_agg(key, value)
           from jsonb_each_text(op_days) where value is not null),
          '{}'::jsonb)
      ));
      applied := applied || to_jsonb(op_item_id);
      perform public.log_table_activity(
        target_table_id, 'item_added', op_item_id, null, null, op_name);
      continue;
    end if;

    stored_item := items_json->item_index;
    stored_entries := coalesce(stored_item->'entries', '{}'::jsonb);

    if op_kind = 'delete' then
      items_json := items_json - item_index;
      applied := applied || to_jsonb(op_item_id);
      perform public.log_table_activity(
        target_table_id, 'item_deleted', op_item_id, null,
        stored_item->>'name', null);
      continue;
    end if;

    -- Cakisma taramasi once bastan sona yapilir: yarisi uygulanmis bir oge
    -- birakmak, kullaniciya gosterilecek tutarli bir "kayittaki hal"
    -- birakmazdi.
    conflicted := false;
    if op_name_base is not null
       and (stored_item->>'name') is distinct from op_name_base then
      conflicted := true;
    end if;
    if not conflicted then
      for day_key in select key from jsonb_each(op_day_base) loop
        if (stored_entries->>day_key) is distinct from (op_day_base->>day_key) then
          conflicted := true;
          exit;
        end if;
      end loop;
    end if;

    if conflicted then
      conflicts := conflicts || jsonb_build_object(
        'itemId', op_item_id, 'reason', 'changed', 'current', stored_item);
      continue;
    end if;

    if op_name is not null and (stored_item->>'name') is distinct from op_name then
      perform public.log_table_activity(
        target_table_id, 'item_renamed', op_item_id, null,
        stored_item->>'name', op_name);
      stored_item := jsonb_set(stored_item, '{name}', to_jsonb(op_name));
    end if;

    for day_key in select key from jsonb_each(op_days) loop
      old_mark := stored_entries->>day_key;
      new_mark := op_days->>day_key;
      if old_mark is distinct from new_mark then
        perform public.log_table_activity(
          target_table_id, 'mark_changed', op_item_id, day_key,
          old_mark, new_mark);
      end if;
      if new_mark is null then
        stored_entries := stored_entries - day_key;
      else
        stored_entries := jsonb_set(
          stored_entries, array[day_key], to_jsonb(new_mark));
      end if;
    end loop;

    stored_item := jsonb_set(stored_item, '{entries}', stored_entries);
    items_json := jsonb_set(items_json, array[item_index::text], stored_item);
    applied := applied || to_jsonb(op_item_id);
  end loop;

  table_payload := jsonb_set(table_payload, '{items}', items_json);

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

revoke all on function public.apply_shared_tally_items(uuid, jsonb) from public, anon;
grant execute on function public.apply_shared_tally_items(uuid, jsonb) to authenticated;

comment on function public.apply_shared_tally_items(uuid, jsonb) is
  'Cetele oge islemlerini birlestirerek uygular. Birlestirme gun duzeyinde:
   ayni ogenin farkli gunlerine dokunan iki kisi cakismaz. Cakisma yalnizca
   ayni ogenin ayni gununde olur; o oge uygulanmaz ve conflicts icinde
   kayittaki hali geri doner.';
