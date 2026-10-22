# DEĞİŞİKLİK RAPORU — "İlk 500 TL komisyon Tarak.app'ten!", banka (IBAN) tahsilatı ve otomatik e-posta

Tarih: 2026-10-22 · Hiçbir sunucuya deploy / mağaza yüklemesi yapılmadı · Yerel geliştirme veritabanına dokunulmadı (testler ve arayüz denemesi yalnızca atılabilir `berberimgelsin_test` veritabanında).

## 1. Ne yapıldı (özet)
Mevcut finans mimarisi **korunarak** üstüne kuruldu; sıfırdan sistem yazılmadı.

| İstek | Sonuç |
|---|---|
| Hediye komisyon hakkı (gerçek para değil) | Mevcut 500 TL hoş geldin promosyonu (`promo_balance`) "hediye komisyon hakkı" oldu: yalnızca Tarak komisyonunu karşılar, çekilebilir nakit değildir, komisyonda nakitten önce kullanılır. **İkinci kez tanımlanmaz** (idempotent). Hediye / yüklenen (banka) / rezerve tutarlar ayrı raporlanır: `GET /provider/wallet` → `gift`, `deposited_balance`, `reserved_total`, `active_reservations`. |
| Komisyon server-side, atomik, çift kesinti yok | Mevcut mekanizma aynen: hesaplama sunucuda, rezervasyon `DB::transaction` + satır kilidi, `idempotency_key` + `resource` başına tek rezervasyon, tamamlanınca kesinleşir, iptalde serbest kalır, uyuşmazlıkta `HELD_DISPUTE`. Testlerle doğrulandı (çift capture = tek kesinti). |
| Hediye bitince tek seferlik e-posta | `GiftCommissionDepletedMail`: Tarak.app logolu, işletme adına, hediye kullanım özeti + kalan hesap durumu, ödeme detaylarının **İşletme Finans Merkezi**'nde olduğunu söyler (IBAN e-postada yok). Kuyruk (`SendGiftDepletedEmail`, 5 deneme, 1-5-15-60 dk geri çekilme), atomik "gönderildi" işareti (`wallets.gift_email_sent_at`) ile idempotent, saatlik süpürme komutu `finance:notify-gift-depleted`. |
| E-posta + web finans panelinden ödeme talimatı | Web **İşletme Finans Merkezi** (Cüzdan sekmesi) + "Ödeme Bilgilerimi E-postama Gönder" (`PaymentInstructionsMail`). |
| Flutter'da IBAN yok, "E-postama Gönder" var | Cüzdan ekranında hediye hakkı, yüklenen/rezerve/kullanılabilir, rezervasyonlar, hareketler ve düğme; IBAN/TRK kodu uygulamada **hiçbir yerde** gösterilmez (testle doğrulandı). Sunucu tarafı rate-limit: saatte 3 (+ rota başına dakikada 6). |
| Web finans bölümü | Şirket unvanı, IBAN, **eşsiz TRK referans kodu**, transfer açıklaması, "Ödeme bildir" formu, bildirim/hareket geçmişi, kopyala düğmeleri. Yalnızca giriş yapmış **onaylı işletme** görür (müşteri → 403, anonim → 401, onaysız işletme → 403). |
| Admin | **Finans & Banka Tahsilatı**: Banka Hesabı (IBAN doğrulamalı), Ödeme Bildirimleri (bekleyen/ödendi/reddedildi, incele-doğrula-reddet, TRK koduyla elle işle), Hesap Hareketleri (ledger), Denetim Günlüğü. **Dekont/bildirim tek başına bakiye eklemez**; yalnızca admin banka kaydını görüp doğrulayınca kredi yazılır; banka işlem referansı tekildir (aynı satır iki kez kredi vermez). |
| Kredi yetersizse | Yalnızca **yeni ücretli CASH teklif / doğrudan kabul** engellenir (422, `code: COMMISSION_CREDIT_INSUFFICIENT`, Finans Merkezi'ne yönlendiren ipucu). Onaylı randevular, iptaller ve uyuşmazlıklar normal çalışır (testle doğrulandı). |
| Kampanya mesajı | "İlk 500 TL komisyon Tarak.app'ten!" (tutar admin ayarındaki hoş geldin tutarını izler): web kayıt sonrası başvuru ekranı, mobil kayıt bilgi kutusu, web/mobil Finans Merkezi, API (`gift.campaign_message`). 500 TL hiçbir yerde çekilebilir nakit gibi gösterilmez. |
| Mağaza politikası | Açık ve dürüst akış: uygulama IBAN göstermez, kullanıcıyı yanıltacak gizleme yok; ödeme bilgileri web'de ve işletmenin kendi e-postasında. |
| PayTR/ONLINE | Dokunulmadı; yeni akış ONLINE'a bağımlı değil. |
| Veritabanı | Sıfırlanmadı. Migration yalnızca ekler. |

## 2. Değişen / eklenen dosyalar

### Backend (`tarak-backend/` — 27 dosya, zip'te)
**Yeni:**
`app/Models/CommissionTopup.php` · `app/Services/CommissionTopupService.php` · `app/Services/ProviderFinanceMailer.php` · `app/Services/MailSettingsApplier.php` · `app/Jobs/SendGiftDepletedEmail.php` · `app/Jobs/SendPaymentInstructionsEmail.php` · `app/Mail/GiftCommissionDepletedMail.php` · `app/Mail/PaymentInstructionsMail.php` · `app/Console/Commands/NotifyDepletedGiftCommand.php` · `app/Http/Controllers/Api/ProviderFinanceController.php` · `app/Http/Controllers/Api/AdminCommissionTopupController.php` · `database/migrations/2026_10_29_100000_create_commission_topups_and_gift_tracking.php` · `resources/views/emails/{layout,gift-depleted,payment-instructions}.blade.php` · `resources/brand/tarak-logo.png` (web'deki `public/brand/tarak-logo-header.png`'nin kopyası)

**Değişen:**
`app/Services/FinancialService.php` (hediye özeti, tükenme kancası, banka kredisi, aktif rezervasyonlar, kampanya metni) · `app/Models/{FinanceSetting,Wallet,ProviderProfile,WalletTransaction,AdminLog,UserNotification}.php` · `app/Http/Controllers/Api/ProviderServiceRequestController.php` (yetersiz-kredi yanıtına `code`/`hint`) · `app/Http/Controllers/Api/AdminIntegrationController.php` (SMTP testi panel değerleriyle) · `routes/api.php` · `routes/console.php` (saatlik süpürme)

**Notlar:** `FinanceSetting::current()` artık "ilk satırı" döndürür (eskiden `id = 1` arıyordu; silinen/geri alınan durumda ikinci satır üretebiliyordu). Panelde girilen SMTP değerleri önceden gerçek gönderimde kullanılmıyordu (yalnızca `.env`); artık `MailSettingsApplier` ile, yalnız `MAIL_MAILER=smtp` iken uygulanır.

### Web (`tarak.app/` — derlenmiş dosyalar; kaynak)
**Yeni kaynak:** `components/provider/FinanceCenter.tsx` · `components/admin/BankCollections.tsx`
**Değişen kaynak:** `pages/BarberDashboard.tsx` (cüzdan sekmesine Finans Merkezi, hediye/nakit metinleri) · `pages/AdminDashboard.tsx` (finans görünümü) · `pages/auth/ProfileCreate.tsx` (kampanya notu) · `pages/provider/Marketplace.tsx` (yetersiz kredi mesajı) · `services/api.ts` · `types.ts`
Zip'te: `tarak.app/index.html` + yeniden adlandırılan Vite dosyaları (+ önceki güncellemelerle birikimli konum verisi; hepsi güvenle tekrar yazılabilir).

### Mobil (`mobile/` — 5 dosya, zip'te)
`lib/features/provider/screens/provider_wallet_screen.dart` · `lib/features/provider/instant/providers/provider_instant_providers.dart` · `lib/features/provider/instant/screens/provider_request_detail_screen.dart` · `lib/features/auth/widgets/preauth_widgets.dart` · `test/provider_finance_center_test.dart` (yeni)

### Veritabanı (veri kaybettirmez)
`finance_settings` (+5 sütun), `wallets` (+2), `provider_profiles` (+`payment_reference` tekil), yeni tablo `commission_topups`. Laravel migration'ı **veya** `tarak-500-komisyon-patch.sql` (aynı sonucu verir). SQL patch, üretim dökümünün (4.593 MB, 5.203 kullanıcı) **geçici bir kopyasında** iki kez uygulanarak doğrulandı: satır sayıları değişmedi (yalnızca `migrations` kaydı +1), yapı Laravel migration'ıyla birebir aynı, `artisan migrate:status` bekleyen migration göstermiyor; kopya silindi.

## 3. Güvenlik ve para kuralları
- Bildirim/dekont bakiye eklemez; kredi yalnızca admin doğrulamasıyla, `COMMISSION_TOPUP:{id}` idempotency anahtarı + tekil banka referansı ile **bir kez** yazılır. Doğrulanan ödeme reddedilemez, reddedilen doğrulanamaz.
- Cüzdan defteri (`wallet_transactions`) değiştirilemez kalır; yeni hareket türü `COMMISSION_TOPUP_CREDIT`.
- IBAN/TRK yalnızca `auth:sanctum + role:PROVIDER` ve **onaylı** işletmeye; admin uçları `role:ADMIN`. Hediye e-postasında IBAN yoktur; ödeme bilgisi e-postası yalnızca hesaba kayıtlı adrese gider.
- Rate-limit: ödeme bildirimi dakikada 10, bilgi e-postası dakikada 6 + saatte 3 (429 + `retry_after`). Bekleyen bildirim sınırı 5, aynı tutar/tarih/gönderen çift tıklaması aynı kaydı döndürür.
- Denetim: banka ayarı kaydı, doğrulama, reddetme ve elle işleme `admin_logs`'a yazılır (Denetim Günlüğü sekmesi).
- Pakette `.env`, şifre, API anahtarı, `vendor`, `node_modules`, test dosyası, yerel yol yoktur (otomatik taranır).

## 4. Testler ve derleme (hepsi ana klasörde çalıştırıldı)
- **Backend:** yeni `GiftCommissionAndBankTopupTest` **24 test** (hediye tek sefer, promo-first + override korunur, tükenme e-postası tek kez + idempotent + hata sonrası yeniden deneme, kısmi kullanımda e-posta yok, yetersiz kredi yalnızca yeni CASH işi engeller / doğrulanmış yükleme açar, iptal/uyuşmazlık akışları, ödeme bilgisi yetkileri, bildirim bakiye eklemez, doğrulama tek kredi, tekil banka referansı, reddetme, TRK ile elle işleme, admin yetkileri, banka ayarı doğrulama + denetim, liste/ledger/denetim, e-posta + rate-limit). Tüm backend takımı: **820 test geçti (5.108 doğrulama)**; mevcut finans/yaşam döngüsü/uyuşmazlık testleri değişmeden geçiyor (yalnızca `FinancialLedgerTest::test_09`'a yeni `code` alanı için bir doğrulama satırı eklendi).
- **Web:** `tsc` hata sayısı değişmedi (31, hepsi eski); `vite build` temiz. Yerel arayüz denemesi (geçici API → test veritabanı): Finans Merkezi (hediye 500/60/440, yüklenen 250, rezerve 150, IBAN + TRK kodu), "E-postama Gönder" (kayıtlı adrese ileti üretildi, logo gömülü), admin doğrulama (950 TL → yüklenen bakiye 250 → 1.200). İki e-posta şablonu 640 px'te görsel olarak kontrol edildi.
- **Flutter:** `flutter analyze` temiz; **440 test geçti** (önceki 436 + 4 yeni: hediye/rezerve/kullanılabilir/rezervasyon gösterimi, tükenmiş hediye, IBAN'ın hiç gösterilmemesi + e-posta isteği, 429 mesajı).

## 5. Bilinen sınırlar / kararlar
- Hediye, yeni bir bucket yerine mevcut **promo bucket** olarak tutuldu (ledger/uyum için); arayüzde "Hediye komisyon hakkı" olarak adlandırılır. Eski ledger satırlarının açıklaması "Promosyon" olarak kalır (değişmez kayıt); rozetler yeni dili gösterir.
- Tükenme e-postası, **son hediye tutarı tamamlanan hizmette kesinleşince** gider (rezervasyon anında değil); önceden tükenmiş eski hesaplara toplu e-posta atılmaz.
- Hesabında e-posta olmayan işletme için yalnızca uygulama içi bildirim oluşur.
- Tam üretim paketi/SQL'i (`tarak-cpanel-full-production.zip`, `tarak-full-production.sql`) yeniden üretilmedi (bu klasördeki güncelleme üzerine yazılır); sıfırdan kurulumda import sonrası `php artisan migrate --force` çalıştırın.
- Ürün hukuku: hediye/komisyon metinleri ve ticari ileti içeriği yayın öncesi hukuk tarafından kontrol edilmelidir.
