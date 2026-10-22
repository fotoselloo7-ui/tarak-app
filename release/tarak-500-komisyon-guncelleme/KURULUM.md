# KURULUM — "İlk 500 TL komisyon Tarak.app'ten!" + banka (IBAN) komisyon tahsilatı

Bu klasör **hiçbir sunucuya yüklenmedi**; dosyaları sizin yüklemeniz gerekir. Mevcut kullanıcılar, cüzdanlar, hareketler ve randevular korunur: bu güncelleme yalnızca **ekler** (yeni sütun/tablo), hiçbir veriyi silmez veya sıfırlamaz.

| Dosya | Ne işe yarar | Nereye |
|---|---|---|
| `tarak-web-ustune-yaz.zip` | Web (derlenmiş site + admin) **ve** backend (Laravel) değişen dosyaları | cPanel kullanıcı klasörü (`/home/<cpanel-kullanıcısı>/`) |
| `tarak-mobile-ustune-yaz.zip` | Flutter uygulamasında değişen dosyalar | Proje kökü (`C:\Projeler\berberimgelsin (2)\`) |
| `tarak-500-komisyon-patch.sql` | SSH yoksa: veritabanı değişikliği (veri kaybettirmez, tekrar çalıştırılabilir) | phpMyAdmin → İçe Aktar |
| `DEGISIKLIK_RAPORU.md` | Ne değişti, hangi dosyalar, testler | — |

> Ana çalışma klasöründeki kod (`C:\Projeler\berberimgelsin (2)`) bu değişikliklerle **zaten güncel**; zip'ler yalnızca canlı sunucuya / başka bir kopyaya taşımak içindir.

---

## 0) Başlamadan önce
1. cPanel → **phpMyAdmin → Dışa Aktar** ile veritabanı yedeği alın.
2. `tarak.app/` ve `tarak-backend/` klasörlerinin yedeğini alın (cPanel Dosya Yöneticisi → Sıkıştır).

## 1) Web + backend (cPanel)
1. `tarak-web-ustune-yaz.zip` dosyasını cPanel **Dosya Yöneticisi**nde `/home/<cpanel-kullanıcısı>/` klasörüne yükleyin (`public_html` değil; önceki güncellemelerle aynı yer).
2. Zip'e sağ tık → **Extract**. İçerik `tarak.app/` ve `tarak-backend/` altına **birleşir**. `.env`, `.htaccess`, `storage/`, `vendor/` ve demo-media zip'te yoktur, ezilmez.
3. Veritabanını güncelleyin — **iki yoldan biri** (ikisini birden yapmanız gerekmez, yaparsanız da zarar vermez):
   - **SSH / cPanel Terminal varsa (önerilen):**
     ```
     cd /home/<cpanel-kullanıcısı>/tarak-backend
     /usr/local/bin/ea-php82 artisan migrate --force
     ```
   - **Terminal yoksa:** phpMyAdmin'de uygulamanın veritabanını seçin → **İçe Aktar** → `tarak-500-komisyon-patch.sql` → Git. (Dosya `migrations` tablosuna kaydı da ekler; sonradan `migrate` çalıştırırsanız yeniden çalışmaz.)
4. Önbellekleri yenileyin (Terminal varsa):
   ```
   cd /home/<cpanel-kullanıcısı>/tarak-backend
   /usr/local/bin/ea-php82 artisan optimize:clear
   /usr/local/bin/ea-php82 artisan config:cache
   /usr/local/bin/ea-php82 artisan route:cache
   /usr/local/bin/ea-php82 artisan view:cache
   /usr/local/bin/ea-php82 artisan queue:restart
   ```
   Terminal yoksa `tarak-backend/bootstrap/cache/` içindeki `config.php`, `routes-v7.php`, `events.php` gibi önbellek dosyalarını silin.
5. Tarayıcıda siteyi **Ctrl + F5** ile yenileyin.

## 2) İlk kez yapılması ZORUNLU ayarlar (admin paneli)
Bunlar yapılmazsa işletmeler ödeme bilgilerini göremez ve e-posta gitmez.

1. **Banka hesabı:** Admin → **Finans & Banka Tahsilatı** → **Banka Hesabı** sekmesi → şirket unvanı, banka adı, **IBAN**, en az yükleme tutarı → **Kaydet**. IBAN doğrulanır (TR + sağlama basamağı). Kaydedilince işletmelerin Finans Merkezi'nde görünür.
2. **SMTP:** Admin → **Entegrasyon Merkezi → E-posta / SMTP** → bilgileri girin → **Test e-postası gönder**. Sunucudaki `tarak-backend/.env` içinde `MAIL_MAILER=smtp` olmalıdır (`log` ise e-postalar gerçekten gitmez, yalnızca günlüğe yazılır). Panelde girilen SMTP değerleri artık işletme e-postalarında da kullanılır.
3. **Kuyruk işçisi:** e-postalar kuyruktan gider. Mevcut cron satırınız (`queue:work --queue=push,default --stop-when-empty …`, bkz. `INSTALL_CPANEL_FULL.md`) bunu zaten yapıyor; **Entegrasyon Merkezi → Kuyruk** sağlıklı görünmelidir. Zamanlayıcı (`schedule:run`, her dakika) yeni saatlik `finance:notify-gift-depleted` komutunu kendiliğinden çalıştırır.
4. (İsteğe bağlı) **Finans Ayarları**: hoş geldin hediyesi tutarı (varsayılan 500) ve varsayılan komisyon (%15). Kampanya mesajı tutarı buradan alır: "İlk 500 TL komisyon Tarak.app'ten!".

## 3) Canlıda hızlı kontrol listesi
- [ ] Onaylı bir işletmeyle giriş → **Cüzdan** sekmesi → "İşletme Finans Merkezi": hediye hakkı kartı, yüklenen / rezerve / kullanılabilir tutar, IBAN + **TRK referans kodu**.
- [ ] "Ödeme Bilgilerimi E-postama Gönder" → kayıtlı e-postaya Tarak.app logolu ileti gelir (saatte en fazla 3).
- [ ] İşletme "Ödeme bildir" → Admin → Ödeme Bildirimleri'nde **Bekleyen** görünür; bakiye **değişmez**.
- [ ] Admin bankada ödemeyi görünce **İncele → banka işlem referansı + tutar → Doğrula**: işletmenin yüklenen bakiyesi artar, Hesap Hareketleri'nde `Banka yüklemesi`, Denetim Günlüğü'nde kayıt oluşur.
- [ ] Müşteri/anonim ziyaretçi `https://tarak.app/api/provider/finance/payment-info` adresini açamaz (401/403).
- [ ] Bir işletmenin hediye hakkı bitince **tek** "Hediye komisyon hakkınız tamamlandı" e-postası gider.

## 4) Mobil (Flutter)
1. `tarak-mobile-ustune-yaz.zip` dosyasını proje köküne (`C:\Projeler\berberimgelsin (2)\`) açın; `mobile/lib/...` ve `mobile/test/...` altındaki 5 dosya ezilir.
2. Kontrol:
   ```
   cd mobile
   flutter analyze
   flutter test
   ```
3. Yeni sürümü her zamanki gibi derleyin/mağazaya yükleyin (sürüm numarasını artırın). Mağaza notu: uygulama **IBAN göstermez**; ödeme bilgileri yalnızca web Finans Merkezi'nde ve işletmenin kayıtlı e-postasında yer alır. Komisyon bakiyesi, işletmenin Tarak'a ödediği platform komisyonudur (gerçek dünyadaki hizmetin komisyonu); dijital içerik satışı değildir. Metinler "hediye hak çekilebilir nakit değildir" diyerek dürüst bırakılmıştır.

## 5) Geri alma
- Web/backend: yedeklediğiniz `tarak.app/` ve `tarak-backend/` klasörlerini geri yükleyin. Yeni sütun/tablo kullanılmasa da zarar vermez; silmek isterseniz `php artisan migrate:rollback --step=1` (yalnızca yeni tabloyu ve sütunları kaldırır, ekleme dışındaki veriye dokunmaz).
- Mobil: önceki sürüm paketine dönün.

## 6) Sık sorulanlar
- **İşletme IBAN'ı göremiyor:** hesabı onaylı mı? Admin panelde banka hesabı girildi mi?
- **E-posta gelmiyor:** `.env` → `MAIL_MAILER=smtp`; Entegrasyon Merkezi → SMTP test; kuyruk cron'u çalışıyor mu? Başarısız işler: Entegrasyon Merkezi → Başarısız İşler → yeniden dene.
- **Aynı banka işlemini iki kez girdim:** sistem ikinci kez kredi vermez (banka işlem referansı tekildir).
- **Yanlışlıkla doğruladım:** doğrulanan ödeme geri alınmaz (cüzdan defteri değiştirilemez). Düzeltme gerekirse geliştirici ile telafi kaydı oluşturun; veritabanında elle düzenleme yapmayın. Bu yüzden **doğrulamadan önce banka hesap hareketini mutlaka görün**.
