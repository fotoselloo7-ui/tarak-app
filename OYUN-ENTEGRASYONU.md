# "Randevuya Koş" oyunu entegrasyonu

Oyun ayrı bir projedir (oyun sunucusu: PHP, kendi veritabanı). Tarak tek doğruluk kaynağıdır:
hesap, sponsor işletmeler ve kuponlar Tarak'ta tutulur.

## Akış

1. Oyuncu oyunda hediye parçalarını toplar (oyun sunucusu hile denetimiyle sayar).
2. Parçalar tamamlanınca oyun **"Tarak ile giriş"** ister: oyuncu Tarak'ın kendi sayfasına
   (`/api/game/giris`) yönlenir; şifre oyuna hiç gitmez. Tarak tek kullanımlık kodla (5 dk) oyuna döner,
   oyun sunucusu kodu sunucudan sunucuya değiştirir (`POST /api/game/kod`).
3. Oyun sunucusu `POST /api/game/hediye` der. Tarak, oyuncunun **ilçesinde** (yoksa ilinde) kotası
   dolmamış sponsor işletmeyi seçer ve kuponu üretir (`TRK-XXXX-XXXX`, 30 gün geçerli, hesap başına yılda bir).
4. Kupon aynı anda müşterinin **Oyun Hediyelerim** ekranında ve sponsor işletmenin
   **Oyuna Sponsor Ol** ekranında görünür. Berber kodu doğrular ve "kullanıldı" işaretler.
5. Sponsorun logosu, o bölgedeki oyunculara hangi haritayı oynarlarsa oynasınlar oyunda görünür;
   gösterimler `POST /api/game/gosterim` ile Tarak'a yazılır, berber istatistiği panelinde görür.

## Kurulum (tarak-backend)

```
php artisan migrate        # game_settings, game_auth_codes, game_sponsorships, game_coupons, game_impressions
```

`.env`:

```
GAME_SERVER_KEY=<uzun rastgele anahtar>                 # oyun sunucusuyla paylaşılır
GAME_RETURN_URLS=https://tarak.app/oyun,tarakoyun://giris   # "Tarak ile giriş" sonrası dönülebilecek adresler
```

Oyunun yönetim panelinde (Ayarlar › Tarak bağlantısı): Tarak API adresi `https://tarak.app/api`
ve aynı `GAME_SERVER_KEY`. Boş bırakılırsa oyun kendi kuponunu üretir (eski davranış).

## Uçlar

| Uç | Kim | Ne |
|---|---|---|
| `GET /api/game/giris`, `POST /api/game/giris` | oyuncu | Tarak giriş sayfası, tek kullanımlık kodla dönüş |
| `POST /api/game/kod` | oyun sunucusu (`X-Oyun-Anahtar`) | kodu kullanıcı kimliği + il/ilçe ile değiştirir |
| `POST /api/game/hediye` | oyun sunucusu | bölgedeki sponsordan kupon üretir |
| `POST /api/game/gosterim` | oyun sunucusu | sponsor reklam gösterimleri |
| `GET /api/game/sponsorlar?il=&ilce=` | herkes | oyundaki tabelalar için bölgenin sponsorları |
| `GET /api/game/linkler` | herkes | oyun indirme bağlantıları |
| `GET /api/customer/game-coupons` | müşteri | Oyun Hediyelerim |
| `GET/POST /api/provider/game-sponsorship` | işletme | Oyuna Sponsor Ol (hizmet, berber/kuaför, ilçe/il, aylık kota) |
| `GET /api/provider/game-coupons`, `POST /api/provider/game-coupons/verify` | işletme | kuponlar, doğrula / kullanıldı |
| `GET /api/provider/game-stats` | işletme | gösterim, oyuncu, harita bazında dağılım |
| `GET/PUT /api/admin/game/settings`, `GET /api/admin/game/stats` | yönetici | indirme linkleri, istatistik |

## Ekranlar

- Mobil (Flutter): `lib/features/game/game_screens.dart` — müşteri profili › **Oyun Hediyelerim**,
  işletme profili › **Oyuna Sponsor Ol**.
- Web yönetici: `tarak.app/oyun-yonetim/` (yönetici oturumuyla; indirme linkleri ve istatistik).
  Web sitesinin React kaynağı bu depoda olmadığı için müşteri/işletme web panellerine ekran eklenmedi;
  kaynak eklendiğinde aynı uçlar kullanılır.

## Testler

`tests/Feature/GameIntegrationTest.php` (giriş, bölgeye göre kupon, işletme doğrulaması, süre, istatistik).
Oyun deposunda `tests/tarak-entegrasyon-test.js` iki sunucuyu uçtan uca dener.
