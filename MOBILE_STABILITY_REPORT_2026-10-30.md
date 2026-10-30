# Tarak mobil altyapı düzeltmeleri — 30 Ekim 2026

Çalışma klasörü: `C:\Projeler\TARAK-APP-FINAL-KAYNAK`
Dal: `codex/mobile-stability-pixel9`
Başlangıç: `aafbfb29751549f9abdac53e3a84c938f88d4136`

Son kullanıcı talimatı gereği buton, tema, renk, ölçü ve ekran yerleşimleri değiştirilmedi. Avatar alanlarına eksik fotoğraf verisi bağlandı ve hata fallback'i eklendi. Sürüm **1.1.1+6** korundu. AAB, IPA/TestFlight veya mağaza yayını üretilmedi. Canlı backend'e dosya yüklenmedi. Gerçek `.env`, anahtarlar ve kullanıcı verileri commit edilmedi. Testler yalnız SQLite `:memory:` veritabanını kullandı; mevcut kullanıcı kayıtları silinmedi veya yeniden üretilmedi.

## Kök nedenler ve düzeltmeler

- **Google:** Başlangıç kodu e-posta üzerinden otomatik bağlamayı zaten içeriyordu. Eksik olan güvenli eşzamanlı ilk giriş ve silinmiş hesaba bağlı subject kontrolü güçlendirildi. Subject başka hesaba aitse yeniden atanmaz; doğrulanmamış e-posta ve pasif hesapla bağlantı/token oluşturulmaz. Doğrulanmış eşleşme parola istemeden token verir. Yeni e-posta anlaşılır kayıt mesajı alır. İmzalı doğrulama sonucu oluşturulan prefill kanıtıyla ad/soyad/e-posta gelir; aynı doğrulanmış e-posta için ikinci OTP gerekmez, değiştirilmiş e-posta için gerekir. Native Android SDK'ya server/web client ID gönderilir; Android OAuth ID'si clientId yerine geçirilmez. SDK başlangıç hatasından sonra yeniden denemeye izin verilir. Aynı anda ikinci sosyal giriş engellenir.
- **Canlı Google config:** Salt okunur kontrolde Web ID doğru; `google_ios_client_id` alanı **null**. iOS `Info.plist` içine kullanıcı tarafından verilen public `GIDClientID` ve `GIDServerClientID` eklendi; mevcut reversed URL scheme doğrulandı. Backend example iOS env'si zaten doğru ID içeriyordu. Canlı env'de GOOGLE_IOS_CLIENT_ID ayrıca tanımlanmalı ve config cache yenilenmeli.
- **Firebase Android dosyası:** `mobile/android/app/google-services.json` doğru package içeriyor fakat `oauth_client` sayısı **0**. Firebase'den güncel gerçek dosya indirilmesi gerekiyor; credential uydurulmadı. Açık `serverClientId` kullanımı kodda var. Yerel debug SHA-1: `CF:F1:AA:DE:10:A7:2F:CD:88:9C:44:B8:81:B6:CF:17:6A:CC:BE:CD`. Kullanıcının verdiği Play SHA-1 farklı: `E7:97:EE:02:F8:6E:A5:91:CD:35:D4:D5:EB:68:4E:A8:2A:51:E8:A9`. Pixel 9 Google girişinin tamamlanması için debug imzasına ait Android OAuth tanımının da Google projesinde bulunması gerekir; bulutta kayıtlı olup olmadığı bu görevde değiştirilmedi/doğrulanmadı.
- **Apple:** Başlangıç verifier'ında native bundle audience ile web Service ID ayrımı zaten mevcuttu; yerelde native akışı web secret'ına zorlayan yeni bir hata görülmedi. Native RSA imzası, issuer, audience, süre, nonce ve replay kontrolleri gerçek imzalı test tokenlarıyla doğrulandı. Web code exchange korunarak dönen tokenın zorunlu expiration kontrolü eklendi. Apple'ın yalnız ilk izin sırasında ayrı credential alanlarında verdiği ad/soyad kayıt formuna taşındı. Bundle, entitlement ve URL scheme incelendi; gerçek Apple hesabı/iPhone testi yapılmadı. Canlı Apple Service ID doğru dönüyor.
- **Avatar:** Ana sayfa başlığında ve teklif kartında modeldeki avatar URL'si widget'a hiç gönderilmiyordu. Favoriler API'si avatar kolonunu seçmiyor/döndürmüyordu. Sohbetler hizmet verenin kapak fotoğrafını veya eski customer_profile fotoğrafını kullanıyordu. Hepsi `users.avatar_url` ile birleştirildi. User model accessor'ı API ve ham model serialization'ında mevcut MediaUrl normalizasyonunu kullanıyor. Eski müşteri profil güncellemesi de canonical alanı güncelliyor. Home kart cache'leri avatar değişikliğini izliyor. AvatarPicker'da galeri açılışında yanlışlıkla false yapılan busy durumu, dosya erişimi, iptal ve dispose sonrası işlem sorunları düzeltildi. AvatarPicker, mesaj ve randevu görselleri başarısız URL'de baş harfe düşer. Profil yükleme sonucu auth state'i günceller; sonraki `/auth/me` aynı URL'yi döndürür.
- **Yakındakiler:** Backend, koordinatsız default adresi atlayıp eski koordinatlı adrese düşüyordu. Mobil, default yoksa başka adresi seçiyor ve async refetch sırasında eski değeri gösterebiliyordu. Artık açıkça seçilen cihaz konumu > yalnız default adres; default koordinatsızsa origin yok. Refresh sırasında eski origin kullanılmaz. Cihaz konumu oturum değişince sıfırlanır; çıkış sonrası gecikmiş GPS yanıtı reddedilir. Adres provider'ının otomatik tekrar fırtınası kapatıldı; kullanıcı tekrar deneyebilir. Mevcut adres düzenleme invalidation'ı korundu. Mahmutlar→Şişli API ve Riverpod testlerinde yeni lat/lng/radius ile yeniden istek ve doğru mesafe/sıra doğrulandı; koordinatsız işletme yakın listede öne çıkmıyor. Mevcut Photon/OpenStreetMap harita altyapısı korundu; eski Google fixture'ları buna uyarlandı.
- **Android launcher:** MainActivity launcher'ı başlangıç commit'inde zaten vardı. Debug manifestinde alias launcher filtreleri de miras kalıyor, iki launcher oluşabiliyordu. Debug overlay yalnız alias filtrelerini kaldırır. Birleşmiş debug manifestinde tek MainActivity, release manifestinde 10 alternatif alias ve yalnız bir etkin launcher (`IconAltin`) var. Release ikonları ve MainActivity export/launchMode/theme değerleri korundu.
- **429:** Laravel sayısal throttle middleware'leri boş prefix nedeniyle farklı limitlerde aynı request-signature sayacını paylaşıyordu; iç içe auth limitleri aynı sayacı iki kez tüketebiliyordu. Bootstrap, nonce, auth submit, hassas işlem, send ve medya için ayrı prefix'ler eklendi; limitler kaldırılmadı. API 429 yanıtı Retry-After ile Türkçe döner. Flutter ham framework mesajını çevirirken işlem/kod kilidi gibi anlamlı backend mesajlarını korur. Sosyal giriş ve doğrulama handler'larına aynı karede çift tıklama koruması eklendi.

## Doğrulama

| Kontrol | Sonuç |
|---|---|
| flutter pub get | Geçti |
| flutter analyze | No issues found |
| flutter test --no-pub | **448 geçti, 0 başarısız**; başlangıç 435 geçti / 5 başarısızdı |
| İlgili backend auth/Apple/avatar/geo/rate-limit testleri | **27 geçti, 178 assertion** |
| Tam backend test kümesi | **30 geçti, 3 başarısız**, 196 assertion |
| Değişen PHP dosyaları php -l | Geçti |
| Kaynak UTF-8 / git diff --check | Geçti |
| processDebugMainManifest + processReleaseMainManifest | BUILD SUCCESSFUL; her varyantta tek etkin launcher |
| Android signingReport | Geçti; debug imzası yukarıda |
| iOS plist parse / URL scheme ve public client ID eşleşmesi | Geçti; iOS derleme yapılmadı |

Üç backend hatası `DemoIntegrityTest` içindeki demo işareti ve yalnız gerçek yorumlar beklentileridir. Bu davranışa dokunulmadı. Başlangıç commit'indeki User modeliyle ayrı karşılaştırmada aynı üç hata tekrar üretildi (`.tools/pixel9-demo-baseline.log`); mevcut ProviderProfileResource zaten `is_demo=false` döndürüyor. Testleri yeşile çevirmek için gerçek kayıtların davranışı değiştirilmedi.

Test kanıtları yerel `.tools/` klasöründe: `pixel9-pubget.log`, `pixel9-final-analyze.log`, `pixel9-final-tests.log`, `pixel9-backend-targeted-final.log`, `pixel9-backend-final.log`, `pixel9-demo-baseline.log`, `pixel9-manifests.log`, `pixel9-signing.log`, `pixel9-flutter-run.log`, `pixel9-run-rebuilt.log`. Bu geçici günlükler commit edilmez.

## Pixel 9 senaryoları — otomatik test ile gerçek cihaz ayrımı

| Belgedeki senaryo | Gerçekte doğrulanan |
|---|---|
| 1. Launch | `Pixel_9`, emulator-5554 üzerinde debug APK derlendi/kuruldu; çalışan ana sayfa ve profil ekranı görüldü. ADB tek launcher MainActivity ve sürüm 1.1.1+6 doğruladı. |
| 2. Google hesap seçimi | **Pixel 9’da gerçek Google “Choose an account” penceresi açıldı.** Hesap seçimi kullanıcıya bırakıldı; bir hesaba agent tarafından tıklanmadı. |
| 3. Mevcut Google e-postasıyla doğrudan giriş | Backend testinde geçti; gerçek Google hesabıyla canlı uçtan uca yapılmadı. |
| 4. Google prefill ve OTP atlama | Backend testinde geçti; gerçek cihaz hesabıyla yapılmadı. |
| 5. Avatar upload | İzole API testinde gerçek PNG dosyası yüklenip medya URL'si okundu; mevcut kalıcı profil fotoğrafı Pixel 9 profilinde görüldü. Canlı hesaba yeni fotoğraf yüklenmedi. |
| 6. Aynı avatar yakın/favori/profil/mesaj kartında | Backend testinde aynı URL ve Flutter hata fallback testleri geçti; yeni fotoğrafla canlı kart uçtan uca yapılmadı. |
| 7. Default Mahmutlar→Şişli | İzole API + Riverpod tests: geçti; canlı adres değiştirilmedi. |
| 8. Yeni distance_km | API gerçek mesafe sorgusu ve sıralama testleri geçti; canlı hesapla adres değişimi yapılmadı. |
| 9. iOS buton görünümü | Mevcut GoogleAuthButton ve tema değiştirilmedi. Gerçek iOS render/cihaz testi yapılmadı. |
| 10. 429 Türkçe | API + Flutter testleri geçti; canlı sunucuya spam gönderilmedi. |

Flutter'ın ilk resident çalıştırması uygulamayı açtı fakat otomatik VM keşfi bekledi; mevcut VM adresiyle attach başarılı oldu. Sonraki attach oturumunda dart-define'lar devralınmadan yapılan hot restart giriş ekranına döndürdü; production parametreleriyle yeniden debug çalıştırması yapıldı. Geçici incremental APK paketleme çakışması Flutter clean + pub get sonrası giderildi; son `flutter run --no-resident` doğru production dart-define değerleriyle exit 0 verdi, debug APK kuruldu ve tek launcher tekrar doğrulandı. Son durumda uygulama Google hesap seçimi penceresindedir; önceki oturum tekrar giriş gerektiriyor. Hesap seçimi için kullanıcıdan sonuç istendi. Bunlar test çalıştırma notlarıdır; kaynak tasarımı değiştirilmedi.

## Canlı sunucuya yüklenecek değişen backend dosyalarının TAM listesi

Aşağıdaki yollar repo köküne göredir. Test dosyaları ve `.env.example` çalışma zamanı dağıtım dosyası değildir. Gerçek `.env` dosyasının üzerine örnek dosyayı yazmayın.

- `tarak-backend/app/Http/Controllers/Api/ConversationController.php`
- `tarak-backend/app/Http/Controllers/Api/CustomerProfileController.php`
- `tarak-backend/app/Http/Controllers/Api/FavoriteController.php`
- `tarak-backend/app/Http/Controllers/Api/PublicProviderController.php`
- `tarak-backend/app/Http/Controllers/Api/SocialAuthController.php`
- `tarak-backend/app/Models/User.php`
- `tarak-backend/app/Services/ConversationService.php`
- `tarak-backend/app/Services/SocialIdentityVerifier.php`
- `tarak-backend/bootstrap/app.php`
- `tarak-backend/config/services.php`
- `tarak-backend/routes/api.php`

Env kontrolü: GOOGLE_WEB_CLIENT_ID, GOOGLE_ANDROID_CLIENT_ID, GOOGLE_IOS_CLIENT_ID, APPLE_BUNDLE_ID ve APPLE_SERVICE_ID `.env.example` içindeki kullanıcı tarafından verilen public değerlerle eşleşmeli. APP_URL `https://tarak.app` olmalı. Apple web code exchange için mevcut secret/redirect bilgileri sunucuda korunmalı. Dosya/env güncellemesi ardından sunucuda `php artisan optimize:clear` ve `php artisan config:cache` çalıştırılmalı. Bu görevde migration veya veri sıfırlama yok. Bu 11 dosya bu çalışma serisindeki runtime değişiklikleridir; MediaUrl, public medya endpoint'i, sosyal kimlik tabloları ve mevcut resources başlangıç kaynakta zaten bulunuyordu.

## Değişen mobil dosyalar

- `mobile/android/app/src/debug/AndroidManifest.xml`
- `mobile/android/app/src/main/AndroidManifest.xml`
- `mobile/ios/Runner/Info.plist`
- `mobile/lib/core/network/api_exception.dart`
- `mobile/lib/features/auth/screens/login_screen.dart`
- `mobile/lib/features/auth/screens/register_screen.dart`
- `mobile/lib/features/auth/services/social_identity_service.dart`
- `mobile/lib/features/chat/widgets/conversation_card.dart`
- `mobile/lib/features/customer/providers/home_content_providers.dart`
- `mobile/lib/features/customer/providers/instant_request_provider.dart`
- `mobile/lib/features/customer/providers/provider_list_origin.dart`
- `mobile/lib/features/customer/screens/customer_home_tab.dart`
- `mobile/lib/features/customer/screens/favorites_screen.dart`
- `mobile/lib/features/customer/screens/offers_screen.dart`
- `mobile/lib/features/provider/appointments/screens/provider_appointment_detail_screen.dart`
- `mobile/lib/features/provider/appointments/screens/provider_appointments_tab.dart`
- `mobile/lib/features/shared/widgets/avatar_picker.dart`
- `mobile/test/customer_home_logo_test.dart`
- `mobile/test/mobile_stability_test.dart` (yeni regresyon testleri)

Backend regresyon testleri: `AppleIdentityTest.php`, `AuthRateLimitTest.php`, `AvatarConsistencyTest.php`, `SocialLoginLinkTest.php` eklendi; `GeoApiTest.php` güncellendi.

Yerel kod commit serisi: `c673d21` (auth/rate limit), `5a4084e` (backend avatar/default adres), `0d0e2a7` (mobil veri/yaşam döngüsü/native config).

Gerçek hesap seçimi, computer-use becerisinin zorunlu okuttuğu `guidance.md` içindeki “Do not automate user authentication dialogs” kuralı nedeniyle kullanıcıya bırakıldı. Bu kural kod/test işlerinin bitirilmesini engellemedi; yalnız gerçek hesabın seçilmesi ve sonraki canlı giriş sonucu bekleniyor. iOS native cihaz doğrulaması ayrıca Windows ortamında yapılamadı.

Teknik referanslar: [Google backend ID token doğrulaması](https://developers.google.com/identity/sign-in/android/backend-auth), [Apple kullanıcı doğrulaması](https://developer.apple.com/documentation/signinwithapple/verifying-a-user), yerelde kurulu `google_sign_in_ios-6.3.8/README.md` native GIDClientID/GIDServerClientID yapılandırması.
