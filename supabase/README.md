# Table Note Supabase kurulumu

1. Supabase projesi oluşturun.
2. `supabase/migrations` altındaki SQL migrasyonunu projeye uygulayın.
3. Authentication > Providers bölümünde Google sağlayıcısını etkinleştirin.
4. Redirect URL listesine `com.muratstudio.tablenote://login-callback` ekleyin.
5. Uygulamayı bağlantı bilgileriyle çalıştırın:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
```

Alternatif olarak `dart_defines.example.json` dosyasını `dart_defines.json`
adıyla kopyalayıp değerleri doldurun ve şu komutu kullanın:

```bash
flutter run --dart-define-from-file=dart_defines.json
```

Bağlantı bilgileri verilmezse Table Note çevrimdışı modda açılmaya devam eder.
`service_role` anahtarı hiçbir zaman mobil uygulamaya eklenmemelidir.

## E-posta kodları

Kayıt doğrulaması ve şifre sıfırlama bağlantıyla değil, e-postayla gelen 6
haneli kodla yapılır; kod, e-posta hangi cihazda okunursa okunsun çalışır.
Uygulama bağlantı beklemediği için şablonların kodu göstermesi şarttır:

1. Authentication > Emails > Templates bölümünde **Confirm signup** şablonuna
   `email_templates/confirm_signup.html`, **Reset password** şablonuna
   `email_templates/reset_password.html` içeriğini yapıştırın.
2. Konu satırları: `Table Note doğrulama kodun` ve
   `Table Note şifre sıfırlama kodun`.
3. Authentication > Sign In / Providers > Email bölümünde **Confirm email**
   açık, **Email OTP length** 6 olmalıdır.

Yerleşik e-posta göndericisi saatte 2 e-postayla sınırlıdır; yayından önce
Authentication > Emails > SMTP Settings bölümünden özel SMTP bağlanmalıdır.

## Google Play aboneliği

Play Console'da ürün kimliği `table_note_premium_yearly` olan yıllık abonelik ve
bu aboneliğe bağlı 7 günlük ücretsiz deneme teklifi oluşturulur. Ardından:

1. `202609010002_subscriptions.sql` migrasyonunu çalıştırın.
2. `verify-google-play-purchase` Edge Function'ını yayınlayın.
3. Function secret olarak `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`,
   `GOOGLE_PLAY_PACKAGE_NAME` ve `GOOGLE_PLAY_PRODUCT_ID` tanımlayın.
4. Servis hesabına Play Console'da abonelikleri görüntüleme yetkisi verin.

Premium hakkı cihaz tarafından değil, Google Play Developer API yanıtı üzerinden
bu fonksiyon tarafından verilir.

## Premium ortak tablolar

`202609050001_shared_table_collaboration.sql` migrasyonu su altyapiyi ekler:

- Tablo sahibinin yenileyebildigi, 16 haneli kalici katilim kodu
- Katilan kullaniciya `editor` uyeligi
- Veritabaninda dogrulanan aktif Premium zorunlulugu
- Ayni anda tek kullanicinin yazabilmesini saglayan 30-300 saniyelik kilit
- Kopan uygulamalarda otomatik bosa dusen kilit ve yenileme (heartbeat)
- Eski veriyle yeni verinin birbirini ezmesini engelleyen `revision` kontrolu
- `table_edit_locks` tablosu uzerinden Supabase Realtime bildirimi

Mobil uygulamada ortak tablo yazma islemleri dogrudan `cloud_tables` tablosuna
yapilmaz. Sirasiyla `acquire_shared_table_lock`, gerekirse
`renew_shared_table_lock` ve son olarak `update_shared_table` RPC'leri kullanilir.
Basarili guncelleme kilidi otomatik birakir. Kullanici ekrandan cikarsa
`release_shared_table_lock` cagrilir.

Debug modundaki gecici Premium anahtari yalnizca Flutter arayuzunu acar;
veritabani guvenligini atlamaz. Ortak calismayi simulator/emulator ile denemek
icin Supabase SQL Editor'de test kullanicisi adina gecici bir abonelik satiri
eklenebilir:

```sql
insert into public.subscriptions (
  user_id, platform, product_id, purchase_token_hash, status, expires_at
) values (
  'TEST_USER_UUID',
  'google_play',
  'table_note_premium_yearly',
  'development-only-TEST_USER_UUID',
  'active',
  now() + interval '7 days'
)
on conflict (user_id) do update
set status = 'active', expires_at = excluded.expires_at;
```

Bu test satiri magaza yayini oncesinde silinmelidir.
