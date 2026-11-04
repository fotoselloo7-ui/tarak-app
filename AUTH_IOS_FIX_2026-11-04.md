# Auth ve iOS dil düzeltmesi — 4 Kasım 2026

> Sonraki canlı teşhiste iki eski sunucu dosyası bulundu. Bu rapordaki üç dosyalık önceki paket kayıt 500 hatasını tek başına çözmez. Kesin exception, canlı şema kontrolü ve iki dosyalık tamamlayıcı paket için `FINAL_AUTH_DIAGNOSIS_2026-11-04.md` raporunu kullanın.

## 1. Kök neden ve yapılan düzeltme

Giriş/kayıt istekleri `throttle:20,1,auth-submit:` ortak sayacına giriyordu. Google/Apple prefill ve login isteklerinde ayrıca `throttle:10,1,auth-sensitive:` vardı. Bu sayaçlar aynı IP'deki işlemleri birlikte saydığından bir işlemdeki hatalar sonraki giriş/kayıt işlemlerini de 429 ile engelleyebiliyordu. Düzeltme öncesi testte art arda yanlış şifre ve tekrar kayıt denemelerinde 429 yeniden üretildi.

Public login, register, Google/Apple prefill ve login üzerinden bu limitler kaldırıldı. Sosyal girişin dolaylı olarak engellenmemesi için config ve nonce uçlarının dakika sınırları da kaldırıldı. Kod gönderme ve kod tahmini uçlarının mevcut spam/güvenlik limitleri korundu.

E-posta, SMS ve şifre yenileme e-postası için yeniden gönderme beklemesi 60 saniyeden **180 saniyeye** çıkarıldı. Bekleme mesajı kalan gerçek saniyeyi gösteriyor. Bu bekleme, gönderilmiş kodu doğrulamaya veya giriş yapmaya engel olmuyor. Mobilde doğrulama penceresi yeniden açıldığında mevcut kod korunuyor; süre bitince yeni kod gönderme kullanıcı tarafından seçiliyor.

Aynı e-posta/telefon ile kayıt zaten Türkçe 422 yanıtı üretiyor. Üretimdeki gibi `app.debug=false` koşulunda, normalize edilmiş aynı e-posta ve telefonla 30'ar tekrar kayıt isteği doğrulandı. Genel hata yakalayıcısını değiştirme yönündeki ilk şüphe ek testte doğrulanmadığı için bu dosyada değişiklik bırakılmadı. Tarihsel canlı 500 hatalarının tamamı, canlı sunucu logları ve cihaz oturumları olmadan kesin olarak açıklanamaz.

`config/cache.php` içindeki varsayılan `file` tercihi ve sabit `limiter => file` düzeltmesi aynen korundu. 429 JSON handler, Google ID token tekrar kullanım düzeltmesi ve Apple nonce/token doğrulaması değiştirilmedi.

iOS tarafında proje geliştirme dili `en` idi; Info.plist geliştirme dili de build değişkenine bağlıydı. Binary dil bildirimi açıkça Türkçe yapıldı. Flutter zaten yalnızca `tr_TR` kullanıyordu; bu ayar korundu.

## 2–3. Değişen dosyaların tamamı ve içerikleri

| Dosya | Değişiklik |
|---|---|
| `tarak-backend/routes/api.php` | Public giriş/kayıt/sosyal giriş ve bunların config/nonce çağrılarından dakika sınırları kaldırıldı. Gönderim ve kod tahmini limitleri korundu. |
| `tarak-backend/app/Services/RegistrationVerificationService.php` | E-posta ve SMS yeniden gönderme beklemesi 180 saniye; hata mesajında kalan gerçek süre. |
| `tarak-backend/app/Http/Controllers/Api/PasswordResetController.php` | Şifre yenileme e-postası yeniden gönderme beklemesi 180 saniye. |
| `mobile/lib/features/auth/screens/register_screen.dart` | Bekleme varsayılanı 180 saniye; pencere yeniden açılınca otomatik kod yenileme kaldırıldı. |
| `mobile/ios/Runner/Info.plist` | `CFBundleDevelopmentRegion=tr`, `CFBundleLocalizations=[tr]`. |
| `mobile/ios/Runner.xcodeproj/project.pbxproj` | `developmentRegion=tr`, `knownRegions=(tr, Base)`. |
| `tarak-backend/tests/Feature/AuthRateLimitTest.php` | Tekrarlanan giriş/kayıt, imzalı Google/Apple istekleri, 180 saniye sınırları ve korunmuş 429 yanıtları için regresyon testleri. |
| `tarak-backend/tests/Feature/AppleIdentityTest.php` | Native token test verisine mevcut doğrulayıcının gerektirdiği test bundle ID eklendi; gerçek credential değişmedi. |
| `tarak-backend/tests/TestCase.php` | Test şeması yalnızca boş SQLite belleğinde `migrate` ile kuruluyor; `migrate:fresh` ve seed çağrılmıyor. Rate limiter testler arasında bellek deposuyla izole ediliyor. |
| `mobile/test/registration_prefill_test.dart` | E-posta/SMS bekleme, beklerken doğrulama ve pencereyi yeniden açınca kodu koruma testleri. |
| `AUTH_IOS_FIX_2026-11-04.md` | Bu teslim ve doğrulama raporu. |

UI/tasarım, avatar, adres, mesafe, hizmet ikonları, randevu, ödeme, Firebase, Reverb, gerçek OAuth kimlikleri, .env ve sürüm adı değiştirilmedi. Kayıt onayları, şifre kuralları, kodların 10 dakikalık geçerliliği, hatalı kod deneme sınırları ve tek kullanımlık kanıt/nonce kuralları korundu. Kullanıcı verisi silinmedi; gerçek veritabanına migration veya seed uygulanmadı.

## 4. Test sonuçları

- İstenen dört PHP syntax kontrolü başarılı: `routes/api.php`, `config/cache.php`, `SocialIdentityVerifier.php`, `AuthController.php`. Değişen diğer iki backend PHP dosyası da syntax kontrolünden geçti.
- `php artisan route:list --path=auth -vv`: login/register/social prefill/login/config/nonce üzerinde throttle yok; gönderimlerde `5,1`, doğrulama/reset uçlarında mevcut `10,1` korunuyor.
- Auth odaklı backend: **30 test, 1209 assertion başarılı**.
- 30 yanlış şifre isteği 401, 30 eksik giriş isteği 422; ardından doğru giriş 200. 429/500 yok.
- Aynı normalize e-posta ve aynı telefon için 30'ar kayıt isteği 422 ve Türkçe alan hataları. Ek hesap/token oluşmuyor.
- Google ve Apple için ayrı ayrı 30 prefill + 30 login isteği, gerçek RSA imza doğrulamasıyla 200. Google'da aynı geçerli ID token yeni nonce ile tekrar kullanılıyor. Yeni Google kullanıcısı prefill → register akışını 201 ile tamamlıyor.
- Apple yanlış audience/issuer/expiry/nonce/imza, nonce tekrarı ve web authorization-code eşleştirme regresyonları geçti. Başka kullanıcıya bağlı subject'in yeniden atanamaması testleri geçti.
- E-posta ve SMS: ilk gönderim 180 saniye döndürüyor; 179. saniyede yeniden gönderim engelleniyor; 180. saniyede izin veriliyor. Gönderim beklerken kod doğrulama başarılı. Şifre yenileme e-postasında da aynı sınır kontrol edildi.
- Gönderim uçlarında spam limiti 429, Türkçe mesaj ve `Retry-After` ile dönüyor; login bundan etkilenmiyor.
- Mobil auth/stabilite: **27 test başarılı**.
- Son `flutter analyze --no-pub`: **No issues found**.
- iOS plist XML okuması ve `tr`/`Base` proje ayarları otomatik doğrulandı; `git diff --check` temiz.

Testler uygulamanın gerçek Laravel HTTP kernel/middleware/controller/verifier akışını kullanıyor. Dış Google/Apple anahtar sunucuları test anahtarlarıyla, SMS sağlayıcısı test taklidiyle ve e-posta bellek transportuyla izole edildi. Canlıya istek gönderilmedi, gerçek SMS/e-posta atılmadı, gerçek cihazda Google/Apple SDK oturumu açılmadı. Windows ortamında iOS archive/build çalıştırılamadı.

Tam paketlerde kapsam dışı sonuçlar:

- Backend: **55 testin 51'i geçti, 4'ü başarısız**. `AvatarConsistencyTest` medya dosyası okunabilirliği (`File must be readable`); `DemoIntegrityTest` içinde demo görünürlüğü ve gerçek puan beklentilerine ait 3 hata. Bu alanlara dokunulmadı.
- Mobil: **463 test geçti, 1 hata**. `customer_account_screens_test.dart:111`, hizmet ikonu eşleşmesi: beklenen `U+0F795`, gelen `U+0F659`. İkonlar değiştirilmedi.

## 5. cPanel'e yüklenecek SADECE backend dosyaları

Backend uygulamasının kök dizinine göre:

```text
routes/api.php
app/Services/RegistrationVerificationService.php
app/Http/Controllers/Api/PasswordResetController.php
```

Bu üç dosya `.tools/tarak-auth-resend-180-backend-2026-11-04.zip` içinde aynı dizin yapısıyla paketlendi. Testleri, mobil dosyaları, .env veya veritabanı dosyalarını cPanel'e yüklemeyin. Paket, repoda mevcut file-cache düzeltmesinin sunucuda da bulunduğu sürüm üzerine hazırlanmıştır.

## 6. cPanel minimum komutları

Backend kök dizininde:

```sh
php artisan config:clear
php artisan route:clear
php artisan config:cache
```

Bu değişiklikler için migration, seed, dependency kurulumu veya genel cache silme gerekmiyor. Canlı sunucuya yükleme/komut çalıştırma bu görevde yapılmadı.

## 7–8. iOS dosyaları ve TestFlight

iOS değişiklikleri yalnızca `mobile/ios/Runner/Info.plist` ve `mobile/ios/Runner.xcodeproj/project.pbxproj` içindedir. Dilin mevcut App Store binary'sinde değişmesi için **yeni iOS build ve TestFlight/App Store yüklemesi gerekir**. Sürüm adı değiştirilmedi; yükleme sırasında yeni build numarası kullanılmalıdır. Mobil doğrulama penceresi iyileştirmesi de yeni mobil build ile cihazlara ulaşır. Backend deneme sınırı düzeltmesi ise sunucuya yüklenince mevcut uygulamalara da uygulanır.

## 9. App Store Connect manuel adımı

Binary localization ile App Store Connect metadata dili ayrıdır. Kod değişikliği mağaza kaydının Primary Language alanını kendiliğinden değiştirmez.

**App Information → Primary Language / Localizations** bölümünde Türkçe localization yoksa eklenmeli. Türkçe localization App Review tarafından uygun hale geldikten sonra mümkünse Primary Language Türkçe yapılmalı. Mağaza metadata'sı bu görevde değiştirilmedi.

## 10. Git commit/push summary

```text
fix(auth): remove public auth throttles, enforce 180s resend and set iOS Turkish locale
```

Commit/push yapılmadı; değişiklikler mevcut çalışma kopyasında incelemeye hazır.
