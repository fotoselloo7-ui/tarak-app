<?php
// Ortak çekirdek: ayarlar, veritabanı, yardımcılar.
declare(strict_types=1);

date_default_timezone_set('Europe/Istanbul');
mb_internal_encoding('UTF-8');

define('TM_KOK', dirname(__DIR__));
define('TM_VERI', getenv('TM_VERI_KLASORU') ?: TM_KOK . '/data');

/** data/gizli.php ilk çalıştırmada üretilir: IP tuzu, kurulum anahtarı ve veritabanı adı. */
function tm_gizli(): array
{
    static $g = null;
    if ($g !== null) return $g;
    if (!is_dir(TM_VERI)) mkdir(TM_VERI, 0750, true);
    $dosya = TM_VERI . '/gizli.php';
    if (!is_file($dosya)) {
        $yeni = [
            'tuz' => bin2hex(random_bytes(24)),
            'kurulum_anahtari' => bin2hex(random_bytes(8)),
            'db_dosya' => 'oyun-' . bin2hex(random_bytes(8)) . '.sqlite',
        ];
        $f = @fopen($dosya, 'x');
        if ($f) {
            fwrite($f, "<?php\nreturn " . var_export($yeni, true) . ";\n");
            fclose($f);
        }
    }
    return $g = require $dosya;
}

/**
 * Varsayılan: SQLite (kurulum gerektirmez). MySQL için data/mysql.php oluştur:
 * <?php return ['dsn' => 'mysql:host=localhost;dbname=XXX;charset=utf8mb4', 'kullanici' => '...', 'sifre' => '...'];
 */
function tm_db(): PDO
{
    static $db = null;
    if ($db) return $db;
    $gizli = tm_gizli();
    $secenek = [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC];
    $mysql = is_file(TM_VERI . '/mysql.php') ? require TM_VERI . '/mysql.php' : null;
    if ($mysql) {
        $db = new PDO($mysql['dsn'], $mysql['kullanici'], $mysql['sifre'], $secenek);
    } else {
        $db = new PDO('sqlite:' . TM_VERI . '/' . $gizli['db_dosya'], null, null, $secenek);
        $db->exec('PRAGMA journal_mode=WAL');
        $db->exec('PRAGMA busy_timeout=4000');
        $db->exec('PRAGMA foreign_keys=ON');
    }
    tm_tablolar($db, (bool) $mysql);
    return $db;
}

function tm_tablolar(PDO $db, bool $mysql): void
{
    $isaret = TM_VERI . '/sema-' . ($mysql ? 'mysql' : 'sqlite') . '.v6';
    if (is_file($isaret)) return;
    $id = $mysql ? 'INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY' : 'INTEGER PRIMARY KEY AUTOINCREMENT';
    $son = $mysql ? ' ENGINE=InnoDB DEFAULT CHARSET=utf8mb4' : '';
    $tablolar = [
        "CREATE TABLE IF NOT EXISTS oyuncular (id $id, cihaz VARCHAR(64) NOT NULL UNIQUE, ad VARCHAR(32) NOT NULL DEFAULT '',
            engelli INT NOT NULL DEFAULT 0, platform VARCHAR(12) NOT NULL DEFAULT 'web', ilk_gorulme INT NOT NULL, son_gorulme INT NOT NULL,
            ilk_gun VARCHAR(10) NOT NULL, giris_sayisi INT NOT NULL DEFAULT 0)$son",
        "CREATE TABLE IF NOT EXISTS oturumlar (id $id, oyuncu_id INT NOT NULL, jeton VARCHAR(64) NOT NULL UNIQUE, platform VARCHAR(12) NOT NULL,
            ekran VARCHAR(20) NOT NULL DEFAULT '', kaynak VARCHAR(200) NOT NULL DEFAULT '', ip_ozet VARCHAR(64) NOT NULL,
            baslangic INT NOT NULL, son_nabiz INT NOT NULL, gun VARCHAR(10) NOT NULL)$son",
        "CREATE TABLE IF NOT EXISTS kosular (id $id, oturum_id INT NOT NULL, oyuncu_id INT NOT NULL, bolum INT NOT NULL,
            baslangic INT NOT NULL, bitis INT NULL, sonuc VARCHAR(12) NOT NULL DEFAULT '', skor INT NOT NULL DEFAULT 0,
            tarak INT NOT NULL DEFAULT 0, can INT NOT NULL DEFAULT 0, sure DOUBLE PRECISION NOT NULL DEFAULT 0, mesafe INT NOT NULL DEFAULT 0,
            yildiz INT NOT NULL DEFAULT 0, neden VARCHAR(16) NOT NULL DEFAULT '', supheli INT NOT NULL DEFAULT 0,
            gizli INT NOT NULL DEFAULT 0, gun VARCHAR(10) NOT NULL)$son",
        "CREATE TABLE IF NOT EXISTS tiklamalar (id $id, oyuncu_id INT NOT NULL, tur VARCHAR(16) NOT NULL, zaman INT NOT NULL, gun VARCHAR(10) NOT NULL)$son",
        "CREATE TABLE IF NOT EXISTS ayarlar (anahtar VARCHAR(40) NOT NULL PRIMARY KEY, deger TEXT NOT NULL)$son",
        "CREATE TABLE IF NOT EXISTS yoneticiler (id $id, kullanici VARCHAR(40) NOT NULL UNIQUE, sifre VARCHAR(255) NOT NULL)$son",
        "CREATE TABLE IF NOT EXISTS giris_denemeleri (id $id, ip_ozet VARCHAR(64) NOT NULL, zaman INT NOT NULL)$son",
        // v3: gerçek hizmet hediyeleri (Tarak Mobil'de kullanılan kodlar)
        "CREATE TABLE IF NOT EXISTS hediyeler (id $id, oyuncu_id INT NOT NULL, kod VARCHAR(20) NOT NULL UNIQUE, tur VARCHAR(12) NOT NULL,
            ad VARCHAR(80) NOT NULL, yil INT NOT NULL, durum VARCHAR(12) NOT NULL DEFAULT 'verildi', olusturma INT NOT NULL,
            kullanma INT NULL, aciklama VARCHAR(120) NOT NULL DEFAULT '')$son",
        // v5: bölgesel sponsor işletmeler ve oyunda görünen reklamlarının sayımı
        "CREATE TABLE IF NOT EXISTS sponsorlar (id $id, ad VARCHAR(80) NOT NULL, hizmet VARCHAR(60) NOT NULL DEFAULT '', il VARCHAR(40) NOT NULL,
            ilce VARCHAR(40) NOT NULL DEFAULT '', logo VARCHAR(200) NOT NULL DEFAULT '', renk VARCHAR(9) NOT NULL DEFAULT '#1c2023', aktif INT NOT NULL DEFAULT 1,
            bitis INT NOT NULL DEFAULT 0, tarak_id VARCHAR(40) NOT NULL DEFAULT '', olusturma INT NOT NULL)$son",
        "CREATE TABLE IF NOT EXISTS sponsor_gosterim (id $id, sponsor_id INT NOT NULL, oyuncu_id INT NOT NULL, bolum INT NOT NULL, gun VARCHAR(10) NOT NULL, zaman INT NOT NULL)$son",
    ];
    foreach ($tablolar as $sql) $db->exec($sql);
    $indeksler = [
        'idx_oturum_ip ON oturumlar (ip_ozet, baslangic)', 'idx_oturum_gun ON oturumlar (gun)',
        'idx_oturum_nabiz ON oturumlar (son_nabiz)', 'idx_kosu_oyuncu ON kosular (oyuncu_id, bolum)',
        'idx_kosu_gun ON kosular (gun)', 'idx_kosu_oturum ON kosular (oturum_id)', 'idx_hediye_oyuncu ON hediyeler (oyuncu_id, yil)',
        'idx_sponsor_bolge ON sponsorlar (il, ilce)', 'idx_gosterim_sponsor ON sponsor_gosterim (sponsor_id, gun)',
    ];
    foreach ($indeksler as $i) {
        try { $db->exec('CREATE INDEX ' . ($mysql ? '' : 'IF NOT EXISTS ') . $i); } catch (PDOException $e) { /* zaten var */ }
    }
    // v2: zorluk modu ve yarı yoldan devam sütunları
    foreach (["zorluk VARCHAR(6) NOT NULL DEFAULT 'zor'", 'devam INT NOT NULL DEFAULT 0', 'parca INT NOT NULL DEFAULT 0'] as $sutun) {
        try { $db->exec("ALTER TABLE kosular ADD COLUMN $sutun"); } catch (PDOException $e) { /* zaten var */ }
    }
    // v4: kupon son kullanma tarihi (alındıktan sonra 30 gün)
    try { $db->exec('ALTER TABLE hediyeler ADD COLUMN son_tarih INT NOT NULL DEFAULT 0'); } catch (PDOException $e) { /* zaten var */ }
    // v5: oyuncunun seçtiği il ve ilçe (konum izni değil, kendi seçimi)
    foreach (["il VARCHAR(40) NOT NULL DEFAULT ''", "ilce VARCHAR(40) NOT NULL DEFAULT ''"] as $sutun) {
        try { $db->exec("ALTER TABLE oyuncular ADD COLUMN $sutun"); } catch (PDOException $e) { /* zaten var */ }
    }
    // v6: Tarak hesabı bağlantısı (Tarak ile giriş)
    try { $db->exec('ALTER TABLE oyuncular ADD COLUMN tarak_id INT NOT NULL DEFAULT 0'); } catch (PDOException $e) { /* zaten var */ }
    file_put_contents($isaret, date('c'));
}

function tm_sorgu(string $sql, array $p = []): PDOStatement
{
    $s = tm_db()->prepare($sql);
    $s->execute($p);
    return $s;
}
function tm_satir(string $sql, array $p = []): ?array { $r = tm_sorgu($sql, $p)->fetch(); return $r ?: null; }
function tm_satirlar(string $sql, array $p = []): array { return tm_sorgu($sql, $p)->fetchAll(); }
function tm_deger(string $sql, array $p = []) { return tm_sorgu($sql, $p)->fetchColumn(); }

const TM_UC = 100;   // kosular.bolum alanında 3D koşunun numarası
const TM_MODLAR = ['kolay' => 'Kolay', 'orta' => 'Orta', 'zor' => 'Zor'];

const TM_VARSAYILAN_AYAR = [
    'oyun_aktif' => '1',
    'bakim_mesaji' => 'Oyun kısa süreliğine bakımda. Birazdan tekrar dene.',
    'duyuru' => '',
    'randevu_url' => 'https://tarak.app',
    'randevu_metni' => 'Gerçek randevu al →',
    'uygulama_url' => 'https://tarak.app/',
    'uygulama_ios' => 'https://apps.apple.com/tr/app/tarak-berber-ve-kuaf%C3%B6r-%C3%A7a%C4%9F%C4%B1r/id6826645157?l=tr',
    'uygulama_android' => 'https://play.google.com/store/apps/details?id=app.tarak.mobile&hl=tr',
    'hediye_aktif' => '1',
    'hediye_parca' => '20',
    'hediye_erkek' => 'Sakal Tıraşı',
    'hediye_kadin' => 'Manikür',
    'entegrasyon_anahtari' => '',
    'sponsor_metni' => '',   // boşsa platforma göre: App Store / Google Play / tarak.app
    'hiz_carpani' => '1',
    'kapali_bolumler' => '',
    // Tarak entegrasyonu: boşsa oyun kendi kuponunu üretir; doluysa kupon ve sponsorlar Tarak'tan gelir
    'tarak_api' => '',            // ör. https://tarak.app/api
    'tarak_oyun_anahtari' => '',  // Tarak sunucusundaki GAME_SERVER_KEY
];

function tm_ayarlar(): array
{
    $a = TM_VARSAYILAN_AYAR;
    foreach (tm_satirlar('SELECT anahtar, deger FROM ayarlar') as $s) $a[$s['anahtar']] = $s['deger'];
    return $a;
}

function tm_ayar_yaz(string $anahtar, string $deger): void
{
    $varMi = tm_deger('SELECT COUNT(*) FROM ayarlar WHERE anahtar = ?', [$anahtar]);
    if ($varMi) tm_sorgu('UPDATE ayarlar SET deger = ? WHERE anahtar = ?', [$deger, $anahtar]);
    else tm_sorgu('INSERT INTO ayarlar (anahtar, deger) VALUES (?, ?)', [$anahtar, $deger]);
}

/** 3D rotaları (ad, dünyalar, saat, hava). kosular.bolum = TM_UC + rota numarası */
function tm_rotalar(): array
{
    static $r = null;
    if ($r === null) $r = json_decode((string) @file_get_contents(__DIR__ . '/rotalar.json'), true) ?: [];
    return $r;
}
function tm_rota_adi(int $no): string { return (string) (tm_rotalar()[$no - 1]['ad'] ?? ('Rota ' . $no)); }

function tm_bolumler(): array
{
    static $b = null;
    if ($b === null) {
        $b = [];
        foreach (json_decode((string) file_get_contents(__DIR__ . '/bolumler.json'), true) ?: [] as $x) $b[(int) $x['id']] = $x;
    }
    return $b;
}

/** IP adresi düz metin saklanmaz; yalnızca tuzlu özeti tutulur. */
function tm_ip_ozet(): string
{
    return hash_hmac('sha256', (string) ($_SERVER['REMOTE_ADDR'] ?? ''), tm_gizli()['tuz']);
}

function tm_ad_temizle(string $ad): string
{
    $ad = preg_replace('/[^\p{L}\p{N} _.\-]/u', '', $ad) ?? '';
    return mb_substr(trim(preg_replace('/\s+/u', ' ', $ad) ?? ''), 0, 16);
}

// ---------- Hediyeler ----------
/** Okunması kolay hediye kodu: TRK-XXXX-XXXX (karışan harfler yok) */
function tm_hediye_kodu(): string
{
    $abc = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    do {
        $k = '';
        for ($i = 0; $i < 8; $i++) $k .= $abc[random_int(0, strlen($abc) - 1)];
        $kod = 'TRK-' . substr($k, 0, 4) . '-' . substr($k, 4, 4);
    } while (tm_deger('SELECT COUNT(*) FROM hediyeler WHERE kod = ?', [$kod]) > 0);
    return $kod;
}
/** Bu yıl, şüpheli olmayan koşularda toplanan hediye parçaları */
function tm_hediye_parcasi(int $oyuncu): int
{
    return (int) tm_deger("SELECT COALESCE(SUM(parca), 0) FROM kosular WHERE oyuncu_id = ? AND supheli = 0 AND gizli = 0 AND gun >= ?", [$oyuncu, date('Y') . '-01-01']);
}
/** Yılbaşı dönemi (20 Aralık – 15 Ocak): hediyeye yılbaşı adı verilir */
function tm_yilbasi_mi(): bool { $a = (int) date('n'); $g = (int) date('j'); return ($a === 12 && $g >= 20) || ($a === 1 && $g <= 15); }
/** Tarak Mobil sunucusunun hediye kodlarını doğrulamak için kullandığı anahtar (ilk kullanımda üretilir) */
function tm_entegrasyon_anahtari(): string
{
    $a = tm_ayarlar()['entegrasyon_anahtari'] ?? '';
    if (strlen($a) < 32) { $a = bin2hex(random_bytes(24)); tm_ayar_yaz('entegrasyon_anahtari', $a); }
    return $a;
}
const TM_KUPON_GUN = 30;
/** Süresi dolmuş, kullanılmamış kuponları işaretler; kuponun güncel durumunu döndürür */
function tm_kupon_durumu(array $h): string
{
    if ($h['durum'] === 'verildi' && (int) ($h['son_tarih'] ?? 0) > 0 && (int) $h['son_tarih'] < time()) {
        tm_sorgu("UPDATE hediyeler SET durum = 'suresi_doldu' WHERE id = ? AND durum = 'verildi'", [$h['id']]);
        return 'suresi_doldu';
    }
    return (string) $h['durum'];
}

// ---------- Tarak entegrasyonu ----------
function tm_tarak_acik(): bool { $a = tm_ayarlar(); return $a['tarak_api'] !== '' && $a['tarak_oyun_anahtari'] !== ''; }
/** Tarak API'sine istek (sunucudan sunucuya). Hata olursa null döner; oyun kendi başına çalışmaya devam eder. */
function tm_tarak(string $yol, ?array $govde = null, int $sure = 6): ?array
{
    $a = tm_ayarlar();
    if ($a['tarak_api'] === '') return null;
    $baslik = "Accept: application/json\r\nX-Oyun-Anahtar: " . $a['tarak_oyun_anahtari'] . "\r\n";
    $secenek = ['http' => ['method' => $govde === null ? 'GET' : 'POST', 'timeout' => $sure, 'ignore_errors' => true,
        'header' => $baslik . ($govde === null ? '' : "Content-Type: application/json\r\n"),
        'content' => $govde === null ? '' : json_encode($govde, JSON_UNESCAPED_UNICODE)]];
    $yanit = @file_get_contents(rtrim($a['tarak_api'], '/') . $yol, false, stream_context_create($secenek));
    if ($yanit === false) return null;
    $j = json_decode($yanit, true);
    $kod = 0;
    foreach ($http_response_header ?? [] as $h) if (preg_match('#^HTTP/\S+ (\d{3})#', $h, $m)) $kod = (int) $m[1];
    return is_array($j) ? $j + ['_http' => $kod] : null;
}
/** "Tarak ile giriş" dönüşünde durum değeri: oturum jetonuna bağlı imza (başka oturuma taşınamaz) */
function tm_tarak_durum(string $jeton): string { return substr(hash_hmac('sha256', 'tarak-giris|' . $jeton, tm_gizli()['tuz']), 0, 32); }
/** Tarak'taki bölge sponsorları (10 dk önbellek). Oyundaki kimlik: 100000 + Tarak sponsorluk no */
function tm_tarak_sponsorlari(string $il, string $ilce, string $kitle = ''): array
{
    if (!tm_tarak_acik() || $il === '') return [];
    $dosya = sys_get_temp_dir() . '/tarak-sp-' . md5($il . '|' . $ilce . '|' . $kitle) . '.json';
    if (is_file($dosya) && filemtime($dosya) > time() - 600) { $l = json_decode((string) file_get_contents($dosya), true); if (is_array($l)) return $l; }
    $j = tm_tarak('/game/sponsorlar?' . http_build_query(['il' => $il, 'ilce' => $ilce, 'kitle' => $kitle]));
    $l = [];
    foreach (($j['data'] ?? []) as $s) {
        $l[] = ['id' => 100000 + (int) $s['sponsorluk_id'], 'ad' => (string) $s['ad'], 'hizmet' => (string) $s['hizmet'], 'il' => (string) ($s['il'] ?? $il),
                'ilce' => (string) ($s['ilce'] ?? ''), 'logo' => (string) ($s['logo'] ?? ''), 'renk' => '#1c2023', 'tarak' => true];
    }
    @file_put_contents($dosya, json_encode($l, JSON_UNESCAPED_UNICODE));
    return $l;
}

// ---------- Bölgeler ve sponsorlar ----------
/** Geçerli il => [ilçeler] (rotalar.json'daki 973 ilçeden) */
function tm_bolgeler(): array
{
    static $b = null;
    if ($b !== null) return $b;
    $b = [];
    foreach (tm_rotalar() as $r) { if (!empty($r['il'])) $b[$r['il']][] = $r['ilce']; }
    return $b;
}
/** Oyuncunun bölgesindeki etkin sponsorlar: önce aynı ilçe, sonra aynı il (en fazla 4) */
function tm_bolge_sponsorlari(string $il, string $ilce): array
{
    if ($il === '') return [];
    $l = tm_satirlar("SELECT id, ad, hizmet, il, ilce, logo, renk FROM sponsorlar WHERE aktif = 1 AND il = ? AND (bitis = 0 OR bitis > ?)
        ORDER BY CASE WHEN ilce = ? THEN 0 WHEN ilce = '' THEN 1 ELSE 2 END, id LIMIT 4", [$il, time(), $ilce]);
    $yerel = array_map(static fn(array $s) => ['id' => (int) $s['id'], 'ad' => $s['ad'], 'hizmet' => $s['hizmet'], 'il' => $s['il'], 'ilce' => $s['ilce'], 'logo' => $s['logo'], 'renk' => $s['renk']], $l);
    // Tarak'ta "Oyuna Sponsor Ol" diyen işletmeler önce gelir
    return array_slice(array_merge(tm_tarak_sponsorlari($il, $ilce), $yerel), 0, 6);
}
