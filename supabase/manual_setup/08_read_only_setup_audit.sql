-- SADECE OKUMA: veri veya yetki degistirmez.
-- Kurulum kontroludur; iki kullanicili davranis/eszamanlilik testinin yerine gecmez.
with expected_tables(name) as (
  values ('profiles'), ('cloud_tables'), ('table_members'), ('share_invites'),
         ('subscriptions'), ('table_edit_locks'), ('table_edit_presence')
), relations as (
  select e.name, c.oid, c.relrowsecurity
  from expected_tables e
  left join pg_class c on c.oid = to_regclass('public.' || e.name)
), expected_functions(signature, client_callable) as (
  values
    ('public.set_updated_at()', false),
    ('public.handle_new_user()', false),
    ('public.has_active_premium()', true),
    ('public.can_access_shared_table(uuid)', true),
    ('public.rotate_shared_table_join_code(uuid)', true),
    ('public.join_shared_table(text)', true),
    ('public.disable_shared_table_collaboration(uuid)', true),
    ('public.can_edit_shared_table(uuid)', true),
    ('public.lock_shared_table_for_edit(uuid)', false),
    ('public.acquire_shared_table_lock(uuid,integer)', true),
    ('public.renew_shared_table_lock(uuid,uuid,integer)', true),
    ('public.release_shared_table_lock(uuid,uuid)', true),
    ('public.update_shared_table(uuid,uuid,bigint,text,jsonb,integer)', true),
    ('public.sync_table_edit_presence()', false)
), functions as (
  select *, to_regprocedure(signature) as oid from expected_functions
), expected_policies(table_name, policy_name) as (
  values
    ('profiles', 'profiles_select_self'),
    ('profiles', 'profiles_update_self'),
    ('cloud_tables', 'cloud_tables_select_allowed'),
    ('cloud_tables', 'cloud_tables_insert_owner'),
    ('cloud_tables', 'cloud_tables_update_owner'),
    ('cloud_tables', 'cloud_tables_delete_owner'),
    ('subscriptions', 'subscriptions_select_own'),
    ('table_edit_presence', 'table_edit_presence_select_members')
), expected_triggers(table_name, trigger_name, function_name) as (
  values
    ('public.profiles', 'profiles_set_updated_at', 'public.set_updated_at()'),
    ('public.cloud_tables', 'cloud_tables_set_updated_at', 'public.set_updated_at()'),
    ('public.subscriptions', 'subscriptions_set_updated_at', 'public.set_updated_at()'),
    ('auth.users', 'on_auth_user_created', 'public.handle_new_user()'),
    ('public.table_edit_locks', 'table_edit_locks_sync_presence', 'public.sync_table_edit_presence()')
), checks(no, control, passed) as (
  select 1, '7 temel tablo mevcut', bool_and(oid is not null) from relations
  union all
  select 2, 'Tum tablolarda RLS acik',
    bool_and(oid is not null and coalesce(relrowsecurity, false)) from relations
  union all
  select 3, 'Anonim kullanicinin tablo/kolon erisimi kapali', bool_and(
    oid is not null
    and not has_table_privilege('anon', oid, 'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')
    and not has_any_column_privilege('anon', oid, 'SELECT,INSERT,UPDATE,REFERENCES')
  ) from relations
  union all
  select 4, '14 fonksiyon mevcut', bool_and(oid is not null) from functions
  union all
  select 5, 'Anonim kullanici fonksiyonlari cagiramaz',
    bool_and(oid is not null and not has_function_privilege('anon', oid, 'EXECUTE'))
  from functions
  union all
  select 6, 'Istemci yalnizca izinli fonksiyonlari cagirabilir', bool_and(
    oid is not null
    and has_function_privilege('authenticated', oid, 'EXECUTE') = client_callable
  ) from functions
  union all
  select 7, 'Premium kaydi istemciden degistirilemez',
    oid is not null
    and not has_table_privilege('authenticated', oid, 'INSERT,UPDATE,DELETE,TRUNCATE,TRIGGER')
    and not has_any_column_privilege('authenticated', oid, 'INSERT,UPDATE')
  from relations where name = 'subscriptions'
  union all
  select 8, 'Abonelik durumu uygulamadan okunabilir', bool_and(
    has_column_privilege('authenticated', to_regclass('public.subscriptions'), column_name, 'SELECT')
  ) from (values ('user_id'), ('status'), ('expires_at')) cols(column_name)
  union all
  select 9, 'Satin alma sunucusu aboneligi okuyup yazabilir',
    oid is not null
    and has_table_privilege('service_role', oid, 'SELECT')
    and has_table_privilege('service_role', oid, 'INSERT')
    and has_table_privilege('service_role', oid, 'UPDATE')
  from relations where name = 'subscriptions'
  union all
  select 10, 'Paylasim alanlari istemciden degistirilemez', bool_and(
    not has_column_privilege('authenticated', to_regclass('public.cloud_tables'), column_name, 'INSERT')
    and not has_column_privilege('authenticated', to_regclass('public.cloud_tables'), column_name, 'UPDATE')
  ) from (values ('revision'), ('collaboration_enabled'), ('join_code_hash')) cols(column_name)
  union all
  select 11, 'Ham kilit ve uyelik tablolari istemciye kapali', bool_and(
    oid is not null
    and not has_table_privilege('authenticated', oid, 'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')
    and not has_any_column_privilege('authenticated', oid, 'SELECT,INSERT,UPDATE,REFERENCES')
  ) from relations where name in ('table_edit_locks', 'table_members', 'share_invites')
  union all
  select 12, 'Bildirim tablosu istemciden sadece okunabilir',
    oid is not null
    and has_table_privilege('authenticated', oid, 'SELECT')
    and not has_table_privilege('authenticated', oid, 'INSERT,UPDATE,DELETE,TRUNCATE,TRIGGER')
    and not has_any_column_privilege('authenticated', oid, 'INSERT,UPDATE')
  from relations where name = 'table_edit_presence'
  union all
  select 13, 'Beklenen RLS kurallari mevcut; fazladan kural yok',
    not exists (
      select 1 from expected_policies e where not exists (
        select 1 from pg_policies p where p.schemaname = 'public'
          and p.tablename = e.table_name and p.policyname = e.policy_name
      )
    ) and not exists (
      select 1 from pg_policies p
      where p.schemaname = 'public' and p.tablename in (select name from expected_tables)
        and not exists (
          select 1 from expected_policies e
          where e.table_name = p.tablename and e.policy_name = p.policyname
        )
    )
  union all
  select 14, 'Yukleme ve guncelleme kurallarinda Premium kontrolu var',
    (select count(*) = 2 from pg_policies
      where schemaname = 'public' and tablename = 'cloud_tables'
        and policyname in ('cloud_tables_insert_owner', 'cloud_tables_update_owner')
        and lower(coalesce(with_check, '')) like '%has_active_premium%')
  union all
  select 15, 'Ortak tabloya dogrudan guncelleme kapali', exists (
    select 1 from pg_policies where schemaname = 'public'
      and tablename = 'cloud_tables' and policyname = 'cloud_tables_update_owner'
      and lower(coalesce(qual, '')) like '%not collaboration_enabled%'
      and lower(coalesce(with_check, '')) like '%not collaboration_enabled%'
  )
  union all
  select 16, 'Profil ve bildirim tetikleyicileri bagli', bool_and(exists (
    select 1 from pg_trigger t
    where t.tgrelid = to_regclass(e.table_name) and t.tgname = e.trigger_name
      and t.tgfoid = to_regprocedure(e.function_name)
      and not t.tgisinternal and t.tgenabled in ('O', 'A')
  )) from expected_triggers e
  union all
  select 17, 'Realtime bildirim tablosunu yayinliyor', exists (
    select 1 from pg_publication_tables where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'table_edit_presence'
  )
  union all
  select 18, 'Realtime ham kilit anahtarlarini yayinlamiyor', not exists (
    select 1 from pg_publication_tables where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'table_edit_locks'
  )
)
select no as sira, control as kontrol,
  case when passed is true then 'OK' else 'KONTROL GEREKLI' end as sonuc
from checks order by no;
