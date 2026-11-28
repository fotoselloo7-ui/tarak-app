# İşletme sponsorlu hediyeler ve Tarak hesabı entegrasyonu (plan)

Amaç: tarak.app'teki berber ve kuaförler oyuna sponsor olur. Oyuncunun kazandığı hediye
(ör. sakal tıraşı, manikür) **oyuncunun bölgesindeki** bir sponsor işletmeden gelir.
Kupon aynı anda müşterinin Tarak profilinde ve sponsor işletmenin hesabında görünür.

## Temel karar: tek doğruluk kaynağı Tarak

| Konu | Nerede tutulur |
|---|---|
| Kullanıcı hesabı, giriş | Tarak (oyun "Tarak ile giriş yap" kullanır) |
| İşletmeler, sponsorluk kotaları, bölge | Tarak (işletme panelinde "Oyuna Sponsor Ol") |
| Kuponlar (kod, durum, işletme, müşteri) | Tarak — müşteri profili ve işletme paneli aynı kaydı görür |
| Oyun skoru, parça sayımı, hile denetimi | Oyun sunucusu |
| İstatistikler, oyun indirme linkleri | Tarak admin paneli (oyun sunucusundan özet çeker) |

Oyun sunucusu yalnızca "bu Tarak kullanıcısı bu yıl hediye hakkı kazandı" der; kuponu Tarak üretir.
Böylece iki kopya arasında eşitleme sorunu olmaz, kupon tek yerde yaşar.

## Akış

1. Oyuncu misafir oynayabilir; parçalar birikir. **Hediye almak için Tarak ile giriş zorunlu**
   (yılda bir hak hesap başına uygulanır, cihaz değiştirerek hile yapılamaz).
2. Giriş: oyun → tarak.app giriş sayfası → oyuna tek kullanımlık kod ile dönüş (OAuth tarzı).
   Oyun bu kodla Tarak'tan kullanıcı kimliğini (ve il/ilçe bilgisini) alır.
3. Parçalar tamamlanınca oyun sunucusu, Tarak'a `hak-kazandi` bildirir (sunucudan sunucuya, imzalı).
4. Tarak, oyuncunun **ilçesindeki** aktif sponsorlardan kotası olanı seçer
   (ilçede yoksa il, ilde de yoksa Tarak'ın genel hediyesi) ve kuponu oluşturur.
5. Kupon: müşterinin Tarak profilinde "Oyundan kazandığın hediyeler" bölümünde,
   sponsor işletmenin panelinde "Bekleyen oyun kuponları" bölümünde görünür.
   Oyunda da sponsorun logolu küçük kartı (ad, ilçe, hizmet, son kullanma tarihi) gösterilir.
6. Müşteri randevu alır; berber kodu/QR'ı panelden doğrular → kupon "kullanıldı".

## Konum ve KVKK

- Hassas GPS gerekmez: **il/ilçe** yeterli. Önce Tarak profilindeki adresin ilçesi kullanılır;
  yoksa hediye anında (oyun başında değil) konum izni istenir ve yalnızca ilçe saklanır.
- Koordinat saklanmaz; açık rıza ve aydınlatma metni gerekir.

## İşletme paneli: "Oyuna Sponsor Ol"

- Hizmet seçimi (yalnızca işletmenin sunduğu hizmetler: ör. Sakal Tıraşı, Manikür).
- Kota (ör. ayda 10 hediye), başlangıç–bitiş tarihi, bölge (kendi ilçesi / il).
- Kota bitince sponsorluk otomatik durur. Sponsor logosu oyunda o bölgedeki oyunculara görünür.
- Kupon doğrulama ve kullanım geçmişi.

## Tarak admin paneli

- Oyun indirme linkleri (App Store / Google Play / web) düzenlenebilir.
- İstatistik: oyuncu sayısı, Tarak hesabına bağlanan oyuncular, kazanılan / kullanılan kuponlar,
  sponsor bazında dağılım, bölge haritası.

## Oyunda hazır olanlar (Sürüm 12)

- **Bölge**: oyuncu isim ekranında il/ilçesini seçer (isteğe bağlı, konum izni yok). Oynadığı harita serbest.
- **Sponsor reklamı**: admin › Sponsorlar'da eklenen işletmenin tabelası/panosu, bölgesi o işletmenin il/ilçesi
  olan oyunculara **hangi ilde oynarlarsa oynasınlar** görünür (şehirde dükkân tabelası, yolda pano).
  Sponsor yoksa boş panolarda "Berberler, kuaförler: oyuna sponsor ol" reklamı çıkar.
- **Gösterim sayacı**: koşu başına sponsor başına bir gösterim; şüpheli/çok kısa koşular sayılmaz.
- **Berber paneli için uç**: `GET api/index.php?islem=sponsorIstatistik&isletme=<Tarak işletme no>`
  (başlık `X-Tarak-Anahtar`) → toplam gösterim, tekil oyuncu, son 30 gün, rota (il/ilçe) bazında dağılım.
- **Kupon**: alındıktan sonra 30 gün geçerli; süresi dolan kod geçersizdir.

## Önceden hazır olanlar

- Parçalar zor yerlerde, sunucuda hileye karşı sayılır; yılda bir hak.
- `hediyeDogrula` / `hediyeKullan` uçları (bkz. TARAK-HEDIYE-ENTEGRASYON.md) — Tarak tarafı
  kuponu üretecek şekilde değiştirilirken bu uçlar "hak kazandı" bildirimine dönüştürülecek.

## Gerekenler

- Tarak Berber Çağır deposuna erişim (GitHub) ve hangi teknolojiyle yazıldığı.
- Oyunun yayınlanacağı adres (ör. mobil.tarak.app) ve Tarak API'sinin adresi.
