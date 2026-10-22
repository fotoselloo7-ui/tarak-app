# Tarak.app — temiz yayın kaynağı (22 Ekim 2026)

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
