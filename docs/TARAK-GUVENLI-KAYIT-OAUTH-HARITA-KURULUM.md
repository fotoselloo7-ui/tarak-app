# Tarak.app — Güvenli Üyelik / Google / Apple / Google Maps

**ÖNEMLİ:** Kaynak kodlar GitHub'da; gerçek SMTP/SMS/OAuth/Maps anahtarları yapılandırılmadan canlı işlev garantisi yok. Web ve Flutter uygulaması yeni dağıtıma ihtiyaç duyar.

## Yayın sırası

1. Web köküne tarak.app/guvenli-kayit.html, index.html ve assets/tarak-secure-registration*.js dosyalarını yükle. Eski varlıkları silme.
2. Laravel backend değişen dosyalarını yükle. Mevcut .env ve APP_KEY değerini KORU.
3. Terminalde: cd /home/alac6ayazilimtr/tarak-backend
4. Terminalde: php artisan migrate --force
5. Terminalde: php artisan optimize:clear
6. SMTP test e-postası ulaşıyor mu doğrula; güvenli kayıt sayfasında 6 haneli OTP kodunu test et.
7. Her iki kayıt istemcisi dağıtılıp doğrulandıktan sonra .env içinde REGISTRATION_VERIFICATION_REQUIRED=true ayarla ve php artisan config:clear çalıştır. Bundan sonra /auth/register endpointi OTP olmadan hesap açmayı reddeder. Eski derlenmiş istemcilerin bu geçişle uyumlu olması şarttır.

## Üretim .env (yalnızca eksik anahtarları ekle)

REGISTRATION_VERIFICATION_REQUIRED=false
GOOGLE_OAUTH_WEB_CLIENT_ID=
APPLE_OAUTH_BUNDLE_ID=app.tarak.mobile
GOOGLE_MAPS_BROWSER_API_KEY=

APP_KEY değiştirilmemeli: şifreli SMTP/PayTR ayarları eski anahtara bağlı olabilir. Bu örnekteki boş değerin yerine kişisel OAuth istemci kimliğini sunucuda tanımla. Şifre/parola/servis hesabı JSON'unu repoya push etme.

## Google bağlantısı

Google Cloud Console -> OAuth Consent Screen + Web Client oluştur. Client ID sunucudaki GOOGLE_OAUTH_WEB_CLIENT_ID ile mobil --dart-define=GOOGLE_OAUTH_WEB_CLIENT_ID arasında aynı olmalı. Android için app.tarak.mobile ve sürümün SHA-1/SHA-256 imzalarına bağlı OAuth Android Client ekle. iOS için uygulama Bundle ID'sine ait iOS Client ID ve Reverse Client ID değerlerini Xcode private build setting TARAK_GOOGLE_IOS_CLIENT_ID ve TARAK_GOOGLE_IOS_REVERSED_CLIENT_ID olarak tanımla. Gerekirse Firebase GoogleService-Info.plist dosyasını yeniden indir.

Google kimlik ID token'ı Laravel'de imza + audience + issuer kontrolünden geçer. Profil ön izlemesi hesap açmaz; kullanıcı bilgileri sonradan düzenleyebilir.

## Apple bağlantısı

Apple Developer -> Identifier app.tarak.mobile -> Sign in with Apple capability etkinleştir. Güncel provisioning profile yeniden üret. Runner.entitlements Apple entitlement içerir. Apple JWT, Apple public JWKS anahtarları ve audience/issuer ile doğrulanır. Apple yalnızca ilk yetki verilişinde ad soyad gönderebilir; kullanıcı elle düzenler. Hesap otomatik açılmaz.

## Harita

Mobil Google Maps SDK: Google'ın 2026 fiyatlandırmasına göre mobil native harita gösterimi (Maps SDK SKU) sınırsız ücretsiz, ancak Cloud Billing etkinleşmeli ve platforma özel, kısıtlı API key gerekir.

Android: Google Cloud Maps SDK for Android; Gradle TARAK_MAPS_API_KEY (env veya -PTARAK_MAPS_API_KEY).
iOS: Google Cloud Maps SDK for iOS; private Xcode build setting TARAK_MAPS_IOS_API_KEY.
Her iki platform yapılandırıldıktan sonra Flutter build'e --dart-define=TARAK_MAPS_ENABLED=true ekle. Eksik anahtarda kullanıcı elle adres kaydeder.

Web: Maps JavaScript API + Geocoding API açılır; GOOGLE_MAPS_BROWSER_API_KEY HTTP referrer https://tarak.app/* ile kısıtlanmalı ve aylık kota/bütçe alarmı kurulmalı. Browser haritaları/Geocoding ücretsiz kota sonrası ücretli olabilir. Haritada önerilen adres PIN'i kullanıcı tarafından doğrulanır, pin elle sürüklenebilir.

Konum otomatik ya da arka planda toplanmaz. Müşterinin customer_addresses ve hizmet verenin provider_profiles enlem/boylam alanları kullanılır; mevcut randevu/bakiye verileri korunur.

## SMS ve SMTP

SMTP: Admin Entegrasyon Merkezi'nde aktif ve test edilmiş olmalı. E-posta OTP 10 dakika geçerli, yanlış deneme 5 ve yeniden gönderme bekleme süresi 60 saniye. OTP gerçek posta kutusuna gönderilir.
Telefon OTP isteğe bağlıdır: Admin'de SMS sağlayıcısını ve sms_events.otp olayını etkinleştir. Kapalıysa telefon SMS'i gönderilmez; e-posta OTP üzerinden devam edilir. SMS operatör tarifesine göre ücretli olabilir.

## Onaylar

Kullanım koşulları kabulü ve KVKK aydınlatma metninin okunduğu teyidi iki ayrı zorunlu checkbox; pazarlama onayı ayrı ve varsayılan kapalı. Eski hesapların oturumları ve admin rolleri değiştirilmedi.

## QA / yayın öncesi

- Uçtan uca e-posta, SMS ve Google/Apple OAuth testleri gerçek sağlayıcı hesapları ile yapılmalı.
- Flutter pub get, flutter analyze, Android imzalı AAB ve iOS IPA build; mağazalarda yeni sürüm gereklidir.
- Webde https://tarak.app/guvenli-kayit.html yolu canlı olmalı ve tüm kayıt butonları bu forma yönlenmeli.
- Backend migrations çalışmadan Laravel dosyalarını devreye alma; ilgili kullanıcılara yeni consent alanları eklenmiştir.
- Eski web kayıt ekranı doğrulama bilmediğinden OTP zorunluluğu yalnızca yeni web + mobil dağıtıldıktan sonra açılmalıdır.
- Bu görevde gerçek cihaz/cihaz emülatörü, canlı hesaplar ve Apple provisioning doğrulanamadı. Uçtan uca üretim testi gereklidir.


## 24 Ekim ekleri — müşteri, uzman ve yakınlık (web + Flutter)

- **Kayıt:** Google / Apple ID token doğrulamasından gelen doğrulanmış isim ve e-posta yalnızca düzenlenebilir ön doldurma alanlarıdır. `/auth/social/preview` *oturum açmaz, hesap oluşturmaz, login token döndürmez*. Apple seçeneği iOS için hazırlanmıştır. Kullanıcı adı/soyadı/e-postayı düzeltebilir; zorunlu e-posta OTP ve açık son onay ile kayıt olur.
- **E-posta OTP:** 6 rakam, 10 dakika, 5 yanlış deneme, 60 saniye yeniden isteme süresi. SMTP canlıda yapılandırılmadan doğrulama e-postası gönderilemez. **SMS OTP** isteğe bağlı; SMS entegrasyonu ve `sms_events.otp` etkin olmadıkça 503 döner; e-posta üzerinden devam edilir.
- **Harita:** Kayıt ekranında müşteri hizmet adresini, hizmet veren işletme adresini yazabilir. Anahtarlar varsa haritada adres eşleştirmesi, sürüklenebilir pin, lat/lng kaydı vardır. Anahtar yoksa elle metin adresi kaydedilebilir; bunun *koordinat doğrulaması anlamına gelmediği* kullanıcıya gösterilir. Kullanıcıdan habersiz konum isteği yoktur.
- **Kayıt sonrası:** Flutter müşteri / Adreslerim / adres düzenle üzerinden pini yeniden seçip aynı adresi günceller. Flutter hizmet veren profilinde "İşletme Konumumu Haritada Düzenle" ile işletme pinini yalnızca sahibi günceller; tam koordinat sadece sahibinin özel profil API yanıtında bulunur.
- **Müşteri ana sayfası:** Web ve mobil "Size Yakın Berberler" 1–50 km kaydırıcısı kullanır. Kayıtlı varsayılan adresin lat/lng'si (veya kullanıcı **açıkça izin verdiyse** cihaz koordinatı) ile `GET /api/providers?sort=distance&lat=...&lng=...&max_distance_km=...` sorgulanır. Sunucu sadece halka açık listelenebilir gerçek hizmet verenleri döndürür, km Haversine ile hesaplanır; koordinatsız uzman filtreye dahil değildir. Koordinat yoksa sahte yakınlık sonucu gösterilmez. Kartlar profil ekranına gider.
- **Web yayını:** `tarak.app/assets/tarak-nearby-providers.js`, değişen `CustomerDashboard-AVc8Kzdf.js`, `index-Bj5sn6If.js`, `tarak.app/index.html` dosyalarının **tamamını** birlikte cPanel'de dağıt. Sadece `git pull` web hosting üzerinde yayın yapmayabilir; senin dağıtım yöntemin geçerli. JS asset cache bust yenilendi.
- **Backend yayını:** `ProviderProfileResource.php` güncellemesini dağıt; kayıt sistemi için `php artisan migrate --force`, `php artisan optimize:clear` çalıştır. Mevcut `.env` / `APP_KEY` değerlerini silme/değiştirme. **Her istemci yeni doğrulama ekranına geçince** `REGISTRATION_VERIFICATION_REQUIRED=true` aç. Aksi halde eski API istemcileri hâlâ OTP zorunluluğunun dışındadır.

### GitHub Actions Secret isimleri

| Secret | Nerede kullanılıyor? |
|---|---|
| `GOOGLE_OAUTH_WEB_CLIENT_ID` | Android/iOS Dart Google Sign-In; aynı Web OAuth Client ID backend `GOOGLE_OAUTH_WEB_CLIENT_ID` ile |
| `TARAK_MAPS_ANDROID_API_KEY` | Android Maps SDK, Gradle `TARAK_MAPS_API_KEY` çevre değişkeni |
| `TARAK_GOOGLE_IOS_CLIENT_ID` | iOS Xcode Google Client |
| `TARAK_GOOGLE_IOS_REVERSED_CLIENT_ID` | iOS Google URL scheme |
| `TARAK_MAPS_IOS_API_KEY` | iOS Google Maps SDK |

Bu değerleri GitHub'daki **Settings > Secrets and variables > Actions** menüsüne özel olarak ekle. Kaynak koda API secret, private key, Apple sertifika veya keystore koyma. API key'leri uygulama paketi/bundle kimliklerine veya web referrer'ına kısıtla. Harita için Google Cloud billing etkinliği, kota ve bütçe uyarısı gerekir. Native Maps yapılandırıldığında release workflow `TARAK_MAPS_ENABLED=true` ile build eder.

### Doğrulama / blokaj bilgisi

- `.github/workflows/tarak-code-health.yml` Flutter analiz + web JS syntax + backend PHP syntax doğrulamaları içindir.
- GitHub Actions'ta iOS ve code-health işlemleri bazen **runner tahsis edilmeden**, adımlar başlamadan `failure` ile kapanabiliyor. Bu durum başarılı derleme ya da derleme hatası olarak yorumlanmamalıdır. Repo **Actions**, organizasyon planı/dakika, GitHub Billing, workflow izinleri ve runner erişimini kontrol et; otomatik kontroller bir runner'da gerçekleşip yeşil olmadan "derlendi/test edildi" denemez.
- Tamamlandı saymak için: çalışan workflow, kayıt / OTP canlı uçtan uca testleri, harita API anahtarlarıyla gerçek cihaz adres pini, hizmet veren profili, yakınlık kartları, her iki mağaza build'i ve cPanel dağıtımı doğrulanmalı.
