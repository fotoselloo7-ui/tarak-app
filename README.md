# Tarak.app — temiz yayın kaynağı (22 Ekim 2026)

## Yerel web ve API (28 Ekim 2026)

Proje kökünde tek komut:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\start-local.ps1
```

Başlatıcı mevcut Laravel API ile web dağıtımını aynı origin üzerinde sunar. `.env` içindeki mevcut yerel veritabanını korur: SQLite veya yalnız `127.0.0.1`/`localhost`/`::1` üzerindeki MySQL kabul edilir. Canlı cPanel bağlantısı ve `DB_URL` kabul edilmez. Boş SQLite kurulumunda yalnız hizmet kataloğu hazırlanır; otomatik örnek hesap üretilmez. Örnek veri ancak açık `-SeedPreview` seçeneğiyle ayrı SQLite üzerinde oluşturulur. Dolu portta başka projeye yönelmemek için durur.

Bu bilgisayardaki mevcut Tarak kayıtları eski yerel MySQL kaynağından **ayrı bir yerel MySQL kopyasına** aktarıldı: 5.203 hesap (5.101 müşteri, 101 hizmet veren, 1 yönetici), 7.611 adres ve ilişkili veriler korunur. Kaynak değiştirilmedi; SQL yedeği `.tools/local-db-backups/` içindedir ve Git'e gönderilmez. Yeni boş önizleme veritabanı mevcut kayıtların yerine kullanılmaz. Mevcut `is_demo` değerleri de kaynaktaki haliyle korunmuştur.

Başka bir bilgisayarda mevcut yerel verilerin ayrı kopyası hazırlanacaksa (hedef veritabanı önceden mevcut olmamalıdır):

```powershell
php scripts/copy-local-database.php "ESKI_YEREL_BACKEND_KLASORU" tarak_updated_local
```

Bu komut yalnız yerel MySQL kaynaklarını kabul eder, önce SQL yedeği alır ve tüm tablo sayılarını doğruladıktan sonra yerel `.env` bağlantısını yeni kopyaya geçirir. Canlı veritabanında kullanılmaz.

Bu bilgisayarda 8010 başka bir geliştirme projesi tarafından kullanılıyor. Boş port alternatifi:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\start-local.ps1 -Port 18810
```

Entegrasyon ayarları, doğrulama sonuçları ve mağaza kalanları: [release/INTEGRATION-READINESS.md](release/INTEGRATION-READINESS.md).

Bu paket kullanıcı tarafından yüklenen `release.zip` içinden doğrulanmış **en güncel tam** paketlerden oluşturulmuştur.

## Klasörler
- `tarak.app/`: **derlenmiş**, cPanel'e kurulabilir web sitesi. React/TypeScript **kaynak kodu bu yüklemede yoktur**; düzenlenebilir web kaynağı için yerel geliştirme klasörü ayrıca aktarılmalı.
- `tarak-backend/`: Laravel API ve yönetim fonksiyonları (PHP kaynakları, migration'lar, mail sınıfları).
- `mobile/`: Flutter Android + iOS **kaynak kodunun tamamı** (1.1.0+2).
- `database/tarak-full-production.sql`: tek SQL; tam şema, demo hesapları/verileri, son komisyon/banka tahsilatı yapısı. **Bu dosya yalnızca boş veritabanı kurulumuna yöneliktir. Canlı veritabanına tekrar import ETMEYİN.**
- `release/tarak-500-komisyon-guncelleme/store-builds/`: Android AAB / iOS IPA oluşturma betikleri ve mağaza notları.

## Kimlikler
Google Play uygulaması için önceden belirlenen Android `applicationId`, namespace ve Kotlin MainActivity paketi `app.tarak.mobile` olarak eşitlendi. iOS Runner + RunnerTests Bundle ID'leri ve uygulama simgesi değiştirme platform kanalları aynı kimlikle eşitlendi. Uygulama görünen adı `Tarak.app`. Mevcut `mobile/pubspec.yaml` sürümü `1.1.0+2` olarak **korundu**.

Android/iOS Firebase konfigürasyonları bu arşivde yok; `app.tarak.mobile` kimliğiyle indirip doğru dizinlere koyun. Android release için **yeni upload keystore** (ilk Play yüklemesi) ve `mobile/android/key.properties` hazırlanmalı; iOS için macOS/Xcode, Apple Team ID ve distribution signing gerekir. İmzalı AAB/IPA **bu pakette yok**. Mevcut API ve komisyon akışları yeniden yazılmadı.

## Web dağıtımı
Tam cPanel kurulumunda `tarak.app/` ve `tarak-backend/` iki kardeş klasördür. `INSTALL_CPANEL.md` sadece **sıfırdan kurulum** için okunmalı; mevcut canlı siteyi tüm SQL ile sıfırlamayın.

## Önemli üretim güvenliği
`database/tarak-full-production.sql` çok sayıda **sentetik demo kullanıcı, test hareketleri ve 3 demo hesaba ait parola hash'i** içerir; canlı müşteri verisi olmamalıdır, ama özel depoda bile dikkatle saklanmalı. Demo admin parolasını yayına çıkmadan değiştirin; test hesaplarına erişimi sınırlandırın. Gerçek müşteri verileriyle karışık veri yüklemeyin. `mobile/android/key.properties`, `.jks`, `.env`, Firebase hizmet hesabı JSON'u ve Apple signing dosyalarını Git'e göndermeyin.

## Paket seçimi
- Tam web/backend: `tarak-cpanel-full-production.zip` esas alındı.
- Mobil: `tarak-mobile-kaynak-son.zip` esas alındı; eski 5 dosyalık kısmi yama esas alınmadı.
- Son 159 dosyalık web yamasının tüm içeriği tam pakette birebir bulundu.
- `tarak-500-komisyon-patch.sql` tam SQL'deki güncelleme ile aynı sürüme aittir; **tekrar birleştirilmedi**.

## GitHub'a gönderme
İlk push için kökteki `GITHUB_ILK_PUSH.cmd` dosyasını çalıştırın. Uzak depo `https://github.com/fotoselloo7-ui/tarak-app` önceden açılmıştır; script **force push kullanmaz**. Sonraki güncellemelerde `git add . && git commit -m "..." && git push`.
