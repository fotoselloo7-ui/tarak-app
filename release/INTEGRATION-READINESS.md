# Tarak entegrasyon ve yayın durumu — 28 Ekim 2026

Bu çalışma `aa7ce4b63e442c3e9411a88276c6a9a193ff2594` referansından ilerler. Üretim cPanel veritabanına bağlanılmadı. Güncel yerel sürüm mevcut Tarak verilerinin ayrı yerel MySQL kopyasını kullanır; veritabanı ve yedekler Git dışında tutulur.

## Yerel çalıştırma

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\start-local.ps1 -Port 18810
```

Port belirtilmezse 8010 kullanılır. Bu bilgisayarda 8010/8011 eski başka bir geliştirme projesine ait süreçlerce kullanıldığı için doğrulama 18810 üzerinde yapıldı. Başlatıcı dolu portu reddeder; eski süreçleri kapatmaz.

Başlatıcı PHP/Composer bağımlılıklarını ve eksik migration'ları hazırlar. Mevcut `.env` içindeki yerel SQLite veya loopback MySQL kullanılır; uzak MySQL/cPanel ve DB_URL reddedilir. Boş SQLite için yalnız hizmet kataloğu oluşturulur. Otomatik örnek hesap üretimi kaldırıldı; isteğe bağlı `-SeedPreview` yalnız ayrı SQLite için kullanılabilir.

### Mevcut kullanıcı verilerinin korunması

İlk önizlemede yeni SQLite açıldığı için eski kayıtlar görünmüyordu. Eski yerel kaynak `C:/Projeler/berberimgelsin (2)/backend` içindeki MySQL veritabanında bulundu. `scripts/copy-local-database.php` ile önce SQL yedeği, ardından ayrı `tarak_updated_local_20261028` veritabanı oluşturuldu. Kaynak veritabanına yazılmadı; eski SQLite da silinmedi. Fotoğraf dosyaları mevcut dosyaların üzerine yazılmadan kopyalandı. Eski loopback fotoğraf URL'leri yalnız yerel JSON yanıtlarında güncel origin'e uyarlanır; saklanan URL'ler değişmez.

- 5.203 hesap: 5.101 müşteri, 101 hizmet veren, 1 yönetici.
- 101 hizmet veren profili, 7.611 adres, 5.052 değerlendirme, 12 randevu, 27 sohbet mesajı.
- Kaynaktaki 67 tablonun kayıt sayıları kopyalama sırasında eşleşti. Yeni migration'lardan sonra 65 tablodaki özgün sütunların tüm satır değerleri hash ile karşılaştırıldı ve değişmediği doğrulandı. Çalışırken değişen `cache` ve yeni migration kayıtları bu ikinci karşılaştırmanın dışındadır: `release/validation/data-integrity.json`.
- Kaynakta 5.100 müşteri ve 100 hizmet veren zaten `is_demo=1` taşıyordu. Bu değerler bu çalışmada eklenmedi veya değiştirilmedi; hesaplar yeniden üretilmedi. Gerçek hesap/demo ayrımı için kaynak işaretlerinin doğruluğu ayrıca değerlendirilmeli; topluca rozet/kimlik doğrulaması verilmedi.
- Web `/api/providers` toplam 101 profil döndürür; vitrin ve eski profil fotoğrafları HTTP 200 ile doğrulandı. Pixel 4a aynı güncel API'ye bağlıdır.
- Yedek ve önceki yerel `.env`: `.tools/local-db-backups/20261028-125930/` (Git dışında). Mevcut kaynak sistem korunur.

## Uygulanan akışlar

- Mevcut React kayıt/giriş ekranlarında Google/Apple bilgi doldurma, e-posta ve SMS doğrulama kontrolleri, kullanım koşulları/KVKK ve ayrı pazarlama tercihi.
- Sağlayıcı seçimi hesap/oturum oluşturmaz. Son kayıt işlemi kullanıcı tarafından açıkça tamamlanır. Sosyal giriş yalnız bağlı sağlayıcı + subject kimliğini kullanır; e-posta eşleşmesiyle hesap seçmez. Mevcut hesap bağlama oturum ve mevcut şifre ister.
- OTP altı haneli, 10 dakika geçerli, yeniden gönderim 60 saniye, en fazla beş yanlış deneme. Kanıt iletişim bilgisine bağlıdır ve kayıt sırasında tüketilir.
- Mevcut müşteri/işletme adres formlarında harita arama, sürüklenen pin ve ters geocoding ile alan doldurma; il/ilçe/mahalle/sokak/bina alanları düzenlenebilir. Koordinat çifti doğrulanır ve profil/adres kaydına yazılır.
- Müşteri ana sayfasında mevcut vitrin kartıyla Size Yakın Berberler: kayıtlı adres veya izinli cihaz konumu, 1–50 km, gerçek mesafe ve yakınlık sırası. Web ve Flutter aynı `/customer/providers/nearby` sorgusunu kullanır.
- Demo hesaplar ve orijinal üretme/tek tuşla temizleme sistemi korunur. Demo kartları etiketlenir; sahte belge/yorumlar gerçek doğrulama rozeti veya gerçek puan üretmez. Demo detayları önizlenebilir, gerçek çağrı uygunluğu verilmez.
- Flutter mevcut ekranlarına sosyal bilgi doldurma/giriş/hesap bağlama, OTP, adres seçme/düzenleme ve yakın berberler eklendi. Firebase, ödeme, randevu ve sohbet altyapıları korunur.

## Gerekli gerçek servis ayarları

| Entegrasyon | Ayar |
|---|---|
| Google web/mobile | Backend `GOOGLE_WEB_CLIENT_ID`, gerekirse `GOOGLE_ANDROID_CLIENT_ID`, `GOOGLE_IOS_CLIENT_ID`; mobile build `GOOGLE_WEB_CLIENT_ID`, iOS için `GOOGLE_CLIENT_ID` |
| Apple | `APPLE_SERVICE_ID`, `APPLE_BUNDLE_ID=app.tarak.mobile`, `APPLE_CLIENT_SECRET`, `APPLE_REDIRECT_URI`; iOS provisioning profilinde Sign in with Apple yetkisi |
| E-posta | Üretimde gerçek mail transportu (`MAIL_MAILER=smtp` gibi) ve mevcut Admin → Entegrasyon Merkezi → SMTP ayarları |
| SMS | Mevcut Admin → Entegrasyon Merkezi → SMS sağlayıcı kimlik bilgileri, sağlayıcı aktifliği ve `otp` olayı aktifliği |
| Maps backend | `GOOGLE_MAPS_SERVER_KEY` — yalnız sunucuda, Geocoding API ile sınırlı |
| Maps web | `GOOGLE_MAPS_BROWSER_KEY`, isteğe bağlı `GOOGLE_MAPS_MAP_ID`; referrer ve API kısıtları |
| Maps Android/iOS | CI/local build `GOOGLE_MAPS_ANDROID_API_KEY` Gradle property ve `GOOGLE_MAPS_IOS_API_KEY`; native build `GOOGLE_MAPS_ENABLED=true` |

Bu kimlik bilgileri bu çalışma sırasında mevcut değildi. Yapılandırılmayan servisler açıklayıcı hata verir. Gerçek Google/Apple oturumu, SMS/e-posta teslimatı ve canlı Google haritası cihazda doğrulanmış sayılmaz. Apple Android web dönüş akışı bu sürümde etkin değildir; native Apple akışı iOS içindir. Apple'ın kimlik belirtecinde doğrulanmış ad/soyad bulunmadığında alanlar kullanıcıya bırakılır.

Google haritası yalnız seçici açıldığında yüklenir; native arama beklemeli, web arama açık gönderimli, sunucu uçları hız sınırlıdır. Tam geocoding sonuçları tekrar kullanılan kalıcı bir önbelleğe yazılmaz. Cloud Console günlük API kotası ve bütçe uyarıları ayrıca ayarlanmalıdır; bütçe uyarısı harcamayı durdurmaz. Ücretsiz sınırlar SKU'ya göre değişir: [Google fiyatlandırma](https://developers.google.com/maps/billing-and-pricing/pricing), [maliyet/kota yönetimi](https://developers.google.com/maps/billing-and-pricing/manage-costs), [geocoding politikaları](https://developers.google.com/maps/documentation/geocoding/policies).

## Kontroller ve mağaza durumu

- Laravel: 15 test, 82 doğrulama. Test bootstrap'ı `$_SERVER`, `$_ENV` ve process env üzerinde zorunlu `:memory:` SQLite kullanır. Testten sonra 5.203 hesap ve 101 hizmet veren profilinin korunduğu ayrıca doğrulandı.
- Paket denetiminde Laravel 11/CommonMark açıkları görüldüğü için PHP 8.2 uyumu korunarak Laravel 12.70.2 ve CommonMark 2.10.4'e geçildi. Composer doğrulaması ve güvenlik denetimi temiz; 261 route çözümlendi ve API testleri tekrar geçti. Geçiş: [Laravel resmi kılavuzu](https://laravel.com/docs/12.x/upgrade), [kimlik doğrulama güvenlik kaydı](https://github.com/laravel/framework/security/advisories/GHSA-f9x3-7vq9-cph6).
- Flutter: 440 test geçti; `flutter analyze --no-pub` temiz.
- Yerel HTTP: sağlık, kategori/hizmet ve vitrin sorguları gerçek Laravel üzerinden kontrol edildi. Katalog 2 kategori/19 hizmettir.
- Tarayıcı: mevcut kayıt tasarımı, müşteri ana sayfası, 10→1 km filtre (1,1 km kartın çıkması), karttan mevcut detay sayfası ve demo önizleme kontrol edildi. Görseller `release/validation/` içindedir.
- Pixel 4a (`emulator-5556`): güncel debug APK yüklendi ve `app.tarak.mobile/.MainActivity` önde çalıştığı doğrulandı. İlk açılış ikon seçimi ekranı korunmuştur. Bu debug derlemesi `http://10.0.2.2:18810/api` yerel API'sini kullanır.
- Android/iOS kimliği `app.tarak.mobile`, kaynak sürümü `1.1.0+2`; doğrulama derlemelerinde build 3 kullanılır. Mağazaya yüklerken son yayınlanan build numarasından daha yüksek bir değer seçilmelidir.
- Android AGP/Kotlin uyumu güncellendi, gerçek keystore gerektiren AAB koruması korundu. Release AAB build 3 başarıyla üretildi (68,2 MB); `jarsigner -verify` sonucu `jar verified`. SHA-256: `664b9e8ee66f9266efb04ca179631b64f7179ec2559bf98dc834229725c288f5`. Dosya `mobile/build/app/outputs/bundle/release/app-release.aab` içindedir ve Git'e eklenmez. Maps/OAuth anahtarları olmadan üretilmiş test AAB'si tamamlanmış mağaza yayını sayılmaz.
- iOS için Windows üzerinde IPA üretilemez. TestFlight iş akışı açık manuel tetiklemeye alındı; OAuth/Maps ayarları build sırasında enjekte edilir. Mevcut Firebase dosyaları korunur.
- GitHub erişimi doğrulandı; depodaki Actions secret listesi kontrolde boştu. iOS dağıtım sertifikası/provisioning/App Store Connect ve Android upload signing/Maps/OAuth değerleri repository Actions ayarlarına sahibi tarafından eklenmelidir. Özel anahtarlar Git'e eklenmez.
- Önceki TestFlight run `40171778526`, GitHub'ın hesap ödemesi/harcama limiti engeli nedeniyle derleme adımına başlamamıştı. `Billing & plans` ayarı hesap sahibi tarafından çözülmeden yeni Actions işleri de başlayamayabilir. Bu, yerel derleme sonucundan ayrı bir dış engeldir.
- App Store/TestFlight veya Google Play'e yükleme/yayın tamamlandı iddiası yoktur. İmzalama ve gerçek servis yapılandırmaları olmadan release iş akışı yayın başarısı sayılmaz.

## Web kaynağı sınırı ve tekrar uygulama

Bu Git deposunda düzenlenebilir React/TypeScript projesi yerine Vite dağıtımı vardır. Yeni kodlar okunabilir ESM modülleridir (`AuthControls.js`, `MapAddressPicker.js`, `NearbyProviders.js`); mevcut ekranlara sınırlı, kontrol edilen bağlantılar yapılır. Görünüm/CSS/vitrin fotoğrafları yeniden oluşturulmaz.

Entegrasyonlar, aynı güvenli dağıtım tabanı üzerinde şu sırayla tekrar uygulanabilir:

```powershell
node scripts/integrate-web-auth.mjs
node scripts/integrate-web-nearby.mjs
node scripts/integrate-web-dashboard-nearby.mjs
node scripts/patch-web-map-address.mjs
node scripts/integrate-web-demo-labels.mjs
node scripts/integrate-web-social-link.mjs
node scripts/version-web-assets.mjs
```

Tüm modül grafiği aynı sürüm sorgusunu kullanır; tarayıcı eski/yeni chunk veya iki farklı main modülünü karıştırmaz. Tam React kaynağıyla gelecekte yeni build alınırsa bu entegrasyonlar o kaynağa taşınmalıdır. Başka yerel projede bulunan kaynak, güvenli Git referansıyla birebir doğrulanmadığı için bu çalışmada onun üzerine yazılmadı.

Yerel eşitleme aracı `sync-conflict` kopyaları üretiyordu. Kopyalar kurtarılabilir şekilde `.tools/sync-conflicts/` içine alındı; Git'e dahil edilmez. Eşitleme ayarlarında `vendor`, `build`, `.dart_tool`, `.gradle` ve yerel SQLite dosyası üretilmiş/yerel dosya olarak dışlanmalıdır. Ara Android kaynak birleştirme hatası yalnız üretilmiş Flutter dosyaları temizlenip yeniden derlenerek giderildi.
