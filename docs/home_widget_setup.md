# Ana ekran widget’ı — ilk sürüm

Android: yerel RemoteViews widget ve yapılandırma ekranı.
iOS: iOS 17+ WidgetKit uzantısı; orta ve büyük boyut. Uygulamanın minimum iOS sürümü değiştirilmedi.

Her widget ayrı bir tablo/çetele ve isteğe bağlı sayısal sütun/durum toplamı seçer.
Başlığa dokunmak doğru tabloyu açar; + mevcut kayıt/öğe ekleme formunu açar.
Doğrudan +1 veya arka planda kayıt değiştirme yoktur. Açık form varsa yönlendirme,
form kapanana kadar bekler. Silinen tablo başka bir tabloya otomatik atanmaz.

Widget verisi cihazda hesaplanır: ad, kimlik, kayıt sayısı, toplamlar ve tablonun
ilk birkaç satırı. Widget bu satırları gerçek bir tablo olarak çizer, yani hücre
içerikleri — çetelede öğe adları da — ana ekranda görünür. Bu bilinçli bir tercih;
görünürlüğü kısıtlamak isteyen kullanıcı widget eklememelidir. Oturum belirteçleri,
API anahtarları ve bulut kimlik bilgileri hiçbir zaman aktarılmaz.
Tablo başına en çok `HomeWidgetSnapshot.maxRecent` satır ve
`maxGridColumns` sütun (çetelede `maxGridDays` gün) gider; hücreler kısaltılır.
Satır sırası uygulamadaki sıralamayı izler, sıralama kapalıysa en yeni kayıt üsttedir.
Özetler arama filtresinden bağımsızdır; çetele toplamı çetelenin tarih aralığını kapsar.
Sütun adı değişince ilgili toplamı widget ayarlarından yeniden seçmek gerekir.
Widget güncellemelerinin gösterilme zamanını işletim sistemi belirler.
SMTP, yeni sunucu veya ücretli servis gerektirmez.

## iOS: hesap/provisioning adımı

Apple Developer → Certificates, Identifiers & Profiles bölümünde:

1. `group.com.muratstudio.tablenote` App Group kimliğini oluştur.
2. Ana App ID `com.muratstudio.tablenote` için App Groups yetkisini aç ve bu grubu seç.
3. Widget App ID `com.muratstudio.tablenote.TableNoteWidget` için de aynı grubu seç.
4. Xcode’da `ios/Runner.xcworkspace` aç. Runner ve TableNoteWidget hedeflerinde
   doğru geliştirme takımı ile otomatik imzalamayı kontrol et. İki hedefin de
   Signing & Capabilities → App Groups listesinde aynı grup olmalı.
5. Manuel imzalama kullanılıyorsa iki hedefin provisioning profillerini yenile.

Xcode hedefi, bağımlılığı, Embed App Extensions aşaması, sürüm eşleştirmesi,
entitlements ve paylaşılan UserDefaults gizlilik bildirimleri proje dosyalarına eklendi.
Widget uzantısını ana uygulamadan ayrı App Store uygulaması olarak oluşturma.

Paylaşılan UserDefaults erişimi, Apple’ın [App Group için 1C8F.1 gerekçesi](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)
ile her iki hedefin PrivacyInfo.xcprivacy dosyasında bildirildi.

## Cihazda deneme (bu geliştirme turunda çalıştırılmadı)

Native değişiklikler nedeniyle hot reload yeterli değildir; yeni uygulama kurulumu gerekir.
Önce uygulamayı açıp bir tablo/çetele oluştur; ardından telefonun widget galerisinden
Table Note ekle. Uygulamadaki Ayarlar → Ana ekran widget’ı bölümünde yönergeler var.

- İki widget ekle; farklı tablo ve toplam seç. Birinin ayarı diğerini değiştirmemeli.
- Uygulama kapalıyken ve arka plandayken başlığa/+ düğmesine dokun.
  Doğru tablo/çetele ve ekleme formu açılmalı; iptal etmek veri eklememeli.
- Bir form açıkken widget’a dokun; mevcut girişler korunmalı.
- Satır ekle/düzenle/sil, çetele durumunu değiştir; özetin yenilenmesini kontrol et.
- Dil ve tema değiştir; widget yazılarını kontrol et.
- Seçili tabloyu sil veya seçili sütunu yeniden adlandır; yanlış toplam/tablo gösterilmemeli.
- Android’de widget boyutlandırma/dişli ayarını ve yeniden başlatma sonrasını kontrol et.
- iOS’ta Widget’ı Düzenle ekranını, orta/büyük boyutları ve App Group veri aktarımını kontrol et.
- E-posta/Google giriş dönüşünün widget bağlantılarından etkilenmediğini kontrol et.

`test/home_widget_snapshot_test.dart` özet ve bağlantı ayrıştırma regresyon testlerini içerir.
Build veya cihaz testi yapılmadan platformların uçtan uca çalıştığı kabul edilmemelidir.
