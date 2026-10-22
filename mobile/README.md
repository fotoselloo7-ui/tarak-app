# app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Firebase / FCM yapılandırması

Repoda Firebase config dosyası yoktur; gerçek Firebase projesinden indirilen dosyalar
aşağıdaki yerlere konur. Dosya yoksa uygulama yine derlenir ve çalışır, yalnız push kapalı kalır
(`PushNotificationService` log'a `Firebase init gracefully skipped` yazar, cihaz backend'e kaydedilmez).

`Firebase.initializeApp()` bilerek seçeneksiz çağrılır: ayarları aşağıdaki native dosyalardan okur,
`firebase_options.dart` kullanılmaz.

### Android
- Firebase Console'da Android uygulamasını paket adı `app.tarak.mobile` ile kaydedin.
- `google-services.json` → `mobile/android/app/google-services.json`
- `android/app/build.gradle.kts` dosyayı görünce `com.google.gms.google-services` (4.4.2) eklentisini
  uygular; eklenti `android/settings.gradle.kts` içinde `apply false` ile tanımlıdır. Dosya yokken build
  `google-services.json not found in android/app; Firebase/FCM is disabled for this build.` satırını yazar.
- JSON içindeki `package_name` `app.tarak.mobile` değilse `process*GoogleServices` görevi build'i durdurur.

### iOS
- Firebase Console'da iOS uygulamasını bundle ID `app.tarak.mobile` ile kaydedin.
- `GoogleService-Info.plist` → `mobile/ios/Runner/GoogleService-Info.plist`
- Dosyayı yalnız klasöre kopyalamak yetmez: Xcode'da `ios/Runner.xcworkspace` açılıp dosya Runner grubuna
  sürüklenmeli ve **Runner** target'ı işaretlenmeli (Build Phases → Copy Bundle Resources içinde görünmeli).
- Runner → Signing & Capabilities: **Push Notifications** ve **Background Modes → Remote notifications**.
- APNs Authentication Key (.p8) Firebase Console → Project Settings → Cloud Messaging'e yüklenmeli;
  aksi halde iOS'ta FCM token alınamaz.

### Backend
Gönderim tarafı `backend/.env` içindedir (`FCM_ENABLED`, `FCM_PROJECT_ID`, `GOOGLE_APPLICATION_CREDENTIALS`
= service account JSON yolu). `FCM_PROJECT_ID`, mobil config dosyalarıyla aynı Firebase projesi olmalıdır.
