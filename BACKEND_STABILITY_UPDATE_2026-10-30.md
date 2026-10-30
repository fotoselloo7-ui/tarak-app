# Tarak backend: kayıt, avatar, yakın konum ve istek sınırı güncellemesi

Bu paket 21 PHP kaynak dosyası içerir. Bunların 11'i altyapı düzeltmelerindeki değişen dosyalardır; 10'u kayıt/OTP ve medya bağımlılıklarının aynı sürümde olması için eklenen mevcut kaynaklardır. Veritabanı, gerçek .env, API secret, uygulama tasarımı ve mağaza paketi içermez.

Google girişinin çözüldüğü kullanıcı tarafından doğrulandı. Bu paket o düzeltmeyi de içerir.

1. Sunucuda artisan dosyasının bulunduğu Laravel kökünü belirleyin. Mevcut ilgili dosyaların yedeğini alın.
2. ZIP içindeki backend/ klasörünün İÇERİĞİNİ aynı yolları koruyarak Laravel köküne yükleyin. backend klasörünü web köküne yeni bir uygulama olarak kurmayın.
3. Mevcut .env dosyasını koruyun. Public Google/Apple client ID değerlerini önceki rapordaki değerlerle kontrol edin. APP_URL=https://tarak.app olmalı.
4. Laravel kökünde php artisan optimize:clear çalıştırın. Sunucuda config cache kullanılıyorsa php artisan config:cache çalıştırın. PHP OPcache eski kaynakları tutuyorsa ilgili PHP uygulamasını panelden yeniden başlatın.
5. Mevcut kayıt ve sosyal doğrulama tabloları kullanılır. Migration veya seed çalıştırmayın; kullanıcı kayıtları ve medya dosyaları taşınmaz/silinmez.
6. Google ile kayıt doldurma, normal e-posta kodu, profil fotoğrafı ve default adres değişimi sonrası yakın listeyi test edin.

Kayıtta e-posta kodu gönderimi izole testlerde array mail transportuyla doğrulandı; gerçek SMTP/SMS teslimatı veya canlı yeni kullanıcı oluşturma bu testlerin kapsamında değildir. iPhone native Apple girişi Windows'ta doğrulanmadı.

manifest.json her dosyanın SHA-256 değerini ve güncelleme kapsamını içerir. Bu paket canlıya otomatik yüklenmedi.

## Paket dosyaları

- `app/Http/Controllers/Api/ConversationController.php`
- `app/Http/Controllers/Api/CustomerProfileController.php`
- `app/Http/Controllers/Api/FavoriteController.php`
- `app/Http/Controllers/Api/PublicProviderController.php`
- `app/Http/Controllers/Api/SocialAuthController.php`
- `app/Models/User.php`
- `app/Services/ConversationService.php`
- `app/Services/SocialIdentityVerifier.php`
- `bootstrap/app.php`
- `config/services.php`
- `routes/api.php`
- `app/Http/Controllers/Api/AuthController.php`
- `app/Http/Requests/RegisterRequest.php`
- `app/Http/Controllers/Api/RegistrationVerificationController.php`
- `app/Services/RegistrationVerificationService.php`
- `app/Support/MediaUrl.php`
- `app/Http/Controllers/Api/PublicMediaController.php`
- `app/Http/Controllers/Api/ProfileMediaController.php`
- `app/Http/Resources/UserResource.php`
- `app/Http/Resources/ProviderProfileResource.php`
- `app/Http/Resources/CustomerProfileResource.php`
