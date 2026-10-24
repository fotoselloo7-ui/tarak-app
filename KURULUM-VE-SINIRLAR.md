# Tarak.app — Premium Bildirim Merkezi (24 Ekim 2026)

## Uygulananlar

- Admin → Öne Çıkarma & Reklam → Bildirim Reklamı ekranının **üstüne** ayrı bir Premium Bildirim Merkezi eklendi. Berberlerin ücretli bildirim reklamı ayarları ve satın alım akışları korunmuştur.
- Sunucuda `admin_broadcasts` tablosu için yeni Laravel migration ve yeni ADMIN-only API uçları vardır.
- Herkese / müşteri / hizmet veren, isteğe bağlı il/ilçe hedefleme, alıcı tahmini ve aktif push cihazı sayısı.
- Taslak, test (yalnız oturum sahibi admine), hemen gönder, ileri tarihli gönderim, duraklat, sürdür, iptal ve geçmiş.
- 80 kişilik kuyruk partileri. Aynı kullanıcıya aynı kampanya için tekrar bildirim kaydetmeme garantisi mevcut `idempotency_key` ile sürdürülür.
- Ticari/sponsorlu bildirimler için **veritabanına açıkça kaydedilmiş** `push_enabled=true` VE `campaign_enabled=true` tercihi ve aktif FCM cihazı gerekir. Varsayılan true ancak hiç kaydedilmemiş tercih, **açık onay sayılmaz**.
- Mevcut `SendPushNotification` kuyruk işçisi, kampanya iznini gerçek gönderim anında yeniden kontrol eder.
- Sponsorlu bildirimler bildirim başlığında **Sponsorlu** etiketiyle ayrılır.

## Yerel projeye uygulama

1. GitHub Desktop'ta mevcut Tarak repo klasörünüzde (ör. `C:\Projeler\TARAK-APP-FINAL-KAYNAK`) yeni değişiklikleriniz varsa commit edin ve `Fetch origin` → `Pull origin` yapın.
2. Bu ZIP'in içindekileri **repo kökünün üzerine**, mevcut yolları koruyarak çıkartın: `tarak-backend/...` ve `tarak.app/assets/...`.
3. GitHub Desktop'ta değiştirilmiş dosyaları kontrol edin, `Commit to main` ve `Push origin` yapın. Bu ZIP'in kendisini repository içine eklemeyin.
4. PHP kodunun ve UI entegrasyonunun tam testini çalıştırın. Bu pakette sözdizimi kontrolleri geçmiştir; gerçek Laravel DB/FCM entegrasyon testi bu ortamda çalıştırılmadı.

## Canlı cPanel'e alma (yayınlanan site otomatik güncellenmez)

1. **Önce** hem `tarak.app`, hem `tarak-backend`, hem MySQL veritabanı yedeğini alın.
2. Paket içindeki **yalnızca** `tarak.app/` ve `tarak-backend/` klasörlerini cPanel'de ikisinin ortak üst dizinine açın. Önceki ekrana göre `/home/alac6ayazilimtr/` idi; mevcut dizini doğrulayın.
3. Laravel dizininde `php artisan migrate --force` çalıştırın. Bu, `admin_broadcasts` tablosunu oluşturur; tam SQL dökümünü tekrar içe aktarmayın.
4. Gerçek FCM anahtar dosyasını `/home/<cpanel-user>/` altında web'den erişilemeyen güvenli bir dizine koyun. `.env`: `FCM_ENABLED=true`, `FCM_PROJECT_ID=tarak-app-af491`, `GOOGLE_APPLICATION_CREDENTIALS=/tam/yol/anahtar.json`. Sunucuda `config:cache` kullanılıyorsa yeniden oluşturun.
5. Laravel `push` kuyruğunun ve `php artisan schedule:run` cron'unun çalıştığını doğrulayın. Planlanan gönderimler ve retry bunlara bağlıdır.
6. Yönetici panelinde önce test bildirimi gönderin. Tek kullanıcı, sonra küçük izinli grup üzerinde doğrulayın; doğrudan herkese sponsorlu kampanya başlatmayın.

## Firebase / mağaza kalanları

- `mobile/ios/Runner/GoogleService-Info.plist` ve Xcode Copy Bundle Resources bağlantısı daha önce **doğrudan GitHub'a** işlendi; bu pakette kopyalanmaz. `mobile/android/app/google-services.json` da GitHub'da mevcut.
- iOS Push Notifications entitlement, APNs `.p8` anahtarı, Team ID, Xcode imzalama ve macOS build işlemleri henüz tamamlanmadı.
- Android yükleme keystore'u ve imzalı AAB henüz oluşturulmadı.
- Firebase istemci yapılandırmaları **FCM sunucu kimlik bilgileri değildir**. Servis hesabının gizli anahtarını GitHub'a koymayın.

## Ticari ileti / kullanıcı onayı

Kampanya/sponsorlu iletiler için şirketin uyum yükümlülükleri (KVKK ve ilgili ticari elektronik ileti mevzuatı dahil) yayın öncesi hukuk ekibiyle kontrol edilmeli. Mevcut uygulamada kampanya ayarının varsayılan gösterimi `true` olabilir; açık rıza/onay metinleri ve kayıt mekanizması ayrıca doğrulanmadan bu varsayım reklam izni sayılmamalıdır. Paket alıcı sorgusu bu yüzden **kaydedilmiş tercihi** zorunlu tutar.

## Bilinen teknik sınırlar

- Repo'da düzenlenebilir React/TypeScript web kaynağı yerine derlenmiş `tarak.app/assets` dosyaları bulunduğu için admin merkezi mevcut derlenmiş JS chunk'ına minimal, ek bir ESM modülüyle bağlandı. Ana web uygulaması ileride yeniden derlenirse bu entegrasyon **orijinal React kaynak projesine taşınmalıdır**; aksi halde yeni build tarafından silinebilir.
- Bildirim kaydı oluşturulması, gerçek FCM cihaz teslimatı anlamına gelmez. Teslimat için cihaz tokenları, FCM servis hesabı, kuyruk ve Apple APNs gerekir. Ekrandaki `notifications_created` metriği 'bildirim kaydı' sayısıdır; teslim edildi bilgisi değildir.
- `action_url` alanı şimdilik uygulama içindeki güvenli yolu veri olarak kaydeder; mobil kabuğun tüm olası özel yolları otomatik açması uygulanmış değildir. Bilinmeyen yollar için uygulama varsayılan ana ekrana döner. İleri aşamada doğrulanmış deep-link hedefleri eklenmelidir.
- Firebase Analytics Firebase konsolunda açılmış olsa bile `firebase_analytics` mobil SDK'sı ve özel olay takibi henüz entegrasyon kapsamına dahil değildir.

## Paket içeriği

- `tarak-backend/routes/api.php`, `routes/console.php`
- `tarak-backend/app/Http/Controllers/Api/AdminBroadcastController.php`
- `tarak-backend/app/Services/AdminBroadcastAudience.php`
- `tarak-backend/app/Jobs/ProcessAdminBroadcast.php`, `SendPushNotification.php`
- `tarak-backend/app/Models/AdminBroadcast.php`, `UserNotification.php`
- `tarak-backend/database/migrations/2026_10_29_090000_create_admin_broadcasts_table.php`
- `tarak.app/assets/PremiumBroadcastCenter.js`, `AdminDashboard-DW6WIR4K.js`, `index-Bj5sn6If.js`
