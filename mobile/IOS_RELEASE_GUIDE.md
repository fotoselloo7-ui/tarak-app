# Tarak — iOS release rehberi (Mac üzerinde)

Windows'ta IPA üretilemez; **sahte IPA yoktur**. Bu klasör Mac/Xcode release build'i için hazırlandı. Bundle ID: **`app.tarak.mobile`** (değiştirmeyin).
Gerçek IPA Mac'te oluşunca yolu: `mobile/build/ios/ipa/*.ipa`.

**Aynı backend, aynı veritabanı:** iOS (ve Android) uygulaması web ile **aynı** `https://tarak.app/api` backend'ini ve **aynı** üretim veritabanını (`release/tarak-full-production.sql` ile kurulan dolu pazar yeri) kullanır; ayrı iOS veritabanı/veri seti yoktur. Derlemede `--dart-define=API_BASE_URL=https://tarak.app/api` ve `--dart-define=REVERB_HOST=tarak.app` zorunludur (aşağıdaki komut). Yerel/demo API'ye bağlanan release derlemesi üretilemez (`EnvConfig` reddeder). Sunucu tarafı kurulumu bitmeden (SQL import + `composer install`) uygulama boş/hatalı görünür.

## 0. Hazırlık durumu (Windows'ta doğrulananlar)

| Kontrol | Sonuç |
|---|---|
| Bundle ID (`Runner.xcodeproj`, 3 yapılandırma) | `app.tarak.mobile` (RunnerTests: `app.tarak.mobile.RunnerTests`) |
| Sürüm | `pubspec.yaml` `1.1.0+2` → `CFBundleShortVersionString=1.1.0`, `CFBundleVersion=2` (bkz. 5) |
| Minimum iOS | 15.0 |
| `Info.plist` | `CFBundleDisplayName=Tarak`; konum / kamera / fotoğraf / mikrofon açıklamaları var; **bu sürümde `UIBackgroundModes → remote-notification` eklendi** (FCM için) |
| Uygulama ikonu | `Assets.xcassets/AppIcon.appiconset`: **19 giriş (1024 dahil) + 9 alternatif ikon seti (AppIcon-Bordo … Grafit, 18'er giriş) — tüm PNG'ler Contents.json ölçüleriyle birebir, iOS ikonlarında alfa kanalı yok** (iOS + Android + mağaza ikonları birlikte 233 PNG tarandı, 0 hata) |
| App Store ikonu | `store-assets/app-icons/ios-app-store/app-icon-1024.png` — 1024×1024, RGB (alfasız), 175 KB |
| Açılış ekranı | `LaunchScreen.storyboard` + `LaunchImage.imageset` (Tarak "k" işareti 128/256/384 px, ortalanmış, beyaz zemin) — Flutter varsayılanı değil, marka |
| Alternatif ikonlar | `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` ayarlı (`AppDelegate.swift` method channel ile seçim) |
| Swift Package Manager | Proje `FlutterGeneratedPluginSwiftPackage` kullanıyor (Flutter 3.47). `ios/Podfile` **yoktur**; bir eklenti SPM desteklemiyorsa Flutter Podfile'ı kendisi üretir ve CocoaPods kullanır (bkz. 2) |
| `GoogleService-Info.plist` | **YOK** → iOS FCM `WAITING_CREDENTIAL` (sahte dosya oluşturulmadı) |
| Entitlements (`Runner.entitlements`, `aps-environment`) | **YOK** — Xcode'da "Push Notifications" capability eklenince oluşur (bkz. 3) |
| `DEVELOPMENT_TEAM` | tanımlı değil — Xcode'da kendi takımınızı seçin |
| Hesap silme / gizlilik / yasal / UGC | Hesap silme: Ayarlar → **Hesabımı sil** (müşteri) ve Profil → **Hesabımı Sil** (hizmet veren), backend `DELETE /api/account`; gizlilik/KVKK/şartlar: web `https://<alan adı>/legal/privacy`, `/legal/kvkk`, `/legal/terms`; UGC: mesaj/yorum **raporlama** (`POST /api/reports`) ve **kullanıcı engelleme** (sohbet menüsü "Kullanıcıyı engelle", `/api/blocks`), yönetici paneli "içerik raporları" |
| Kamera / mikrofon açıklamaları | Uygulama yalnız **galeriden** seçer (`ImageSource.gallery`); kamera/mikrofon metinleri `image_picker` eklentisinin bu API'lere başvurması nedeniyle durur (Apple eksik açıklamayı reddeder, fazlasını değil). Metinler doğru ve tutarlıdır; başka izin eklenmedi. |

## 1. Mac gereksinimleri

- Güncel Xcode (App Store'un istediği sürüm), Command Line Tools, Apple Developer Program üyeliği.
- Flutter **3.47.x** (bu proje 3.47.4 ile derlendi: `flutter --version`), `flutter doctor` temiz.
- CocoaPods (`brew install cocoapods`) — yalnız SPM desteklemeyen eklenti varsa gerekir; kurulu olması zararsızdır.
- Apple Developer'da App ID `app.tarak.mobile` kayıtlı (otomatik imzalama Xcode'dan kaydeder) ve App Store Connect'te uygulama kaydı açık.
- Projeyi Mac'e `mobile/` klasörü olarak kopyalayın; **`build/`, `.dart_tool/`, `ios/Flutter/ephemeral/`, `ios/Flutter/Generated.xcconfig` ve `flutter_export_environment.sh` Windows yollarını içerir — taşımayın / silin** (Mac'te `flutter pub get` yeniden üretir).

## 2. Komutlar

```bash
cd mobile
flutter clean
flutter pub get          # ios/Flutter/Generated.xcconfig + SPM paketini Mac yollarıyla yeniden üretir
cd ios
pod install              # YALNIZ ios/Podfile varsa (Flutter bir eklenti için CocoaPods gerektirirse pub get/build onu üretir). Podfile yoksa bu adımı atlayın.
cd ..
```

**Üretim API adresi zorunludur** — release derlemesi bu değerler olmadan çalışmaz (`lib/core/config/env_config.dart` `StateError` fırlatır):

```bash
flutter build ipa --release \
  --build-name 1.1.0 --build-number 2 \
  --dart-define=API_BASE_URL=https://tarak.app/api \
  --dart-define=REVERB_HOST=tarak.app \
  --dart-define=REVERB_APP_KEY=hhyfpgfv2dgv95yd78kz
```
(`tarak.app` = sunucuda kuracağınız gerçek alan adı. `REVERB_APP_KEY` sunucudaki `REVERB_APP_KEY` ile aynı olmalı. Port/şema release'te varsayılan 443/`wss`.)

Çıktı: `build/ios/ipa/*.ipa`. Yüklemek için: Transporter uygulaması (IPA'yı sürükleyin) veya
`xcrun altool --upload-app --type ios -f build/ios/ipa/<dosya>.ipa --apiKey <KEY> --apiIssuer <ISSUER>`.

## 3. Xcode ile (alternatif / imza ve capability ayarı)

1. `ios/Runner.xcworkspace` dosyasını açın (**`.xcodeproj` değil**).
2. Runner target → **Signing & Capabilities** → **Release** (ve Debug): *Automatically manage signing* açık, **Team** = sizin Apple Developer takımınız. Bundle Identifier `app.tarak.mobile` olarak kalmalı.
3. **+ Capability → Push Notifications** (Xcode `Runner/Runner.entitlements` içine `aps-environment` yazar ve App ID'de özelliği açar).
4. **+ Capability → Background Modes → Remote notifications** (Info.plist'te zaten var; kutu işaretli görünmeli).
5. `GoogleService-Info.plist` (Firebase Console → iOS uygulaması `app.tarak.mobile`) dosyasını `ios/Runner/` içine sürükleyin: *Copy items if needed* ✔, *Add to targets: Runner* ✔. Kontrol: Runner → Build Phases → **Copy Bundle Resources** listesinde `GoogleService-Info.plist` olmalı.
6. Üst menü: hedef cihaz **Any iOS Device (arm64)** → **Product → Archive** → Organizer → **Distribute App → App Store Connect → Upload** (otomatik imzalama seçili kalsın).

## 4. Firebase / APNs (push için)

1. Apple Developer → Certificates, IDs & Profiles → **Keys** → yeni anahtar → **Apple Push Notifications service (APNs)** → `.p8` dosyasını indirin (**bir kez indirilir**), **Key ID** ve **Team ID**'yi not edin.
2. Firebase Console → Proje ayarları → **Cloud Messaging** → *Apple app configuration* → APNs Authentication Key olarak `.p8` + Key ID + Team ID yükleyin.
3. Sunucu tarafı: `FCM_ENABLED=true`, `FCM_PROJECT_ID`, `GOOGLE_APPLICATION_CREDENTIALS` (bkz. `PRODUCTION_DEPLOYMENT.md`).
4. Gerçek cihazda test (simülatör push almaz): giriş yap → bildirim izni ver → panelden bildirim gönder.

## 5. Sürüm numaraları

`pubspec.yaml` → `version: 1.1.0+2`. App Store Connect aynı sürüm için **her yüklemede farklı build numarası** ister: bu sürüm/build zaten yüklüyse `--build-number`'ı artırın (veya `pubspec.yaml`'ı `1.1.0+3` yapın). Tek komutluk betik: `release/tarak-500-komisyon-guncelleme/store-builds/ios/build-ipa-on-mac.sh`. Daha önce yüklenmiş build numarasını bilmiyoruz; rastgele düşürmeyin.

## 6. App Store Connect formu (kod dışı, sizin dolduracağınız)

- **Gizlilik politikası URL'si:** `https://<alan adı>/legal/privacy` (çalışır; web'de doğrulandı). Destek URL'si: kendi destek sayfanız/e-postanız.
- **App Privacy (veri toplama):** ad, e-posta, telefon, yaklaşık konum (yalnız "Konumumu kullan"), yüklenen fotoğraf/belge, kullanıcı içeriği (mesaj/yorum), push belirteci (cihaz kimliği), ödeme (PayTR üzerinden; kart bilgisi uygulamada saklanmaz).
- **Hesap silme:** uygulama içinde mevcut (yukarıdaki tablo) — inceleme notuna yolunu yazın.
- **UGC (kullanıcı içeriği):** raporlama + engelleme + yönetici denetimi mevcut — inceleme notuna yazın.
- **İnceleme için demo hesabı:** **canlı veritabanında hazır hesap yoktur**; Apple'a verilecek test müşteri/hizmet veren hesaplarını canlıda siz oluşturun (şifreyi sizin belirleyin).
- **Şifreleme beyanı:** uygulama yalnız standart HTTPS/yerleşik şifreleme kullanır; Apple her yüklemede sorar. Muafiyeti onaylıyorsanız `Info.plist`'e `ITSAppUsesNonExemptEncryption = NO` eklenebilir (hukuki beyan olduğu için otomatik eklenmedi).
- **Giriş yöntemi:** yalnız kendi e-posta/telefon hesabı; üçüncü taraf sosyal giriş yok → "Sign in with Apple" zorunlu değil.
- **Ekran görüntüleri:** henüz yok (bkz. `STORE_UPLOAD_FILES.md`).
