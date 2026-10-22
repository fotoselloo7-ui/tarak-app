# Tarak — cPanel kurulum (tek ZIP, dolu pazar yeri)

ZIP, `/home/alac6yazilimtr/` altında açılır ve şu yapıyı verir (**`public_html` adlı ek klasör yoktur**):

```
/home/alac6yazilimtr/tarak.app/                    web sitesi (React) + .htaccess + index.php (Laravel köprüsü) + .user.ini   ← alan adının belge kökü
/home/alac6yazilimtr/tarak.app/demo-media/         demo uzman/müşteri fotoğrafları (545 gerçek dosya; symlink gerekmez)
/home/alac6yazilimtr/tarak-backend/                Laravel (belge kökünün DIŞINDA; internetten doğrudan erişilmez)
/home/alac6yazilimtr/tarak-full-production.sql     veritabanı, tam (belge kökü dışında; kurulumdan sonra SİLİN)
/home/alac6yazilimtr/tarak-full-production.sql.gz  aynı veritabanının sıkıştırılmış hâli (phpMyAdmin yükleme sınırı küçükse bunu yükleyin)
/home/alac6yazilimtr/INSTALL_CPANEL.md             bu dosya
```
Web ve mobil uygulamalar (Android + iOS) **aynı backend'i ve aynı veritabanını** kullanır: `https://tarak.app/api`. Ayrı mobil veritabanı yoktur.

> **Composer zorunludur.** ZIP'te `vendor/` klasörü **yoktur**. `tarak-backend` içinde `composer install --no-dev --optimize-autoloader` çalıştırılmadan API **çalışmaz** (`/api/...` "Sunucu kurulumu tamamlanmadı" JSON'u döner). Terminal (SSH) ve Composer 2 gerekir.

> **Alan adının belge kökü `/home/alac6yazilimtr/tarak.app` olmalıdır** (cPanel → Domains → `tarak.app` → *Document Root*). Farklıysa ya belge kökünü bu klasöre çevirin ya da `tarak.app` klasörünün içeriğini gerçek belge köküne taşıyıp `PUBLIC_WEB_ROOT` ve `index.php` içindeki `../tarak-backend` yolunu ona göre düzeltin.

## Ön koşullar
- cPanel → **MultiPHP Manager**: `tarak.app` için **PHP 8.2 veya üstü**; eklentiler açık: `bcmath ctype curl fileinfo gd mbstring openssl pdo_mysql tokenizer xml zip` (+ `opcache`).
- SSL sertifikası: cPanel → **SSL/TLS Status → Run AutoSSL**.
- Dosya Yöneticisi yükleme sınırı ZIP'ten (~56 MB) küçükse FTP/SFTP ile yükleyin.

## Kurulum
1. **ZIP'i açın:** `tarak-cpanel-full-production.zip` dosyasını `/home/alac6yazilimtr/` içine yükleyin → sağ tık **Extract** (hedef `/home/alac6yazilimtr/`). `tarak.app` içinde eski dosyalarınız varsa önce yedekleyin. Gizli dosyaları görmek için Dosya Yöneticisi → Settings → *Show Hidden Files*. ZIP'i silin.
2. **Boş MySQL veritabanı oluşturun:** cPanel → **MySQL® Databases** → *Create New Database* (ör. `tarak`; cPanel `alac6yazilimtr_tarak` yapar). Boş kalmalı.
3. **Veritabanı kullanıcısı oluşturun ve yetki verin:** *MySQL Users → Add New User* (güçlü şifre), sonra *Add User To Database* → **ALL PRIVILEGES**.
4. **`tarak-full-production.sql` dosyasını içe aktarın:** cPanel → **phpMyAdmin** → soldan **boş veritabanını seçin** → **İçe Aktar (Import)** → dosya olarak bilgisayarınızdaki ZIP'in içindeki `tarak-full-production.sql` (yükleme sınırı küçükse `tarak-full-production.sql.gz`, 0,66 MB; phpMyAdmin sıkıştırılmış dosyayı kendisi açar) → Biçim **SQL** → **Git**. Dosyada `CREATE DATABASE`/`USE` yoktur; seçili veritabanına kurulur. Terminal'den de olur: `mysql -u DB_KULLANICI -p DB_ADI < ~/tarak-full-production.sql`
   - **Import tamamlandı mı kontrolü** (phpMyAdmin → tabloların satır sayısı): `service_categories` **2**, `services` **19**, `provider_profiles` **101**, `users` **5203**, `provider_reviews` **5052**, `appointments` **11**, `migrations` **35**; toplam **67 tablo**. Sayılar bunlardan azsa import yarıda kalmıştır: veritabanını silip yeniden boş oluşturun ve tekrar yükleyin (dosya düzeni gereği hizmet kategorileri/hizmetler/site ayarları kullanıcılardan ÖNCE yüklenir).
   - "Table already exists" hatası: veritabanı boş değil → boş yenisini oluşturun (dosya var olan verinin üzerine yazmaz, bilerek).
5. **`.env` oluşturun** (Terminal):
   ```bash
   cd ~/tarak-backend
   cp .env.production.example .env && chmod 600 .env
   nano .env
   ```
6. **Veritabanı bilgilerini girin:** `DB_DATABASE=`, `DB_USERNAME=`, `DB_PASSWORD=` (`DB_HOST=127.0.0.1` kalabilir).
7. **`APP_URL=https://tarak.app`** (ayrıca `FRONTEND_URL=https://tarak.app`, `SANCTUM_STATEFUL_DOMAINS=tarak.app`). `APP_ENV=production`, `APP_DEBUG=false` değişmemeli. cPanel'de Reverb yoktur: `BROADCAST_CONNECTION=null` kalsın.
8. **`PUBLIC_WEB_ROOT=/home/alac6yazilimtr/tarak.app`**
9. **Bağımlılıkları kurun (ZORUNLU)** — `php -v` ≥ 8.2 değilse `php` yerine `/usr/local/bin/ea-php82` yazın (yol: `ls /usr/local/bin | grep ea-php`):
   ```bash
   cd /home/alac6yazilimtr/tarak-backend
   composer install --no-dev --optimize-autoloader
   ```
   `composer` yoksa: `curl -sS https://getcomposer.org/installer | php -- --install-dir=$HOME --filename=composer.phar` ve `php -d memory_limit=-1 ~/composer.phar install --no-dev --optimize-autoloader`.
10. **Uygulama anahtarı ve önbellekler:**
    ```bash
    php artisan key:generate --force      # APP_KEY üretir; canlıdan sonra ASLA değiştirmeyin
    php artisan optimize:clear
    php artisan config:cache
    php artisan route:cache
    php artisan view:cache
    ```
    (`.env` her değiştiğinde `php artisan config:cache` tekrar.) `php artisan migrate --force` gerekmez: SQL `migrations` tablosunu (36 kayıt, **500 TL komisyon / banka tahsilatı şeması dahil**) içerir ("Nothing to migrate"); yalnız gelecekte eklenen migration'ları çalıştırır. **Kurulumdan sonra admin panelinde (Finans & Banka Tahsilatı → Banka Hesabı) banka hesabını girin ve Entegrasyon Merkezi'nden SMTP'yi test edin;** e-postalar kuyruktan gider (adım 13'teki cron).
11. **Yükleme bağlantısı (storage):** `php artisan storage:link` → `/home/alac6yazilimtr/tarak.app/storage` oluşur; **kullanıcıların sonradan yüklediği** avatar/kapak/galeri görselleri `https://tarak.app/storage/...` adresinden gelir. Demo fotoğrafları bu bağlantıya **bağlı değildir** (`https://tarak.app/demo-media/...` altında gerçek dosyalardır). `Link already exists` derse sorun yok; sunucu `symlink()` işlevini kapatmışsa aynısını elle yapın: `ln -s /home/alac6yazilimtr/tarak-backend/storage/app/public /home/alac6yazilimtr/tarak.app/storage`.
12. **İzinler:** `cd ~/tarak-backend && chmod -R u+rwX,go-w storage bootstrap/cache && chmod 600 .env` (dosyalar 644, klasörler 755; **666/777 olmaz**). Farklı grupla çalışıyorsa `storage` ve `bootstrap/cache` için 775.
13. **Queue + cron** (cPanel → Cron Jobs, her dakika; `ea-php82` yolunu kendinize göre düzeltin):
    ```
    cd /home/alac6yazilimtr/tarak-backend && /usr/local/bin/ea-php82 artisan schedule:run >> /dev/null 2>&1
    cd /home/alac6yazilimtr/tarak-backend && flock -n /tmp/tarak-queue.lock /usr/local/bin/ea-php82 artisan queue:work --queue=push,default --stop-when-empty --tries=3 --max-time=50 >> /dev/null 2>&1
    ```
    Birincisi zamanlayıcı (ödeme uzlaştırma, öne çıkarma süresi bildirimi, canlılık), ikincisi kuyruk (push bildirimleri, PayTR iadesi). Kuyruk adları **`push,default`** birlikte yazılmalı. (`flock` yoksa o kelimeleri çıkarın.)
14. **HTTPS:** `http://tarak.app` → `https://tarak.app` yönlenmeli (`.htaccess` zorlar), kilit simgesi görünmeli, karışık içerik uyarısı olmamalı. Olmazsa AutoSSL'i çalıştırın.
15. **`/api/health` testi:** `https://tarak.app/api/health` → `{"status":"ok","database":"connected",...}`; `https://tarak.app/api/health/ready` → `{"ready":true,...}`
16. **`/api/services` testi:** `https://tarak.app/api/services` → 19 hizmet; **`https://tarak.app/api/service-categories` → 2 kategori (Erkek Bakım, Kadın Kuaför)**.
17. **`/api/providers` testi:** `https://tarak.app/api/providers` → hizmet veren listesi (sayfada 12 kayıt, puan + yorum sayısı + görsel); `https://tarak.app/api/providers/featured` → öne çıkanlar; `https://tarak.app/api/stats/home` → **3 satır: 101 Doğrulanmış Hizmet Veren, 5.101 Hizmet Alan Müşteri, 4,0 Ortalama Tarak Puanı**. Ana sayfa `https://tarak.app/` kategorileri, hizmetleri, uzmanları ve bu üç sayacı göstermeli.
18. **Giriş testi:** `https://tarak.app/admin` (yönetici), müşteri ve hizmet veren girişi çalışmalı (aşağıdaki "Demo hesaplar"). Web ve mobil uygulama aynı verileri göstermeli.
19. **Kurulum bitince SQL'i silin:** `rm ~/tarak-full-production.sql ~/tarak-full-production.sql.gz` (ve gerekirse `~/INSTALL_CPANEL.md`).

## Demo hesaplar ve demo veri — CANLIYA ALMADAN ÖNCE OKUYUN
- **3 adlandırılmış demo hesap** SQL'de orijinal şifre özetleriyle durur: `customer@berberimgelsin.com` (müşteri), `provider@berberimgelsin.com` (hizmet veren "Test Usta", ana sayfada ve listelerde görünür), `admin@berberimgelsin.com` (**yönetici**). Bu hesapların şifresi kod deposundaki geliştirme tohumunda yazılı **bilinen bir değerdir**: herkese açık siteye çıkmadan **hemen** yönetici şifresini değiştirin veya `php artisan app:create-admin --email=siz@alanadiniz.com --name="Ad Soyad"` ile kendi yöneticinizi oluşturup Yönetim → Üye Yönetimi'nden `admin@berberimgelsin.com` hesabını askıya alın/silin. Müşteri ve hizmet veren demo hesaplarını da gerçek kullanıma açmadan önce aynı şekilde değerlendirin.
- **~5.200 sentetik kayıt** (e-posta `@demo.tarak.test`, sahte telefon, `users.is_demo = 1`): 100 hizmet veren + ~5.100 müşteri, 5.050 yorum. Bunlar **gerçek kişi değildir**; şifreleri kullanılamaz rastgele özetlerdir (giriş yapılamaz). İstediğiniz an `php artisan demo:purge` veya Yönetim → Demo Veriler ile silinir (3 adlandırılmış hesap silinmez).
- **Etkinlik geçmişi de SQL'dedir** (yerel veritabanından olduğu gibi): 11 randevu, 11 hizmet talebi, 7 teklif, 4 sohbet (25 mesaj), 1 ödeme kaydı, 1 uyuşmazlık, 21 cüzdan hareketi, 89 bildirim, 11 komisyon rezervi, 46 hizmet olayı, destek talebi, yönetici günlüğü. Bunlar **3 adlandırılmış hesabın yerel test çıktısıdır** ("FAZ4_QA…" notları, bir XSS deneme mesajı dahil) ve `demo:purge` ile silinmez; gerçek kullanıma açmadan önce bu hesaplarla birlikte ele alın. Hizmet veren demo hesabının cüzdanında yerelde olduğu gibi 6.000 TL **promosyon** bakiyesi vardır (nakit değil).
- **Sahte yorum/puan uyarısı:** demo yorumlar ve "Tarak puanları" gerçek müşteri değerlendirmesi değildir. Gerçek kullanıcıya açık bir sitede bunları "gerçek değerlendirme" gibi sunmak tüketici mevzuatı açısından risklidir (haksız ticari uygulama / yanıltıcı yorum); gerçek yayına geçerken `demo:purge` ile temizlemeniz veya demo olduğunu açıkça belirtmeniz önerilir. Ana sayfa sayaçları demo hesapları **bilerek sayar** (`site_contents.landing.stats_count_demo = yes`); yayında Yönetim → Site Yönetimi → Ana Sayfa → İstatistikler'den "Demo hesaplar sayılara dahil mi?" ayarını "Hayır"a alın.
- **SQL'e bilerek konmayanlar:** oturum/API token'ları (eski yerel token'lar canlıda geçerli olurdu), önbellek/kuyruk kayıtları, entegrasyon bağlantı günlükleri, **yerel anahtarla şifrelenmiş** veriler (banka hesabı IBAN'ı, kesin konum paylaşımları, hizmet başlatma kodları: sunucudaki farklı `APP_KEY` ile çözülemez), PayTR / SMTP / SMS / Firebase / Reverb şifreleri (yerelde de kayıtlı değildi). Kullanıcılar canlıda giriş yapınca yeni token alır.

## Entegrasyon bilgileri (siz girersiniz)
| Alan | Nerede | Not |
|---|---|---|
| **PayTR** | `.env`: `PAYTR_MERCHANT_ID`, `PAYTR_MERCHANT_KEY`, `PAYTR_MERCHANT_SALT` (veya Yönetim → Entegrasyon Merkezi → PayTR) | Önce `PAYTR_TEST_MODE=1`, canlıda `0`. `PAYTR_OK_URL=https://tarak.app/payment-result/success`, `PAYTR_FAIL_URL=.../fail`. PayTR panelindeki **Bildirim URL**: `https://tarak.app/api/payments/paytr/callback` |
| **SMTP** | `.env`: `MAIL_HOST`, `MAIL_PORT`, `MAIL_USERNAME`, `MAIL_PASSWORD`, `MAIL_FROM_ADDRESS` (veya Entegrasyon Merkezi → SMTP) | host genelde `mail.tarak.app`, port 465 + `MAIL_SCHEME=smtps` |
| **SMS** | **Yalnız** Yönetim → Entegrasyon Merkezi → SMS | `.env` anahtarı yoktur |
| **FCM (push)** | `.env`: `FCM_ENABLED=true`, `FCM_PROJECT_ID`, `GOOGLE_APPLICATION_CREDENTIALS=/home/alac6yazilimtr/tarak-secrets/firebase-service-account.json` | JSON'u belge kökü dışında tutun (`mkdir ~/tarak-secrets && chmod 700`, dosya `chmod 600`) |
| **Reverb** | cPanel'de **kurulamaz** | `BROADCAST_CONNECTION=null`: yeni mesaj/bildirim anında düşmez, ekran yenilenince görünür. Anlık için VPS + Reverb |

## Sorun giderme
- **Hizmet kategorileri / hizmetler / uzmanlar listelenmiyor:** önce `https://tarak.app/api/service-categories` adresine bakın. JSON'da 2 kategori geliyorsa API sağlam, sorun tarayıcı önbelleği olabilir (Ctrl+F5). JSON **boşsa** import yarım kalmıştır (adım 4'teki sayılar). **HTML/ana sayfa** geliyorsa `.htaccess` okunmuyor. **500 / "Sunucu kurulumu tamamlanmadı"** geliyorsa `.env`/composer (adım 6–9). Her üç durumda `tarak-backend/storage/logs/laravel.log` ilk bakılacak yerdir.
- **Ana sayfa sayaçlarında "1 / 1" görünüyor, Tarak puanı yok:** `site_contents` içindeki `landing.stats_count_demo` değeri `yes` olmalı (SQL'de öyledir); yönetici panelinden "Hayır/Otomatik" yapıldıysa canlıda demo hesaplar sayılmaz.
- **500 / boş sayfa:** `tarak-backend/storage/logs/laravel.log`; `.env` ve izinler. `APP_DEBUG` açık bırakılmamalı.
- **`/api/...` "Sunucu kurulumu tamamlanmadı":** adım 9 (composer) yapılmamış.
- **`/api/health` 404 veya SPA sayfası:** `tarak.app/.htaccess` okunmuyor (`AllowOverride` kapalı / dosya silinmiş) veya `mod_rewrite` kapalı.
- **`/api/health` "database" hatası:** adım 6'daki bilgiler veya adım 3 (yetki) hatalı; `php artisan config:cache` tekrar.
- **Görseller kırık (uzman/müşteri fotoğrafları yerine yazı çıkıyor):** tarayıcıda `https://tarak.app/demo-media/pool/portraits/men/9395202.jpg` adresini açın. Fotoğraf geliyorsa sorun yok (Ctrl+F5). **404** ise `tarak.app/demo-media/` klasörü eksik: ZIP tam açılmamış, yeniden `tarak.app` içine açın (`demo-media/pool/…` altında 545 dosya olmalı). **403** ise klasör izinleri: `chmod -R u+rwX,go+rX ~/tarak.app/demo-media` (klasör 755, dosya 644). Kullanıcıların kendi yüklediği görseller için adım 11'deki `storage` bağlantısı gerekir.
- **Dosya yüklenmiyor (413/422):** `tarak.app/.user.ini` (8M/10M) okunmuyorsa cPanel → MultiPHP INI Editor: `upload_max_filesize=8M`, `post_max_size=10M`.
- **Güncelleme:** yeni ZIP'i yedek alıp aynı şekilde açın (`.env` ve kullanıcı yüklemeleri ezilmez); `composer install --no-dev --optimize-autoloader`, `php artisan migrate --force`, `php artisan optimize:clear`, üç `cache` komutu, `php artisan queue:restart`. SQL'i güncellemede **tekrar içe aktarmayın**. **Çalıştırmayın:** `db:seed`, `migrate:fresh`, `db:wipe`.
