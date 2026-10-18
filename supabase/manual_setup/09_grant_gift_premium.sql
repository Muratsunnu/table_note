-- Bir hesaba 2099 sonuna kadar hediye Premium verir. SQL Editor'de çalıştırılır;
-- yalnızca e-posta satırı değiştirilir. Önce bir kez
-- migrations/202610180001_gift_premium.sql çalışmış olmalı.
--
-- Hesap, kişinin uygulamada giriş yaptığı e-postayla bulunur (misafir hesap
-- olmaz). Sonuç tablosu boş gelirse o e-postayla açılmış bir hesap yoktur.
-- Hesabın zaten bir mağaza aboneliği varsa hediye onun yerine geçer.
with target as (
  select id
  from auth.users
  where lower(email) = lower('ornek@gmail.com')
)
insert into public.subscriptions (
  user_id, platform, product_id, purchase_token_hash,
  status, expires_at, last_verified_at, store_payload
)
select
  id, 'gift', 'table_note_premium_gift', 'gift:' || id::text,
  'active', '2099-12-31 23:59:59+00', now(),
  jsonb_build_object('note', 'hediye', 'granted_at', now())
from target
on conflict (user_id) do update set
  platform = excluded.platform,
  product_id = excluded.product_id,
  purchase_token_hash = excluded.purchase_token_hash,
  status = excluded.status,
  expires_at = excluded.expires_at,
  last_verified_at = excluded.last_verified_at,
  store_payload = excluded.store_payload;

-- Sonuç: hesabın Premium satırı.
select u.email, s.platform, s.status, s.expires_at
from public.subscriptions s
join auth.users u on u.id = s.user_id
where lower(u.email) = lower('ornek@gmail.com');
