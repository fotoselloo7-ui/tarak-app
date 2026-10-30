# Google giriş hatası — canlı backend güncellemesi

30 Ekim 2026 / kod commit'i: c673d21

Pixel 9 gerçek denemesinde Google hesabı başarıyla alındı. Sonrasında Tarak API'si
“Bu sağlayıcı hesabı mevcut bir Tarak hesabına bağlı değil. Önce kayıt olun veya şifrenizle giriş yapıp hesabınızı bağlayın.”
mesajını döndürdü. Bu metin güncel yerel controller'da bulunmuyor. Canlıda eski backend davranışı çalışıyor; yeni mobil APK tek başına bunu değiştiremez.

Bu paket yalnız bu Google giriş problemi için gereken güncel `SocialAuthController.php` dosyasını içerir. Tasarım dosyası, gerçek .env, veritabanı, credential veya mağaza paketi içermez. Daha önce raporlanan diğer 10 backend dosyasının dağıtımı ayrıca gereklidir; bu küçük paket bütün altyapı güncellemelerinin yerine geçmez.

Uygulama:

1. Canlı sunucuda `artisan` dosyasının bulunduğu Laravel kökünü açın. Web kökündeki statik dosyalar klasörü farklı olabilir.
2. Mevcut `app/Http/Controllers/Api/SocialAuthController.php` dosyasının yedeğini alın.
3. ZIP içindeki aynı yoldaki dosyayı bu dosyanın üzerine yükleyin.
4. Laravel kökünde `php artisan optimize:clear` çalıştırın. Sunucuda config cache kullanılıyorsa ardından `php artisan config:cache` çalıştırın.
5. PHP OPcache timestamp kontrolü kapalıysa barındırma panelinden ilgili PHP uygulamasını yeniden başlatın. Mobil uygulamayı yeniden derlemek gerekmez.
6. Pixel 9'da “Google ile giriş”e tekrar basın ve hesabı kendiniz seçin.

Beklenen: Google'ın imzalı ve doğrulanmış e-postası mevcut aktif Tarak hesabıyla eşleşiyorsa subject güvenli biçimde bağlanır ve doğrudan giriş yapılır. E-posta kayıtlı değilse anlaşılır kayıt mesajı gelir. Başka hesaba bağlı subject yeniden atanmaz. Pasif hesap veya doğrulanmamış e-posta otomatik bağlanmaz.

Bu yama mevcut sosyal giriş tablolarını ve verifier'ı kullanır. Migration, migrate:fresh, seed veya kullanıcı verisi taşıma komutu çalıştırmayın. Canlı dağıtım bu çalışma sırasında yapılmadı. Başarı sonucu ancak dosya güncellemesinden sonra tekrar gerçek girişle doğrulanabilir.

Ayrıntılı tüm altyapı değişiklikleri: MOBILE_STABILITY_REPORT_2026-10-30.md
