# Tarak Mobil: Randevuya Koş 🏃‍♂️✂️

> **Yerleşim (2026-11-28):** oyun tarak.app'in parçasıdır.
> - Yayındaki oyun (istemci, oyun API'si, oyun yönetim paneli): `tarak.app/oyun/` → https://tarak.app/oyun/
> - Bu klasör (`tarak-backend/oyun/`): araçlar, testler, Android paketi, belgeler (web'den erişilemez).
> - Tarak entegrasyonu (Tarak ile giriş, sponsorlar, kuponlar): `tarak-backend` (GameController) — bkz. `../../OYUN-ENTEGRASYONU.md`.
> - Mağazalarda (App Store / Google Play) Tarak Berber Çağır'dan **ayrı bir oyun uygulaması** olarak yayınlanacak.
> Aşağıdaki `web/` yolları artık `tarak.app/oyun/` demektir.

tarak.app maskotu **K**'nin müşteriye yetişmek için engelleri aştığı mobil koşu oyunu.
Web'de, ana ekrana eklenen uygulama (PWA) olarak ve Android APK'sı olarak çalışır.

- **3D Koşu** (Subway Surfers tarzı, üç şerit): kamera K'nin arkasında; müşteri duraklarında sandık, dünya değişimi, fön jet ve diğer güçler
- İki ana mod: **3D Koşu** ve **2D Macera**
- Ödüller: tarak cüzdanı, günlük ödül serisi, günlük 3 görev, sandık, 2D yolda hediye kutuları, haritada bölge sandıkları
- **Seviye yolu** ve **Gardırop**: seviyeyle açılan kıyafetler, tarakla alınanlar, yılbaşı kostümü (20 Kasım–15 Ocak ücretsiz), hazır kostümler, kilitli kıyafeti deneme
  (hepsi oyun içi, cihazda saklanır; kurallar `web/assets/js/odul.js`)
- 2D: 12 bölüm (Şehir · Otoyol · Orman · Aslanın İni) + Sonsuz Mod
- Zıpla, **çift zıpla**, kay, **2× turbo kayış**, havadan hızlı iniş
- **Kolay / Orta / Zor** modları; 2D'de Kolay ve Orta'da son bayraktan devam
- Skor sıralaması, güçlendiriciler, yıldızlar, ses ve titreşim
- Yönetim paneli: anlık / günlük / toplam oyuncu, bölüm başarı oranı, skorlar, engelleme, oyunu kapatma, duyuru, randevu düğmesi

## Bilgisayarda açmak
`EMULATORDE-AC.bat` dosyasına çift tıkla (sunucu + sanal Android telefon + oyun).
Tarayıcıda: http://localhost:8812 · Panel: http://localhost:8812/admin/ (yerel test girişi `web/data/yerel-test-giris.txt`).

Klavye: `←` `→` şerit (3D), `Boşluk`/`↑` zıpla, `↓` kay, `P` duraklat.

## Subdomain'e yayınlamak (örnek: mobil.tarak.app)
1. `powershell -ExecutionPolicy Bypass -File tools\paketle.ps1` → `dist/tarak-oyun-subdomain.zip`
2. Hosting panelinde subdomain oluştur (PHP **8.0+**, `pdo_sqlite` veya MySQL, `mbstring`) ve SSL'i aç.
3. Zip'i subdomain'in kök klasörüne açıp `data/` klasörüne yazma izni ver.
4. `https://mobil.tarak.app/api/index.php?islem=ayar` adresini bir kez aç: `data/gizli.php` oluşur.
5. **Hemen** `https://mobil.tarak.app/admin/` adresine gir. `data/gizli.php` içindeki `kurulum_anahtari` ile kendi yönetici hesabını oluştur.
6. Güvenlik kontrolü: `https://mobil.tarak.app/data/gizli.php` ve `/inc/bolumler.json` **403** vermeli.
   Sunucu `.htaccess` okumuyorsa (nginx) bu iki klasörü sunucu ayarından kapat.

MySQL istersen `data/mysql.php` oluştur:
```php
<?php return ['dsn' => 'mysql:host=localhost;dbname=VERITABANI;charset=utf8mb4', 'kullanici' => 'KULLANICI', 'sifre' => 'SIFRE'];
```

### Ana siteye buton eklemek
```html
<a href="https://mobil.tarak.app" style="background:#ffc400;color:#1c2023;padding:12px 22px;border-radius:12px;font-weight:800;text-decoration:none">🎮 K ile Randevuya Koş!</a>
```

## Android
```powershell
powershell -ExecutionPolicy Bypass -File android\derle.ps1 -ApiAdresi "https://mobil.tarak.app/api/index.php"
```
Çıktı: `android/cikti/tarak-kos.apk`. Oyun dosyaları paketin içindedir, internetsiz de oynanır; skor ve istatistik için sunucu gerekir.
Bu APK **test anahtarıyla** imzalıdır. Google Play için ayrıca AAB, kalıcı imza anahtarı ve Play geliştirici hesabı gerekir.
iOS (App Store) sürümü için Mac ve Apple geliştirici hesabı gerekir; iPhone'da web sürümü "Ana ekrana ekle" ile oynanabilir.

## Testler
```powershell
node tests\bot-test.js
node tests\uc-test.js
node tests\odul-test.js
node tests\api-test.js
```
Bölüm veya mod ayarı değişirse: `node tools\export-levels.js` (sunucunun hile kontrolü bu dosyayı kullanır).

## Klasörler
| Yol | İçerik |
|---|---|
| `web/` | Subdomain'e yüklenen her şey (oyun, `api/`, `admin/`) |
| `web/assets/js/core.js` | 2D fizik, bölümler, zorluk modları |
| `web/assets/js/uc-*.js` | 3D koşu: mantık, maskot modeli, sahne, arayüz |
| `web/assets/js/odul.js` | Ödül, görev ve mağaza kuralları (fiyatlar burada) |
| `tools/three-paket/` | Three.js'i tek dosyaya paketler (`npm install` + esbuild) |
| `android/` | WebView uygulaması ve Gradle'sız derleme betiği |
| `tools/` | Sprite kesme, paketleme, emülatör açma |

## Notlar
- Logo, sohbette paylaşılan görsele bakılarak SVG olarak yeniden çizildi (`web/assets/img/logo.svg`, `logo-acik.svg`). Orijinal vektör dosyanız varsa bu iki dosyanın yerine koyun.
- Maskot gövdesi, eldiven ve ayakkabı orijinal 3D görselden kesildi (`tools/make-sprites.ps1`).
- Sunucuda IP adresi ve cihaz kimliği düz metin tutulmaz (tuzlu özet). Siteye KVKK/gizlilik metni eklemeniz önerilir.
