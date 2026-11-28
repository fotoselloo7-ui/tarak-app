<?php
// Oyun API'si. Çerez kullanmaz; kimlik doğrulama oturum jetonu iledir.
declare(strict_types=1);
require __DIR__ . '/../inc/baslat.php';

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
header('X-Content-Type-Options: nosniff');
header('Access-Control-Allow-Origin: *');        // Android paketi file:// kökeninden bağlanır
header('Access-Control-Allow-Headers: Content-Type, X-Tarak-Anahtar');
if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') { http_response_code(204); exit; }

function cevap(array $v, int $kod = 200): void
{
    http_response_code($kod);
    echo json_encode($v, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}
function hata(string $m, int $kod = 400): void { cevap(['hata' => $m], $kod); }

function govde(): array
{
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') hata('POST gerekli', 405);
    $ham = (string) file_get_contents('php://input', false, null, 0, 4096);
    $v = json_decode($ham, true);
    if (!is_array($v)) hata('Geçersiz veri');
    return $v;
}
function metin(array $v, string $k, int $uz = 64): string { return isset($v[$k]) && is_scalar($v[$k]) ? mb_substr((string) $v[$k], 0, $uz) : ''; }
function sayi(array $v, string $k, int $ust = 100000000): int { return isset($v[$k]) && is_numeric($v[$k]) ? max(0, min($ust, (int) $v[$k])) : 0; }

function oturum(string $jeton): array
{
    if (!preg_match('/^[a-f0-9]{48}$/', $jeton)) hata('Oturum yok', 401);
    $o = tm_satir('SELECT t.*, p.engelli, p.ad FROM oturumlar t JOIN oyuncular p ON p.id = t.oyuncu_id WHERE t.jeton = ?', [$jeton]);
    if (!$o || $o['baslangic'] < time() - 86400) hata('Oturum yok', 401);
    return $o;
}

/** Skorun fiziksel olarak mümkün olup olmadığını kontrol eder. */
function supheli_mi(int $bolum, string $zorluk, bool $devam, string $sonuc, int $skor, int $tarak, int $can, float $sure, int $mesafe, int $gecen, float $carpan): bool
{
    $canUst = ['kolay' => 5, 'orta' => 4, 'zor' => 3][$zorluk];
    $puan = ['kolay' => 1.0, 'orta' => 1.5, 'zor' => 2.0][$zorluk];
    if ($sure > $gecen + 4 || $can > $canUst) return true;
    $turboHiz = 1.35 * max(0.5, $carpan);
    if ($bolum >= TM_UC) {
        // En yüksek hız: 24 m/sn × turbo/jet çarpanları
        if ($mesafe > ($gecen + 4) * 55 * max(1.0, $carpan) + 100) return true;
        if ($tarak > $mesafe * 1.2 + 80) return true;
        $durak = intdiv($mesafe, 350) + 1;
        $bonus = $durak * 150 + 25 * $durak * ($durak - 1) + (int) ($mesafe / 8) * 25;
        return $skor > ($mesafe * 2 + $tarak * 10 + $bonus + 100) * $puan;
    }
    if ($bolum === 0) {
        if ($mesafe > ($gecen + 4) * 375 * $turboHiz + 800) return true;
        if ($tarak > $mesafe / 25 + 30) return true;
        return $skor > ($tarak * 10 + (int) ($mesafe / 20) + (int) ($mesafe / 200) * 25 + 50) * $puan;
    }
    $b = tm_bolumler()[$bolum]['modlar'][$zorluk] ?? null;
    if (!$b) return true;
    if ($tarak > $b['tarak']) return true;
    $tavan = $tarak * 10 + $b['koli'] * 25;
    if ($sonuc === 'kazandi') {
        // Yarı yoldan devam eden koşu yolun yalnızca ikinci yarısını oynar.
        $enAzSure = $b['uzunluk'] / ($b['hiz'] * $turboHiz) * ($devam ? 0.22 : 0.9);
        if ($gecen + 2 < $enAzSure || $mesafe < $b['uzunluk'] - 5) return true;
        $tavan += 500 + $bolum * 50 + 3 * 150;
    }
    return $skor > $tavan * $puan;
}

try {
    $islem = (string) ($_GET['islem'] ?? '');
    $ayar = tm_ayarlar();

    switch ($islem) {
        case 'ayar':
            cevap([
                'oyunAktif' => $ayar['oyun_aktif'] === '1',
                'bakimMesaji' => $ayar['bakim_mesaji'],
                'duyuru' => $ayar['duyuru'],
                'randevuUrl' => $ayar['randevu_url'],
                'randevuMetni' => $ayar['randevu_metni'],
                'uygulamaUrl' => $ayar['uygulama_url'] ?? 'https://tarak.app/',
                'webUrl' => $ayar['uygulama_url'] ?? 'https://tarak.app/',
                'iosUrl' => $ayar['uygulama_ios'] ?? '',
                'androidUrl' => $ayar['uygulama_android'] ?? '',
                'sponsorMetni' => $ayar['sponsor_metni'] ?? '',
                'hizCarpani' => (float) $ayar['hiz_carpani'],
                'kapaliBolumler' => array_values(array_map('intval', array_filter(explode(',', $ayar['kapali_bolumler']), 'strlen'))),
            ]);

        case 'oturum': {
            $v = govde();
            $cihaz = metin($v, 'cihaz', 64);
            if (!preg_match('/^[A-Za-z0-9\-]{8,64}$/', $cihaz)) hata('Geçersiz cihaz');
            $ip = tm_ip_ozet();
            if (tm_deger('SELECT COUNT(*) FROM oturumlar WHERE ip_ozet = ? AND baslangic > ?', [$ip, time() - 3600]) >= 150) hata('Çok fazla istek', 429);
            $platform = in_array(metin($v, 'platform', 12), ['web', 'pwa', 'android'], true) ? metin($v, 'platform', 12) : 'web';
            $ozet = hash_hmac('sha256', $cihaz, tm_gizli()['tuz']);
            $simdi = time(); $gun = date('Y-m-d');
            $oyuncu = tm_satir('SELECT * FROM oyuncular WHERE cihaz = ?', [$ozet]);
            if (!$oyuncu) {
                tm_sorgu('INSERT INTO oyuncular (cihaz, ad, platform, ilk_gorulme, son_gorulme, ilk_gun, giris_sayisi) VALUES (?, ?, ?, ?, ?, ?, 0)',
                    [$ozet, tm_ad_temizle(metin($v, 'isim', 40)), $platform, $simdi, $simdi, $gun]);
                $oyuncu = tm_satir('SELECT * FROM oyuncular WHERE cihaz = ?', [$ozet]);
            }
            tm_sorgu('UPDATE oyuncular SET son_gorulme = ?, giris_sayisi = giris_sayisi + 1, platform = ? WHERE id = ?', [$simdi, $platform, $oyuncu['id']]);
            $jeton = bin2hex(random_bytes(24));
            $ekran = preg_match('/^\d{2,5}x\d{2,5}$/', metin($v, 'ekran', 20)) ? metin($v, 'ekran', 20) : '';
            // Yönlendiren adresten yalnızca alan adı tutulur.
            $kaynak = (string) (parse_url(metin($v, 'kaynak', 200), PHP_URL_HOST) ?: '');
            tm_sorgu('INSERT INTO oturumlar (oyuncu_id, jeton, platform, ekran, kaynak, ip_ozet, baslangic, son_nabiz, gun) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
                [$oyuncu['id'], $jeton, $platform, $ekran, mb_substr($kaynak, 0, 200), $ip, $simdi, $simdi, $gun]);
            cevap(['jeton' => $jeton, 'tarak' => tm_tarak_acik(), 'tarakBagli' => (int) ($oyuncu['tarak_id'] ?? 0) > 0, 'ad' => (string) $oyuncu['ad']]);
        }

        case 'nabiz': {
            $o = oturum(metin(govde(), 'jeton'));
            tm_sorgu('UPDATE oturumlar SET son_nabiz = ? WHERE id = ?', [time(), $o['id']]);
            tm_sorgu('UPDATE oyuncular SET son_gorulme = ? WHERE id = ?', [time(), $o['oyuncu_id']]);
            cevap(['tamam' => true]);
        }

        case 'isim': {
            $v = govde();
            $o = oturum(metin($v, 'jeton'));
            tm_sorgu('UPDATE oyuncular SET ad = ? WHERE id = ?', [tm_ad_temizle(metin($v, 'isim', 40)), $o['oyuncu_id']]);
            cevap(['tamam' => true]);
        }

        case 'basla': {
            $v = govde();
            $o = oturum(metin($v, 'jeton'));
            $bolum = sayi($v, 'bolum', 9999);
            $ucMu = $bolum > TM_UC && $bolum <= TM_UC + count(tm_rotalar());
            if ($bolum !== 0 && !$ucMu && !isset(tm_bolumler()[$bolum])) hata('Bölüm yok');
            if (tm_deger('SELECT COUNT(*) FROM kosular WHERE oturum_id = ?', [$o['id']]) >= 600) hata('Çok fazla istek', 429);
            $zorluk = isset(TM_MODLAR[metin($v, 'zorluk', 6)]) ? metin($v, 'zorluk', 6) : 'zor';
            // "Devam" yalnızca aynı oyuncu bu bölümü az önce yarı yoldan sonra kaybettiyse kabul edilir.
            $devam = 0;
            if (!empty($v['devam']) && isset(tm_bolumler()[$bolum]) && $zorluk !== 'zor') {
                $esik = (int) ((tm_bolumler()[$bolum]['modlar'][$zorluk]['kontrol'] ?? 0) * 0.95);
                $devam = tm_deger("SELECT COUNT(*) FROM kosular WHERE oyuncu_id = ? AND bolum = ? AND zorluk = ? AND sonuc = 'kaybetti' AND mesafe >= ? AND baslangic > ?",
                    [$o['oyuncu_id'], $bolum, $zorluk, $esik, time() - 7200]) > 0 ? 1 : 0;
            }
            tm_sorgu('INSERT INTO kosular (oturum_id, oyuncu_id, bolum, zorluk, devam, baslangic, gun) VALUES (?, ?, ?, ?, ?, ?, ?)',
                [$o['id'], $o['oyuncu_id'], $bolum, $zorluk, $devam, time(), date('Y-m-d')]);
            tm_sorgu('UPDATE oturumlar SET son_nabiz = ? WHERE id = ?', [time(), $o['id']]);
            cevap(['kosuId' => (int) tm_db()->lastInsertId()]);
        }

        case 'bitir': {
            $v = govde();
            $o = oturum(metin($v, 'jeton'));
            $k = tm_satir('SELECT * FROM kosular WHERE id = ? AND oturum_id = ?', [sayi($v, 'kosuId'), $o['id']]);
            if (!$k || $k['bitis'] !== null) hata('Koşu bulunamadı', 404);
            $sonuc = in_array(metin($v, 'sonuc', 12), ['kazandi', 'kaybetti', 'cikti'], true) ? metin($v, 'sonuc', 12) : 'cikti';
            // Sonsuz modda kazanma yoktur; 3D rotası ancak son durağa (en az ~1 km) ulaşınca tamamlanır
            if ((int) $k['bolum'] === 0 && $sonuc === 'kazandi') $sonuc = 'cikti';
            if ((int) $k['bolum'] >= TM_UC && $sonuc === 'kazandi' && sayi($v, 'mesafe') < 1000) $sonuc = 'cikti';
            $skor = sayi($v, 'skor'); $tarak = sayi($v, 'tarak', 100000); $can = sayi($v, 'can', 99);
            $sure = isset($v['sure']) && is_numeric($v['sure']) ? max(0.0, min(86400.0, (float) $v['sure'])) : 0.0;
            $mesafe = sayi($v, 'mesafe');
            $neden = preg_match('/^[a-zA-Z]{0,16}$/', metin($v, 'neden', 16)) ? metin($v, 'neden', 16) : '';
            $gecen = time() - (int) $k['baslangic'];
            $supheli = supheli_mi((int) $k['bolum'], (string) $k['zorluk'], (bool) $k['devam'], $sonuc, $skor, $tarak, $can, $sure, $mesafe, $gecen, (float) $ayar['hiz_carpani']) ? 1 : 0;
            // Hediye parçası: koşu başına en fazla 3; çok kısa koşularda sayılmaz
            $parca = ($supheli || $gecen < 20) ? 0 : min(3, sayi($v, 'parca', 10));
            // Koşuda görünen sponsor reklamları: yalnızca oyuncunun bölgesindeki etkin sponsorlar, koşu başına bir kez
            if (!$supheli && $gecen >= 10 && isset($v['sponsor']) && is_array($v['sponsor'])) {
                $p = tm_satir('SELECT il, ilce FROM oyuncular WHERE id = ?', [$o['oyuncu_id']]);
                $gecerli = array_column(tm_bolge_sponsorlari((string) ($p['il'] ?? ''), (string) ($p['ilce'] ?? '')), 'id');
                $tarakKayit = [];
                foreach (array_unique(array_map('intval', array_slice($v['sponsor'], 0, 6))) as $sid) {
                    if (!in_array($sid, $gecerli, true)) continue;
                    if ($sid >= 100000) $tarakKayit[] = ['sponsorluk_id' => $sid - 100000, 'rota' => tm_rota_adi((int) $k['bolum'] - TM_UC), 'gosterim' => 1, 'oyuncu' => 1];
                    else tm_sorgu('INSERT INTO sponsor_gosterim (sponsor_id, oyuncu_id, bolum, gun, zaman) VALUES (?, ?, ?, ?, ?)', [$sid, $o['oyuncu_id'], (int) $k['bolum'], date('Y-m-d'), time()]);
                }
                if ($tarakKayit) tm_tarak('/game/gosterim', ['kayitlar' => $tarakKayit], 3);   // berberin panelindeki istatistik
            }
            tm_sorgu('UPDATE kosular SET bitis = ?, sonuc = ?, skor = ?, tarak = ?, can = ?, sure = ?, mesafe = ?, yildiz = ?, neden = ?, supheli = ?, parca = ? WHERE id = ?',
                [time(), $sonuc, $skor, $tarak, $can, $sure, $mesafe, sayi($v, 'yildiz', 3), $neden, $supheli, $parca, $k['id']]);
            cevap(['tamam' => true]);
        }

        // Oyuncunun kendi seçtiği il / ilçe (hediye ve sponsor reklamları için; konum izni istenmez)
        case 'bolge': {
            $v = govde();
            $o = oturum(metin($v, 'jeton'));
            $il = metin($v, 'il', 40); $ilce = metin($v, 'ilce', 40);
            $b = tm_bolgeler();
            if ($il !== '' && !isset($b[$il])) hata('İl yok');
            if ($ilce !== '' && ($il === '' || !in_array($ilce, $b[$il], true))) hata('İlçe yok');
            tm_sorgu('UPDATE oyuncular SET il = ?, ilce = ? WHERE id = ?', [$il, $ilce, $o['oyuncu_id']]);
            cevap(['tamam' => true, 'sponsorlar' => tm_bolge_sponsorlari($il, $ilce)]);
        }

        // "Tarak ile giriş": Tarak'ın kendi giriş sayfasının adresi (şifre oyuna hiç gelmez)
        case 'tarakGiris': {
            $v = govde();
            $o = oturum(metin($v, 'jeton'));
            if (!tm_tarak_acik()) hata('Tarak bağlantısı kapalı', 503);
            $donus = metin($v, 'donus', 300);
            cevap(['url' => rtrim($ayar['tarak_api'], '/') . '/game/giris?' . http_build_query(['donus' => $donus, 'durum' => tm_tarak_durum((string) $o['jeton'])])]);
        }
        // Tarak'tan dönen tek kullanımlık kodu sunucudan sunucuya değiştirir, oyuncuyu Tarak hesabına bağlar
        case 'tarakBagla': {
            $v = govde();
            $o = oturum(metin($v, 'jeton'));
            if (!hash_equals(tm_tarak_durum((string) $o['jeton']), metin($v, 'durum', 64))) hata('Giriş isteği bu oturuma ait değil', 400);
            $j = tm_tarak('/game/kod', ['kod' => metin($v, 'kod', 100)]);
            if (!$j || empty($j['success'])) hata((string) ($j['message'] ?? 'Tarak ile bağlantı kurulamadı'), 502);
            $d = $j['data'];
            $p = tm_satir('SELECT il, ilce FROM oyuncular WHERE id = ?', [$o['oyuncu_id']]);
            $il = ($p['il'] ?? '') !== '' ? $p['il'] : mb_substr((string) ($d['il'] ?? ''), 0, 40);
            $ilce = ($p['il'] ?? '') !== '' ? $p['ilce'] : mb_substr((string) ($d['ilce'] ?? ''), 0, 40);
            // Oyuncunun adı yoksa Tarak'taki adı kullanılır (sıralamada görünür)
            $ad = (string) (tm_satir('SELECT ad FROM oyuncular WHERE id = ?', [$o['oyuncu_id']])['ad'] ?? '');
            if ($ad === '') $ad = tm_ad_temizle((string) ($d['ad'] ?? ''));
            tm_sorgu('UPDATE oyuncular SET tarak_id = ?, il = ?, ilce = ?, ad = ? WHERE id = ?', [(int) $d['kullanici_id'], $il, $ilce, $ad, $o['oyuncu_id']]);
            cevap(['tamam' => true, 'ad' => (string) ($d['ad'] ?? ''), 'oyuncuAd' => $ad, 'il' => $il, 'ilce' => $ilce, 'sponsorlar' => tm_bolge_sponsorlari($il, $ilce)]);
        }

        case 'tarakCikis': {
            $v = govde();
            $o = oturum(metin($v, 'jeton'));
            tm_sorgu('UPDATE oyuncular SET tarak_id = 0 WHERE id = ?', [$o['oyuncu_id']]);
            cevap(['tamam' => true]);
        }

        // Oyuncunun bölgesindeki sponsorlar (oyunda panolarda görünür)
        case 'sponsorlar': {
            $v = govde();
            $o = oturum(metin($v, 'jeton'));
            $p = tm_satir('SELECT il, ilce FROM oyuncular WHERE id = ?', [$o['oyuncu_id']]);
            cevap(['sponsorlar' => tm_bolge_sponsorlari((string) ($p['il'] ?? ''), (string) ($p['ilce'] ?? ''))]);
        }

        // Tarak Mobil berber paneli için: sponsorun reklam istatistikleri (sunucudan sunucuya, anahtarla)
        case 'sponsorIstatistik': {
            $anahtar = (string) ($_SERVER['HTTP_X_TARAK_ANAHTAR'] ?? '');
            if ($anahtar === '' || !hash_equals(tm_entegrasyon_anahtari(), $anahtar)) hata('Yetkisiz', 401);
            $tarakId = mb_substr((string) ($_GET['isletme'] ?? ''), 0, 40);
            $sp = $tarakId !== '' ? tm_satir('SELECT * FROM sponsorlar WHERE tarak_id = ?', [$tarakId]) : tm_satir('SELECT * FROM sponsorlar WHERE id = ?', [(int) ($_GET['sponsor'] ?? 0)]);
            if (!$sp) hata('Sponsor yok', 404);
            $id = (int) $sp['id']; $esik = date('Y-m-d', time() - 29 * 86400);
            $rotalar = array_map(static fn(array $r) => ['rota' => (int) $r['bolum'] - TM_UC, 'ad' => tm_rota_adi((int) $r['bolum'] - TM_UC), 'gosterim' => (int) $r['n']],
                tm_satirlar('SELECT bolum, COUNT(*) AS n FROM sponsor_gosterim WHERE sponsor_id = ? GROUP BY bolum ORDER BY n DESC LIMIT 20', [$id]));
            cevap(['sponsor' => ['id' => $id, 'ad' => $sp['ad'], 'il' => $sp['il'], 'ilce' => $sp['ilce'], 'aktif' => (int) $sp['aktif'] === 1],
                'toplam' => (int) tm_deger('SELECT COUNT(*) FROM sponsor_gosterim WHERE sponsor_id = ?', [$id]),
                'tekilOyuncu' => (int) tm_deger('SELECT COUNT(DISTINCT oyuncu_id) FROM sponsor_gosterim WHERE sponsor_id = ?', [$id]),
                'son30Gun' => (int) tm_deger('SELECT COUNT(*) FROM sponsor_gosterim WHERE sponsor_id = ? AND gun >= ?', [$id, $esik]),
                'rotalar' => $rotalar]);
        }

        // Oyuncunun bu yılki hediye durumu
        case 'hediye':
        case 'hediyeAl': {
            $v = govde();
            $o = oturum(metin($v, 'jeton'));
            if ((int) $o['engelli']) hata('Hesap kısıtlı', 403);
            $yil = (int) date('Y');
            $gerekli = max(5, min(100, (int) $ayar['hediye_parca']));
            $parca = tm_hediye_parcasi((int) $o['oyuncu_id']);
            $var = tm_satir('SELECT id, kod, ad, durum, son_tarih FROM hediyeler WHERE oyuncu_id = ? AND yil = ? AND durum <> ?', [$o['oyuncu_id'], $yil, 'iptal']);
            if ($var) $var['durum'] = tm_kupon_durumu($var);
            if ($islem === 'hediyeAl' && !$var) {
                if ($ayar['hediye_aktif'] !== '1') hata('Hediyeler şu an kapalı', 403);
                if ($parca < $gerekli) hata('Yeterli parça yok', 400);
                $kadin = !empty($v['kadin']);
                $ad = ($kadin ? $ayar['hediye_kadin'] : $ayar['hediye_erkek']);
                if (tm_yilbasi_mi()) $ad = 'Yılbaşı Hediyesi: ' . $ad;
                $kod = tm_hediye_kodu();
                $son = time() + TM_KUPON_GUN * 86400;
                // Tarak bağlıysa kupon Tarak'ta üretilir: müşteri profilinde ve sponsor berberin panelinde aynı kod görünür
                if (tm_tarak_acik()) {
                    $p = tm_satir('SELECT tarak_id, il, ilce FROM oyuncular WHERE id = ?', [$o['oyuncu_id']]);
                    if (!(int) ($p['tarak_id'] ?? 0)) cevap(['tarakGerekli' => true, 'parca' => $parca, 'gerekli' => $gerekli, 'aktif' => true]);
                    $j = tm_tarak('/game/hediye', ['kullanici_id' => (int) $p['tarak_id'], 'il' => $p['il'], 'ilce' => $p['ilce'], 'kitle' => $kadin ? 'kadin' : 'erkek',
                        'oyun_ref' => 'oyun-' . $o['oyuncu_id'] . '-' . $yil, 'hizmet_varsayilan' => $ad]);
                    if (!$j || empty($j['success'])) hata((string) ($j['message'] ?? 'Hediye şu an Tarak’a iletilemedi, biraz sonra tekrar dene'), 502);
                    $d = $j['data'];
                    $kod = (string) $d['kod'];
                    $ad = (string) $d['hizmet'] . (!empty($d['sponsor']['ad']) ? ' · ' . $d['sponsor']['ad'] : '');
                    $son = strtotime((string) $d['son_tarih']) ?: $son;
                    $sponsorKarti = $d['sponsor'] ?? null;
                }
                tm_sorgu('INSERT INTO hediyeler (oyuncu_id, kod, tur, ad, yil, olusturma, son_tarih) VALUES (?, ?, ?, ?, ?, ?, ?)',
                    [$o['oyuncu_id'], $kod, $kadin ? 'kuafor' : 'berber', mb_substr($ad, 0, 80), $yil, time(), $son]);
                $var = ['kod' => $kod, 'ad' => $ad, 'durum' => 'verildi', 'son_tarih' => $son];
            }
            $tb = (int) (tm_satir('SELECT tarak_id FROM oyuncular WHERE id = ?', [$o['oyuncu_id']])['tarak_id'] ?? 0);
            cevap(['aktif' => $ayar['hediye_aktif'] === '1', 'parca' => $parca, 'gerekli' => $gerekli,
                   'kod' => $var['kod'] ?? null, 'ad' => $var['ad'] ?? null, 'durum' => $var['durum'] ?? null,
                   'sonTarih' => isset($var['son_tarih']) ? (int) $var['son_tarih'] : null,
                   'erkek' => $ayar['hediye_erkek'], 'kadinAd' => $ayar['hediye_kadin'],
                   'tarak' => tm_tarak_acik(), 'tarakBagli' => $tb > 0, 'sponsor' => $sponsorKarti ?? null]);
        }

        // Tarak Mobil sunucusu için: kodu doğrula / kullanıldı işaretle (sunucudan sunucuya, gizli anahtarla)
        case 'hediyeDogrula':
        case 'hediyeKullan': {
            $anahtar = (string) ($_SERVER['HTTP_X_TARAK_ANAHTAR'] ?? '');
            if ($anahtar === '' || !hash_equals(tm_entegrasyon_anahtari(), $anahtar)) hata('Yetkisiz', 401);
            $kod = strtoupper(preg_replace('/[^A-Za-z0-9-]/', '', (string) ($_GET['kod'] ?? '')));
            $h = tm_satir('SELECT id, kod, tur, ad, yil, durum, olusturma, kullanma, son_tarih FROM hediyeler WHERE kod = ?', [$kod]);
            if (!$h) hata('Kod bulunamadı', 404);
            $h['durum'] = tm_kupon_durumu($h);
            if ($islem === 'hediyeKullan') {
                if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') hata('POST gerekli', 405);
                if ($h['durum'] !== 'verildi') hata('Kod kullanılamaz: ' . $h['durum'], 409);
                $not = mb_substr((string) ($_GET['not'] ?? ''), 0, 120);
                tm_sorgu("UPDATE hediyeler SET durum = 'kullanildi', kullanma = ?, aciklama = ? WHERE id = ? AND durum = 'verildi'", [time(), $not, $h['id']]);
                $h['durum'] = 'kullanildi'; $h['kullanma'] = time();
            }
            unset($h['id']);
            cevap(['hediye' => $h, 'gecerli' => $h['durum'] === 'verildi' || $islem === 'hediyeKullan']);
        }

        case 'tiklama': {
            $v = govde();
            $o = oturum(metin($v, 'jeton'));
            if (metin($v, 'tur', 16) !== 'randevu') hata('Tür yok');
            if (tm_deger('SELECT COUNT(*) FROM tiklamalar WHERE oyuncu_id = ? AND gun = ?', [$o['oyuncu_id'], date('Y-m-d')]) < 30) {
                tm_sorgu('INSERT INTO tiklamalar (oyuncu_id, tur, zaman, gun) VALUES (?, ?, ?, ?)', [$o['oyuncu_id'], 'randevu', time(), date('Y-m-d')]);
            }
            cevap(['tamam' => true]);
        }

        case 'siralama': {
            $ben = 0;
            $j = (string) ($_GET['jeton'] ?? '');
            if (preg_match('/^[a-f0-9]{48}$/', $j)) $ben = (int) tm_deger('SELECT oyuncu_id FROM oturumlar WHERE jeton = ?', [$j]);
            $kosul = 'k.supheli = 0 AND k.gizli = 0 AND p.engelli = 0 AND k.skor > 0';
            $tur = (string) ($_GET['tur'] ?? '');
            if ($tur === 'sonsuz' || $tur === 'uc') {
                $no = $tur === 'uc' ? TM_UC : 0;
                $sql = "SELECT p.id, p.ad, MAX(k.skor) AS skor FROM kosular k JOIN oyuncular p ON p.id = k.oyuncu_id
                        WHERE " . ($tur === 'uc' ? 'k.bolum >= ' . TM_UC : 'k.bolum = 0') . " AND $kosul GROUP BY p.id, p.ad ORDER BY skor DESC LIMIT 50";
            } else {
                $sql = "SELECT x.id, x.ad, SUM(x.en_iyi) AS skor FROM (
                            SELECT p.id, p.ad, k.bolum, MAX(k.skor) AS en_iyi FROM kosular k JOIN oyuncular p ON p.id = k.oyuncu_id
                            WHERE k.bolum > 0 AND k.bolum < " . TM_UC . " AND k.sonuc = 'kazandi' AND $kosul GROUP BY p.id, p.ad, k.bolum
                        ) x GROUP BY x.id, x.ad ORDER BY skor DESC LIMIT 50";
            }
            $liste = array_map(static function (array $s) use ($ben): array {
                return ['ad' => $s['ad'] !== '' ? $s['ad'] : 'Oyuncu #' . $s['id'], 'skor' => (int) $s['skor'], 'ben' => (int) $s['id'] === $ben];
            }, tm_satirlar($sql));
            cevap(['liste' => $liste]);
        }

        default:
            hata('Bilinmeyen işlem', 404);
    }
} catch (Throwable $e) {
    error_log('tarak-oyun api: ' . $e->getMessage());
    cevap(['hata' => 'Sunucu hatası'], 500);
}
