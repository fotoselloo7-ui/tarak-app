# Final auth teşhisi — 4 Kasım 2026

## 1–2. Canlı kayıt 500 hatasının gerçek nedeni ve exception

Açık cPanel terminalinden bugünkü `storage/logs/laravel-2026-11-04.log` okundu. Eski `laravel.log` yalnızca 22 Ekim tarihli kayıtlar içeriyordu; güncel kayıt hatası daily log dosyasındaydı.

4 Kasım 22:29:48, 22:33:57 ve 22:38:38 kayıtlarında:

```text
BadMethodCallException:
Method App\Http\Requests\RegisterRequest::isLegacyNativeClient does not exist.
```

4 Kasım 22:33:38 ve 22:38:16 kayıtlarında:

```text
Error:
Call to undefined method App\Http\Controllers\Api\RegistrationVerificationController::config()
```

**Kök neden sunucudaki kısmi/uyumsuz auth dağıtımıdır.** Güncel `AuthController` eski `RegisterRequest` üzerinde olmayan metodu çağırıyor. Güncel route ve mobil uygulama da eski doğrulama controller'ında bulunmayan `config()` metodunu çağırıyor. İlki kayıt başlamadan 500'e, ikincisi doğrulama yapılandırmasını okurken 500'e neden oluyor. Bunlar validation hatası değildir; 422 gibi gösterilerek gizlenmedi.

Canlı dosyaların SHA-256 özetleri yerel kaynakla karşılaştırıldı:

| Dosya | Canlı durum |
|---|---|
| `app/Http/Requests/RegisterRequest.php` | Eski; `isLegacyNativeClient()` yok. Canlı SHA-256: `72735282f4723cce0a8bb9ae010ff10ed0300ec52fb417c017a22bcfb073df13` |
| `app/Http/Controllers/Api/RegistrationVerificationController.php` | Eski; `config()` yok. Canlı SHA-256: `f601717b5d3218f14f95a813fe4e404d581a918c385eedfc0fbeec94695649b32d` |
| `app/Http/Controllers/Api/AuthController.php` | Yerel dosyayla aynı |
| `app/Services/RegistrationVerificationService.php` | Yerel dosyayla aynı; gerekli SMS config metodu mevcut |
| `app/Http/Controllers/Api/SocialAuthController.php` | Yerel dosyayla aynı |
| `app/Services/SocialIdentityVerifier.php` | Yerel dosyayla aynı |
| `config/cache.php` | Yerel dosyayla aynı |
| `routes/api.php` | Yerel dosyayla aynı |

Önceki üç dosyalık paket bu iki eski dosyayı içermediği için canlı kayıt hatasını çözemiyordu. Bu görevde yeni bir backend iş kuralı icat etmek yerine, repoda zaten mevcut ve test edilmiş doğru iki dosya ayrı bir tamamlayıcı pakete alındı.

## 3. Dosyalar ve teslim paketi

Bu çalışmada değişen/eklenen repo dosyaları:

| Dosya | Değişiklik |
|---|---|
| `mobile/lib/features/auth/services/social_identity_service.dart` | Sessiz Google hesabı geri yükleme kaldırıldı; manuel sign-out → authenticate ve Türkçe iptal mesajı. |
| `mobile/test/google_account_picker_test.dart` | Hesap değiştirme, interaktif çağrı sırası, iptal sonrası güvenli tekrar, login/prefill gönderilmemesi ve Android Apple görünürlüğü testleri. |
| `tarak-backend/tests/Feature/RegistrationFlowTest.php` | Production hata ayarıyla manuel PROVIDER kaydı, Google prefill → PROVIDER, eksik/hatalı/süresi geçmiş proof ve iOS header sınıflandırma testleri. |
| `scripts/package-auth-hotfix.py` | Canlıda eski olduğu doğrulanan iki dosyanın uyum kontrolleriyle paketlenmesi ve byte/SHA-256 doğrulaması. |
| `AUTH_IOS_FIX_2026-11-04.md` | Önceki paketin yeni bulunan kayıt hatasını çözmediğine dair yönlendirme. |
| `FINAL_AUTH_DIAGNOSIS_2026-11-04.md` | Bu rapor. |

**Sunucuya yüklenecek mevcut repo dosyaları yalnızca şunlardır:**

```text
app/Http/Requests/RegisterRequest.php
app/Http/Controllers/Api/RegistrationVerificationController.php
```

Paket: `.tools/TARAK-CPANEL-FINAL-AUTH-FIX-2026-11-04.zip`.

Hedef dizin: `/home/alac6ayazilimtr/tarak-backend`. ZIP doğrudan bu dizinde açılmalı; içindeki `app/` dizini mevcut `app/` ile birleşmeli. Mobil dosya, .env, kullanıcı verisi, migration, OAuth credential, verifier veya başka feature pakette yoktur.

Paketteki doğru sürümlerin SHA-256 değerleri:

```text
8e14af86b1eff171ac777dff7c8c0d118213754b1844e3dac1e81f2b2f959e3d  app/Http/Requests/RegisterRequest.php
569f2737e397adc44376181e646f2ee0a57da8ef1b06cca3ad849413f64ae70a  app/Http/Controllers/Api/RegistrationVerificationController.php
```

Canlıda bu oturumda yalnızca teşhis yapıldı; dosya yükleme/değiştirme yapılmadı. İki dosya dağıtıldıktan sonraki gerçek cihaz kaydı henüz doğrulanmadı.

## 4. Migration ve canlı şema kontrolü

**Migration gerekmiyor.** cPanel terminalinde `2026_10_30_110000_create_registration_security_tables` `[4] Ran` olarak görüldü. `db:table --json` ile gerçek canlı şema salt okunur incelendi:

- `users`: role, first_name, last_name, name, email, phone, password, gender, status, email_verified_at, phone_verified_at ve modelin kullandığı diğer alanlar mevcut. Email ve phone unique indexleri mevcut.
- `registration_consents`: user_id, terms_accepted_at, kvkk_acknowledged_at, marketing_consented_at, terms_version, kvkk_version, created_at, updated_at mevcut. user_id unique.
- `registration_verifications`: channel, destination_hash, code_hash, proof_hash, attempts, expires_at, resend_after, verified_at, consumed_at ve timestamps mevcut. channel+destination_hash unique.
- `social_auth_attempts`: token_hash, provider, subject, email, email_verified, first_name, last_name, expires_at, consumed_at ve timestamps mevcut. token_hash unique.
- `social_identities`: user_id, provider, subject, email_at_link ve timestamps mevcut. provider+subject ve user_id+provider unique indexleri mevcut.
- `customer_profiles`, `provider_profiles`, `wallets`, `personal_access_tokens` gerekli kolonlarıyla mevcut. Profile/wallet tablolarının user_id unique indexleri mevcut.
- Profile/wallet tablolarında otomatik id dışında varsayılanı olmayan zorunlu alan yalnızca user_id; kayıt ilişkileri bunu sağlıyor. Consents tablosunun zorunlu onay tarihlerini AuthController sağlıyor.

Repodaki eski `database/tarak-full-production.sql` dört yeni auth tablosunu içermiyor; ancak canlıdaki uygulanmış migration bu farkı zaten kapatmış. Eski SQL dosyası canlıya yeniden aktarılmamalı. Gerçek veritabanına migration, seed, veri silme veya schema değişikliği uygulanmadı.

## 5. Production komutları

Asıl işlem iki eski PHP dosyasını doğru sürümleriyle değiştirmektir. Sadece cache komutlarını tekrarlamak bu metotları oluşturmaz. Yeni migration, dependency kurulumu veya config değişikliği yoktur.

Dosyaları yükledikten sonra:

```sh
cd /home/alac6ayazilimtr/tarak-backend
php -l app/Http/Requests/RegisterRequest.php
php -l app/Http/Controllers/Api/RegistrationVerificationController.php
sha256sum app/Http/Requests/RegisterRequest.php app/Http/Controllers/Api/RegistrationVerificationController.php
curl -sS -H 'Accept: application/json' -w '\nHTTP %{http_code}\n' https://tarak.app/api/auth/verification/config
```

Son çağrı 200 ve `success: true`, `data.sms_enabled` içeren JSON dönmeli. Ardından cihazdan normal kayıt tekrar kontrol edilmeli. Güncel hata aranacak dosya `storage/logs/laravel-2026-11-04.log` dosyasıdır.

## 6–7. Google account picker nedeni ve düzeltmesi

`google_sign_in` kilitli sürümü **7.2.0**. Önceki kod manuel login/prefill düğmelerinde `attemptLightweightAuthentication()` çağırıyor, daha önce kullanılan hesabı geri yükleyebiliyordu. Bu durumda interaktif seçim çağrısı atlanıyordu.

Manuel akış artık mevcut tek seferlik initialize/clientId/serverClientId düzenini koruyarak:

```dart
await signIn.signOut();
final account = await signIn.authenticate();
```

şeklinde interaktif işlem başlatıyor. Paket kaynak kodu ve Flutter'ın resmi migration dokümanındaki API kontrol edildi: https://github.com/flutter/packages/blob/main/packages/google_sign_in/google_sign_in/MIGRATION.md

`GoogleSignInExceptionCode.canceled` güvenli `AppException` olarak “Google ile giriş iptal edildi.” mesajına çevriliyor. İptalde login/prefill POST isteği gönderilmiyor; başlangıç nonce/config GET çağrıları yapılmış olabilir. Meşgul durumu temizleniyor ve yeniden denenebiliyor.

Google/Apple token doğrulaması, nonce, audience/issuer, identity ilişkilendirme, Android'de Apple'ın gizlenmesi, iOS Türkçe localization ve buton tasarımı değiştirilmedi. Otomatik kullanıcı oluşturma eklenmedi.

## 8–11. Kayıt ve Google test sonuçları

| Senaryo | Sonuç |
|---|---|
| Normal e-posta kodu gönderme → kod doğrulama → CUSTOMER kayıt | 201; doğrulanmış kullanıcı, consent, profil ve oturum |
| Normal e-posta → PROVIDER kayıt | 201; doğrulanmış kullanıcı, pending profil, sıfır bakiye cüzdan ve consent |
| Eksik, hatalı veya süresi geçmiş verification proof | 422; kısmi kullanıcı/profil/consent/token oluşmuyor |
| Google prefill → CUSTOMER kayıt | Başarılı; doğrulanmış e-postaya ikinci kod gerekmiyor |
| Google prefill → PROVIDER kayıt | 201; aynı doğrulanmış subject bağlanıyor |
| Mevcut Google hesabı girişi | Başarılı; tekrarlı geçerli ID token/yeni nonce regresyonu da geçiyor |
| Kayıtlı olmayan Google hesabı | 409; kendiliğinden kullanıcı veya oturum oluşturulmuyor |
| Yanlış hesaba bağlı subject / iki kullanıcıya aynı subject | Reddediliyor; mevcut bağlantı korunuyor |
| Apple signature/audience/issuer/expiry/nonce ve web code-exchange | Regresyonlar geçti |
| Farklı Google hesabı seçimi | Platform SDK taklidinde iki farklı seçimin farklı tokenları kullanılıyor; her manuel işlem signOut → authenticate |
| Login ve prefill picker iptali | Türkçe mesaj, crash yok, login/prefill POST yok, tekrar deneme açık |
| Android login/register Apple butonu | Gizli |
| Yeni iOS header/payload sınıflandırması | X-Tarak-Client ile secure flow; header yokken consent payload'ı da legacy bypass'a girmiyor |

`_emailProof` → `email_verification_token` ve `_socialProof` → `social_prefill_token` zincirleri mobil kayıt payload testleriyle doğrulandı. Kaynakta Dio `X-Tarak-Client: mobile-secure-v2` gönderiyor. Gerçek Build 10 cihaz isteğinin raw header kaydı alınmadı; farklı iOS/Dart header davranışları yerel HTTP testleriyle kapsandı.

## 12–13. Çalıştırılan kontroller

```sh
php artisan test --filter='RegistrationFlowTest|RegistrationSecurityTest|AuthRateLimitTest|SocialLoginLinkTest|AppleIdentityTest|TestIsolationTest' --colors=never
```

**34 test, 1259 assertion başarılı.** Testler yalnızca izole SQLite belleğinde çalıştı. Production üzerinde test kullanıcısı oluşturulmadı.

```sh
flutter test --no-pub test/google_account_picker_test.dart test/registration_flow_test.dart test/registration_prefill_test.dart test/preauth_flow_test.dart test/mobile_stability_test.dart
flutter analyze --no-pub
```

**33 mobil test başarılı. Flutter analyze: No issues found.**

Backend feature testleri gerçek Laravel HTTP kernel/middleware/controller/transaction akışını kullanıyor; dış Google/Apple anahtarları ve SMS/e-posta test ortamında izole. Mobil seçim/iptal testleri gerçek paket katmanının platform test arayüzünü kullanıyor. Birden fazla gerçek Google hesabıyla fiziksel iPhone seçim ekranı henüz kontrol edilmedi.

**Google picker düzeltmesinin telefona ulaşması için yeni iOS/TestFlight ve Android build gerekir.** Sunucudaki iki dosya düzeltmesi mevcut uygulamalara yeni build olmadan uygulanabilir. Sürüm adı, gerçek credential'lar ve Apple auth değiştirilmedi. Commit/push yapılmadı.
