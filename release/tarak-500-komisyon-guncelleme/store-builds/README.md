# store-builds — Google Play AAB / App Store IPA

Sürüm **1.1.0 (2)**, Bundle ID / applicationId `app.tarak.mobile` (değişmedi). Otomatik yükleme yapılmaz.

| Mağaza | Durum | Dosya |
|---|---|---|
| Android AAB | **ÜRETİLMEDİ** — Play yükleme anahtarı (`android/key.properties` + keystore) bu makinede yok; yeni anahtar üretilmedi, debug imzalı AAB bilerek reddedilir. | `android/build-aab.ps1` (anahtar konunca tek komut) |
| iOS IPA | **ÜRETİLMEDİ** — Windows'ta IPA üretilemez. | `ios/build-ipa-on-mac.sh` + `ios/ExportOptions.plist` (Mac'te tek komut) |

## Android (bu Windows makinesinde)
1. `mobile\android\keystore\tarak-upload-keystore.jks` ve `mobile\android\key.properties` dosyalarını mevcut Play yükleme anahtarınızla koyun (şablon: `key.properties.example`).
2. `powershell -ExecutionPolicy Bypass -File "release\tarak-500-komisyon-guncelleme\store-builds\android\build-aab.ps1"`
3. Çıktı bu klasöre kopyalanır: `android\tarak-1.1.0+2-release.aab` (+ SHA256). `keytool -printcert -jarfile <aab>` çıktısı sizin sertifikanızı göstermeli.

## iOS (Mac'te)
1. Projeyi Mac'e kopyalayın (`build/`, `.dart_tool/`, `ios/Flutter/ephemeral/` taşımayın). Flutter 3.47.x + güncel Xcode, Apple Distribution kimliğiniz Anahtar Zinciri'nde / Xcode hesabınızda.
2. `TEAM_ID=<Apple Team ID> bash release/tarak-500-komisyon-guncelleme/store-builds/ios/build-ipa-on-mac.sh`
3. Çıktı: `ios/tarak-1.1.0+2.ipa` → Transporter ile App Store Connect'e yükleyin.
4. Push için (isteğe bağlı): `ios/Runner/GoogleService-Info.plist` + Xcode'da Push Notifications capability (bkz. `mobile/IOS_RELEASE_GUIDE.md` §3-4). Betik bunlar yoksa uyarır, derlemeyi engellemez.

Pakette sertifika, private key veya şifre **yoktur**.
