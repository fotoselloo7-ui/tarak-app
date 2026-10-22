# Tarak uygulama ikonu: 10 renk, seçilebilir, ne nerede, neyi nereye yüklemeli

İkon hep aynıdır (Tarak puanı için verilen taraklı "k" işareti, `tools/icon-source/tarak-rating-512.png`, yeniden çizilmedi);
**yalnız arka plan rengi** değişir. Varsayılan **Altın**. Kullanıcı rengi uygulama içinden seçer:
ilk açılışta (splash'tan hemen sonra, atlanabilir) ve sonra **Profil → Uygulama İkonu** (müşteri ve hizmet veren).

| Renk | id | Renk | id |
|---|---|---|---|
| Altın (varsayılan) | `altin` | Mavi | `mavi` |
| Lacivert | `lacivert` | Mor | `mor` |
| Krem | `krem` | Gül | `gul` |
| Turuncu | `turuncu` | Grafit | `grafit` |
| Bordo | `bordo` | Zümrüt | `zumrut` |

Önizleme: `store-assets/app-icons/renkler/_onizleme.png` (hepsi bir arada), her biri için 1024 px: `renkler/app-icon-1024-<id>.png`.

## Yeniden üretmek / renk değiştirmek
```bash
pip install Pillow
python tools/generate_app_icons.py        # mobile/ klasöründen
```
Renkler `tools/generate_app_icons.py` içindeki `PALETTE` listesinde (id, ad, iki degrade rengi). Betik Android, iOS, uygulama içi seçenek listesini
(`lib/core/app_icon/app_icon_options.dart`) ve bu klasörü birlikte yeniden yazar; sonra yeniden derle. Başka renk eklemek için `PALETTE`'e satır ekle.

## 1) Projede zaten yerinde (elle yüklenecek bir şey yok; yeni derlemeye girer)

### Android (`mobile/android/app/src/main/`)
| Dosya | Ne işe yarar |
|---|---|
| `AndroidManifest.xml` | Her renk için bir `<activity-alias>` (`.IconAltin`, `.IconLacivert`, …); aynı anda yalnız biri etkin. `MainActivity`'nin kendi başlatıcı girdisi yok |
| `kotlin/com/berberimgelsin/app/MainActivity.kt` | Uygulamadan gelen "ikonu değiştir" çağrısı: yeni alias'ı etkinleştirir, diğerlerini kapatır |
| `res/mipmap-mdpi … xxxhdpi/ic_launcher.png`, `ic_launcher_<id>.png` | Android 5–7 eski simgeler (48–192 px), köşeleri yuvarlak |
| `res/mipmap-anydpi-v26/ic_launcher.xml`, `ic_launcher_<id>.xml` | Android 8+ uyarlanabilir simge tanımları (renge özel arka plan + ortak ön plan + tek renk) |
| `res/drawable/ic_launcher_bg_<id>.xml` | Renk degradeleri |
| `res/drawable-*dpi/ic_launcher_foreground.png` | Ortak ön plan: işaret (şeffaf) |
| `res/drawable-nodpi/ic_launcher_monochrome.png` | Android 13+ "Temalı simgeler" için tek renk siluet |
| `res/drawable-nodpi/ic_launcher_mark.png`, `res/drawable*/launch_background.xml`, `res/values/brand_colors.xml` | Açılış ekranı: beyaz zemin + işaret (Android 12+ da aynı) |

### iOS (`mobile/ios/Runner/`)
| Dosya | Ne işe yarar |
|---|---|
| `Assets.xcassets/AppIcon.appiconset/` | Varsayılan (Altın) simge: tüm iPhone/iPad boyutları + **1024 App Store**; alfasız, tam kare |
| `Assets.xcassets/AppIcon-<Id>.appiconset/` (9 klasör) | Alternatif renkler (ör. `AppIcon-Lacivert`) |
| `../Runner.xcodeproj/project.pbxproj` | `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`: alternatif simge kümelerini uygulamaya katar (Xcode: Runner → Build Settings → "Alternate App Icon Sets") |
| `AppDelegate.swift` | Uygulamadan gelen çağrıyı `UIApplication.setAlternateIconName` ile uygular |
| `Assets.xcassets/LaunchImage.imageset/`, `Base.lproj/LaunchScreen.storyboard` | Açılış ekranı: beyaz zemin + işaret |

> iOS notları: ikon değişirken iOS kendi bilgi penceresini gösterir (kaldırılamaz). Alternatif simgeler Xcode 13+ gerektirir. Simgeler tam kare ve alfasızdır (App Store şartı); köşe yuvarlamayı iOS yapar.

### Uygulama içi (Flutter)
`lib/core/app_icon/` (servis + üretilmiş seçenek listesi), `lib/features/shared/screens/app_icon_screen.dart` (seçim ekranı),
`lib/features/shared/widgets/app_icon_card.dart` (profil kartı), `lib/features/auth/screens/auth_gate.dart` (ilk açılışta bir kez sorar).

## 2) Mağazaya ELLE yüklenecek dosyalar

| Mağaza | Dosya | Nereye |
|---|---|---|
| **Google Play** | `store-assets/app-icons/google-play/app-icon-512.png` (512×512) | Play Console → uygulaman → **Ana mağaza girişi** → *Uygulama simgesi*. Mağazada **yalnız varsayılan (Altın)** görünür; kullanıcının seçtiği renk yalnız kendi telefonunda geçerlidir |
| **App Store** | `store-assets/app-icons/ios-app-store/app-icon-1024.png` (1024×1024, alfasız) | Normalde elle yüklenmez: App Store Connect simgeyi derlemedeki `AppIcon.appiconset` 1024 px dosyasından alır (aynı görsel). Gerekirse Xcode → `Assets.xcassets` → `AppIcon` → *App Store* kutusu |

## 3) Derleme ve kontrol
- Android: `flutter build appbundle --release` (Play'e `.aab`) ya da `flutter build apk --debug`. Gerçek `key.properties`/keystore olmadan release imzalı olmaz (bkz. `RELEASE_READINESS.md`).
- iOS: macOS + Xcode gerekir: `flutter build ipa` → Xcode Organizer / Transporter.
- **Android'de doğrulandı** (Pixel_6a emülatörü): ilk açılışta splash'tan sonra seçim ekranı, renk seçince başlatıcıda yalnız seçilen alias'ın kalması ve simgenin değişmesi, profil kartı. Android ikon değişirken uygulamayı kapatabilir (sistem davranışı); ekranda bu not var.
- **iOS bu makinede (Windows) çalıştırılamadı**: `AppDelegate.swift`, alternatif simge kümeleri ve `pbxproj` ayarı yazıldı ama Xcode'da derlenip cihazda denenmedi. İlk Mac derlemesinde Profil → Uygulama İkonu'ndan bir renk seçip denemen gerekir.

## 4) Mağaza girişi için ayrıca gerekenler (bu işin kapsamı dışında)
- Google Play: **öne çıkan grafik 1024×500** ve en az 2 telefon ekran görüntüsü.
- App Store: iPhone ekran görüntüleri (6,9" ve 6,5"), gizlilik beyanı.
