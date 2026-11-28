<?php
// Tarak Oyun yönetim paneli.
declare(strict_types=1);
require __DIR__ . '/../inc/baslat.php';

header('X-Frame-Options: DENY');
header('X-Content-Type-Options: nosniff');
header('Referrer-Policy: no-referrer');
header("Content-Security-Policy: default-src 'self'; style-src 'self'; img-src 'self' data:; script-src 'self'; frame-ancestors 'none'; form-action 'self'");
header('Cache-Control: no-store');

$https = !empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off';
session_name('tm_yonetim');
session_set_cookie_params(['lifetime' => 0, 'path' => '/', 'secure' => $https, 'httponly' => true, 'samesite' => 'Strict']);
session_start();
if (empty($_SESSION['csrf'])) $_SESSION['csrf'] = bin2hex(random_bytes(24));

function e($m): string { return htmlspecialchars((string) $m, ENT_QUOTES, 'UTF-8'); }
function csrf(): string { return '<input type="hidden" name="csrf" value="' . e($_SESSION['csrf']) . '">'; }
function git(string $s, string $mesaj = ''): void { if ($mesaj !== '') $_SESSION['mesaj'] = $mesaj; header('Location: index.php?s=' . urlencode($s)); exit; }
function n($x): string { return number_format((float) $x, 0, ',', '.'); }
function tarih($t): string { return $t ? date('d.m.Y H:i', (int) $t) : '—'; }

$post = ($_SERVER['REQUEST_METHOD'] ?? '') === 'POST';
if ($post && !hash_equals($_SESSION['csrf'], (string) ($_POST['csrf'] ?? ''))) { http_response_code(400); exit('Oturum süresi doldu, sayfayı yenileyin.'); }
$eylem = $post ? (string) ($_POST['eylem'] ?? '') : '';
$yoneticiVar = (int) tm_deger('SELECT COUNT(*) FROM yoneticiler') > 0;
$uyari = '';

// ---------- İlk kurulum ----------
if (!$yoneticiVar) {
    if ($eylem === 'kur') {
        $anahtar = trim((string) ($_POST['anahtar'] ?? ''));
        $k = trim((string) ($_POST['kullanici'] ?? ''));
        $s = (string) ($_POST['sifre'] ?? '');
        if (!hash_equals(tm_gizli()['kurulum_anahtari'], $anahtar)) { sleep(1); $uyari = 'Kurulum anahtarı hatalı.'; }
        elseif (!preg_match('/^[A-Za-z0-9_.\-]{3,40}$/', $k)) $uyari = 'Kullanıcı adı en az 3 karakter olmalı (harf, rakam, _ . -).';
        elseif (strlen($s) < 10) $uyari = 'Şifre en az 10 karakter olmalı.';
        else {
            tm_sorgu('INSERT INTO yoneticiler (kullanici, sifre) VALUES (?, ?)', [$k, password_hash($s, PASSWORD_DEFAULT)]);
            git('genel', 'Yönetici hesabı oluşturuldu. Şimdi giriş yapın.');
        }
    }
    sayfa_bas('Kurulum');
    echo '<main class="giris"><img src="../assets/img/logo.svg" alt="tarak.app"><h1>Oyun paneli kurulumu</h1>';
    if ($uyari) echo '<p class="uyari">' . e($uyari) . '</p>';
    echo '<p class="soluk">Kurulum anahtarı sunucudaki <code>data/gizli.php</code> dosyasında <code>kurulum_anahtari</code> satırında yazar.</p>';
    echo '<form method="post">' . csrf() . '<input type="hidden" name="eylem" value="kur">
        <label>Kurulum anahtarı<input name="anahtar" required autocomplete="off"></label>
        <label>Kullanıcı adı<input name="kullanici" required autocomplete="username"></label>
        <label>Şifre (en az 10 karakter)<input type="password" name="sifre" required minlength="10" autocomplete="new-password"></label>
        <button class="ana">Hesabı oluştur</button></form></main></body></html>';
    exit;
}

// ---------- Giriş / çıkış ----------
if ($eylem === 'giris') {
    $ip = tm_ip_ozet();
    tm_sorgu('DELETE FROM giris_denemeleri WHERE zaman < ?', [time() - 900]);
    if ((int) tm_deger('SELECT COUNT(*) FROM giris_denemeleri WHERE ip_ozet = ?', [$ip]) >= 6) {
        $uyari = 'Çok fazla hatalı deneme. 15 dakika sonra tekrar deneyin.';
    } else {
        $y = tm_satir('SELECT * FROM yoneticiler WHERE kullanici = ?', [trim((string) ($_POST['kullanici'] ?? ''))]);
        if ($y && password_verify((string) ($_POST['sifre'] ?? ''), $y['sifre'])) {
            session_regenerate_id(true);
            $_SESSION['yonetici'] = (int) $y['id'];
            $_SESSION['csrf'] = bin2hex(random_bytes(24));
            tm_sorgu('DELETE FROM giris_denemeleri WHERE ip_ozet = ?', [$ip]);
            git('genel');
        }
        tm_sorgu('INSERT INTO giris_denemeleri (ip_ozet, zaman) VALUES (?, ?)', [$ip, time()]);
        $uyari = 'Kullanıcı adı veya şifre hatalı.';
    }
}
if ($eylem === 'cikis') { $_SESSION = []; session_destroy(); header('Location: index.php'); exit; }

if (empty($_SESSION['yonetici'])) {
    sayfa_bas('Giriş');
    echo '<main class="giris"><img src="../assets/img/logo.svg" alt="tarak.app"><h1>Oyun Yönetimi</h1>';
    if (!empty($_SESSION['mesaj'])) { echo '<p class="bilgi">' . e($_SESSION['mesaj']) . '</p>'; unset($_SESSION['mesaj']); }
    if ($uyari) echo '<p class="uyari">' . e($uyari) . '</p>';
    echo '<form method="post">' . csrf() . '<input type="hidden" name="eylem" value="giris">
        <label>Kullanıcı adı<input name="kullanici" required autocomplete="username"></label>
        <label>Şifre<input type="password" name="sifre" required autocomplete="current-password"></label>
        <button class="ana">Giriş yap</button></form></main></body></html>';
    exit;
}

// ---------- İşlemler ----------
if ($eylem === 'oyuncu') {
    $id = (int) ($_POST['id'] ?? 0);
    $ne = (string) ($_POST['ne'] ?? '');
    if ($ne === 'engelle') tm_sorgu('UPDATE oyuncular SET engelli = 1 - engelli WHERE id = ?', [$id]);
    if ($ne === 'adsil') tm_sorgu("UPDATE oyuncular SET ad = '' WHERE id = ?", [$id]);
    if ($ne === 'sil') {
        foreach (['tiklamalar', 'kosular', 'oturumlar'] as $t) tm_sorgu("DELETE FROM $t WHERE oyuncu_id = ?", [$id]);
        tm_sorgu('DELETE FROM oyuncular WHERE id = ?', [$id]);
    }
    git('oyuncular', 'Oyuncu güncellendi.');
}
if ($eylem === 'skor') {
    tm_sorgu('UPDATE kosular SET gizli = 1 - gizli WHERE id = ?', [(int) ($_POST['id'] ?? 0)]);
    git('skorlar', 'Skor görünürlüğü değiştirildi.');
}
if ($eylem === 'skor_onay') {
    tm_sorgu('UPDATE kosular SET supheli = 0 WHERE id = ?', [(int) ($_POST['id'] ?? 0)]);
    git('skorlar', 'Skor onaylandı.');
}
if ($eylem === 'bolumler') {
    $acik = array_map('intval', (array) ($_POST['acik'] ?? []));
    $kapali = array_values(array_diff(array_keys(tm_bolumler()), $acik));
    tm_ayar_yaz('kapali_bolumler', implode(',', $kapali));
    $c = max(0.8, min(1.25, (float) str_replace(',', '.', (string) ($_POST['hiz_carpani'] ?? '1'))));
    tm_ayar_yaz('hiz_carpani', (string) $c);
    git('bolumler', 'Bölüm ayarları kaydedildi.');
}
if ($eylem === 'ayarlar') {
    $url = trim((string) ($_POST['randevu_url'] ?? ''));
    if ($url !== '' && !preg_match('#^https?://[^\s"<>]+$#i', $url)) git('ayarlar', 'Randevu adresi http(s):// ile başlamalı. Kaydedilmedi.');
    tm_ayar_yaz('oyun_aktif', isset($_POST['oyun_aktif']) ? '1' : '0');
    tm_ayar_yaz('randevu_url', mb_substr($url, 0, 300));
    foreach (['uygulama_url', 'uygulama_ios', 'uygulama_android'] as $a) {
        $uyg = trim((string) ($_POST[$a] ?? ''));
        if ($uyg !== '' && !preg_match('#^https?://[^\s"<>]+$#i', $uyg)) $uyg = '';
        tm_ayar_yaz($a, mb_substr($uyg, 0, 300));
    }
    tm_ayar_yaz('sponsor_metni', mb_substr(trim((string) ($_POST['sponsor_metni'] ?? '')), 0, 120));
    $tapi = rtrim(trim((string) ($_POST['tarak_api'] ?? '')), '/');
    if ($tapi !== '' && !preg_match('#^https?://[^\s"<>]+$#i', $tapi)) git('ayarlar', 'Tarak API adresi http(s):// ile başlamalı. Kaydedilmedi.');
    tm_ayar_yaz('tarak_api', mb_substr($tapi, 0, 200));
    // Anahtar boş bırakılırsa mevcut anahtar korunur (formda gösterilmez)
    $tanah = trim((string) ($_POST['tarak_oyun_anahtari'] ?? ''));
    if ($tanah !== '') tm_ayar_yaz('tarak_oyun_anahtari', mb_substr($tanah, 0, 200));
    foreach (['bakim_mesaji' => 200, 'duyuru' => 120, 'randevu_metni' => 40] as $a => $uz) tm_ayar_yaz($a, mb_substr(trim((string) ($_POST[$a] ?? '')), 0, $uz));
    git('ayarlar', 'Ayarlar kaydedildi.');
}
if ($eylem === 'hediye_ayar') {
    tm_ayar_yaz('hediye_aktif', isset($_POST['hediye_aktif']) ? '1' : '0');
    tm_ayar_yaz('hediye_parca', (string) max(5, min(100, (int) ($_POST['hediye_parca'] ?? 20))));
    foreach (['hediye_erkek', 'hediye_kadin'] as $a) { $d = trim((string) ($_POST[$a] ?? '')); if ($d !== '') tm_ayar_yaz($a, mb_substr($d, 0, 60)); }
    git('hediyeler', 'Hediye ayarları kaydedildi.');
}
if ($eylem === 'hediye_durum') {
    $yeni = in_array($_POST['durum'] ?? '', ['kullanildi', 'iptal', 'verildi'], true) ? $_POST['durum'] : 'verildi';
    tm_sorgu('UPDATE hediyeler SET durum = ?, kullanma = ? WHERE id = ?', [$yeni, $yeni === 'kullanildi' ? time() : null, (int) ($_POST['id'] ?? 0)]);
    git('hediyeler', 'Hediye güncellendi.');
}
if ($eylem === 'sponsor_ekle') {
    $ad = trim((string) ($_POST['ad'] ?? '')); $il = (string) ($_POST['il'] ?? ''); $ilce = trim((string) ($_POST['ilce'] ?? ''));
    $b = tm_bolgeler();
    if ($ad === '' || !isset($b[$il])) git('sponsorlar', 'İşletme adı ve il gerekli.');
    if ($ilce !== '' && !in_array($ilce, $b[$il], true)) git('sponsorlar', 'İlçe bu ile ait değil: ' . $ilce);
    $logo = '';
    if (!empty($_FILES['logo']['tmp_name']) && is_uploaded_file($_FILES['logo']['tmp_name'])) {
        if ($_FILES['logo']['size'] > 600 * 1024) git('sponsorlar', 'Logo en fazla 600 KB olabilir.');
        $bilgi = @getimagesize($_FILES['logo']['tmp_name']);
        $uzanti = [IMAGETYPE_PNG => 'png', IMAGETYPE_JPEG => 'jpg', IMAGETYPE_WEBP => 'webp'][$bilgi[2] ?? 0] ?? null;
        if (!$uzanti) git('sponsorlar', 'Logo PNG, JPG ya da WEBP olmalı.');
        $klasor = TM_KOK . '/uploads/sponsor';
        if (!is_dir($klasor)) mkdir($klasor, 0755, true);
        $dosya = bin2hex(random_bytes(10)) . '.' . $uzanti;
        if (!move_uploaded_file($_FILES['logo']['tmp_name'], $klasor . '/' . $dosya)) git('sponsorlar', 'Logo kaydedilemedi.');
        $logo = 'uploads/sponsor/' . $dosya;
    }
    $renk = preg_match('/^#[0-9a-fA-F]{6}$/', (string) ($_POST['renk'] ?? '')) ? $_POST['renk'] : '#1c2023';
    $bitis = !empty($_POST['bitis']) ? (int) strtotime($_POST['bitis'] . ' 23:59:59') : 0;
    tm_sorgu('INSERT INTO sponsorlar (ad, hizmet, il, ilce, logo, renk, aktif, bitis, tarak_id, olusturma) VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?, ?)',
        [mb_substr($ad, 0, 80), mb_substr(trim((string) ($_POST['hizmet'] ?? '')), 0, 60), $il, $ilce, $logo, $renk, $bitis, mb_substr(trim((string) ($_POST['tarak_id'] ?? '')), 0, 40), time()]);
    git('sponsorlar', 'Sponsor eklendi.');
}
if ($eylem === 'sponsor_durum') {
    $id = (int) ($_POST['id'] ?? 0);
    if (($_POST['ne'] ?? '') === 'sil') {
        $sp = tm_satir('SELECT logo FROM sponsorlar WHERE id = ?', [$id]);
        if ($sp && $sp['logo'] !== '' && preg_match('#^uploads/sponsor/[a-f0-9]{20}\.(png|jpg|webp)$#', $sp['logo'])) @unlink(TM_KOK . '/' . $sp['logo']);
        tm_sorgu('DELETE FROM sponsorlar WHERE id = ?', [$id]);
        git('sponsorlar', 'Sponsor silindi.');
    }
    tm_sorgu('UPDATE sponsorlar SET aktif = 1 - aktif WHERE id = ?', [$id]);
    git('sponsorlar', 'Sponsor güncellendi.');
}
if ($eylem === 'anahtar_yenile') {
    tm_ayar_yaz('entegrasyon_anahtari', bin2hex(random_bytes(24)));
    git('hediyeler', 'Entegrasyon anahtarı yenilendi. Tarak Mobil sunucusundaki anahtarı da güncelleyin.');
}
if ($eylem === 'sifre') {
    $y = tm_satir('SELECT * FROM yoneticiler WHERE id = ?', [$_SESSION['yonetici']]);
    $yeni = (string) ($_POST['yeni'] ?? '');
    if (!$y || !password_verify((string) ($_POST['eski'] ?? ''), $y['sifre'])) git('ayarlar', 'Mevcut şifre hatalı.');
    if (strlen($yeni) < 10) git('ayarlar', 'Yeni şifre en az 10 karakter olmalı.');
    tm_sorgu('UPDATE yoneticiler SET sifre = ? WHERE id = ?', [password_hash($yeni, PASSWORD_DEFAULT), $y['id']]);
    git('ayarlar', 'Şifre değiştirildi.');
}

function sayfa_bas(string $baslik): void
{
    echo '<!doctype html><html lang="tr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="robots" content="noindex,nofollow"><title>'
        . e($baslik) . ' · Tarak Oyun</title><link rel="stylesheet" href="admin.css"><script src="admin.js" defer></script></head><body>';
}

$s = (string) ($_GET['s'] ?? 'genel');
$menu = ['genel' => 'Genel Bakış', 'oyuncular' => 'Oyuncular', 'skorlar' => 'Skorlar', 'hediyeler' => 'Hediyeler', 'sponsorlar' => 'Sponsorlar', 'bolumler' => 'Bölümler', 'ayarlar' => 'Ayarlar'];
if (!isset($menu[$s])) $s = 'genel';
$ayar = tm_ayarlar();
sayfa_bas($menu[$s]);
echo '<header class="ust"><img src="../assets/img/logo-acik.svg" alt="tarak.app"><nav>';
foreach ($menu as $k => $ad) echo '<a href="?s=' . $k . '"' . ($k === $s ? ' class="secili" aria-current="page"' : '') . '>' . e($ad) . '</a>';
echo '</nav><div class="sag"><a href="../" target="_blank" rel="noopener">Oyunu aç ↗</a><form method="post">' . csrf() . '<input type="hidden" name="eylem" value="cikis"><button>Çıkış</button></form></div></header><main>';
if (!empty($_SESSION['mesaj'])) { echo '<p class="bilgi">' . e($_SESSION['mesaj']) . '</p>'; unset($_SESSION['mesaj']); }
if ($ayar['oyun_aktif'] !== '1') echo '<p class="uyari">Oyun şu an KAPALI: ziyaretçiler bakım ekranını görüyor.</p>';

$bugun = date('Y-m-d');

if ($s === 'genel') {
    $gunSayisi = in_array((int) ($_GET['gun'] ?? 14), [7, 14, 30], true) ? (int) ($_GET['gun'] ?? 14) : 14;
    $ilkGun = date('Y-m-d', strtotime('-' . ($gunSayisi - 1) . ' days'));
    $toplamOyuncu = (int) tm_deger('SELECT COUNT(*) FROM oyuncular');
    $cevrimici = (int) tm_deger('SELECT COUNT(DISTINCT oyuncu_id) FROM oturumlar WHERE son_nabiz > ?', [time() - 120]);
    $bugunTekil = (int) tm_deger('SELECT COUNT(DISTINCT oyuncu_id) FROM oturumlar WHERE gun = ?', [$bugun]);
    $bugunGiris = (int) tm_deger('SELECT COUNT(*) FROM oturumlar WHERE gun = ?', [$bugun]);
    $bugunYeni = (int) tm_deger('SELECT COUNT(*) FROM oyuncular WHERE ilk_gun = ?', [$bugun]);
    $toplamGiris = (int) tm_deger('SELECT COUNT(*) FROM oturumlar');
    $toplamKosu = (int) tm_deger('SELECT COUNT(*) FROM kosular');
    $tiklama = (int) tm_deger('SELECT COUNT(*) FROM tiklamalar');

    echo '<h1>Genel Bakış</h1><div class="kartlar">';
    foreach ([
        ['Şu an oyunda', $cevrimici, 'son 2 dakika'],
        ['Bugün giren oyuncu', $bugunTekil, n($bugunGiris) . ' giriş · ' . n($bugunYeni) . ' yeni'],
        ['Toplam oyuncu', $toplamOyuncu, 'tekil cihaz'],
        ['Toplam giriş', $toplamGiris, 'oyun açılışı'],
        ['Oynanan bölüm', $toplamKosu, 'tüm zamanlar'],
        ['Randevu tıklaması', $tiklama, 'oyundan siteye'],
    ] as [$ad, $deger, $alt]) echo '<div class="kpi"><span>' . e($ad) . '</span><b>' . n($deger) . '</b><small>' . e($alt) . '</small></div>';
    echo '</div>';

    // Günlük tekil oyuncu grafiği (tek seri)
    $ham = [];
    foreach (tm_satirlar('SELECT gun, COUNT(DISTINCT oyuncu_id) AS tekil, COUNT(*) AS giris FROM oturumlar WHERE gun >= ? GROUP BY gun', [$ilkGun]) as $r) $ham[$r['gun']] = $r;
    $gunler = [];
    for ($i = $gunSayisi - 1; $i >= 0; $i--) { $g = date('Y-m-d', strtotime("-$i days")); $gunler[$g] = ['tekil' => (int) ($ham[$g]['tekil'] ?? 0), 'giris' => (int) ($ham[$g]['giris'] ?? 0)]; }
    $tepe = max(1, max(array_column($gunler, 'tekil')));
    $adim = 1; foreach ([1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000, 50000] as $a) { $adim = $a; if ($tepe / $a <= 4) break; }
    $eksen = (int) ceil($tepe / $adim) * $adim;

    echo '<section class="panel"><div class="panel-ust"><h2>Günlük tekil oyuncu</h2><div class="suzgec">';
    foreach ([7, 14, 30] as $x) echo '<a href="?s=genel&amp;gun=' . $x . '"' . ($x === $gunSayisi ? ' class="secili"' : '') . '>' . $x . ' gün</a>';
    echo '</div></div>';
    $gen = 900; $yuk = 240; $sol = 44; $altBosluk = 26; $ustBosluk = 16;
    $alanY = $yuk - $altBosluk - $ustBosluk; $dilim = ($gen - $sol) / $gunSayisi; $cubuk = min(24, $dilim - 2);
    echo '<div class="grafik"><svg viewBox="0 0 ' . $gen . ' ' . $yuk . '" role="img" aria-label="Son ' . $gunSayisi . ' günün günlük tekil oyuncu sayısı">';
    for ($v = 0; $v <= $eksen; $v += $adim) {
        $y = round($ustBosluk + $alanY - $v / $eksen * $alanY, 1);
        echo '<line class="' . ($v ? 'izgara' : 'taban') . '" x1="' . $sol . '" x2="' . $gen . '" y1="' . $y . '" y2="' . $y . '"/><text class="eksen" x="' . ($sol - 8) . '" y="' . ($y + 4) . '" text-anchor="end">' . n($v) . '</text>';
    }
    $i = 0;
    foreach ($gunler as $g => $d) {
        $x = $sol + $i * $dilim + ($dilim - $cubuk) / 2;
        $h = $d['tekil'] / $eksen * $alanY;
        $y = $ustBosluk + $alanY - $h;
        if ($h > 0) {
            $r = min(4, $h, $cubuk / 2);
            echo '<path class="cubuk" d="M' . round($x, 1) . ' ' . ($ustBosluk + $alanY) . 'V' . round($y + $r, 1) . 'Q' . round($x, 1) . ' ' . round($y, 1) . ' ' . round($x + $r, 1) . ' ' . round($y, 1)
                . 'H' . round($x + $cubuk - $r, 1) . 'Q' . round($x + $cubuk, 1) . ' ' . round($y, 1) . ' ' . round($x + $cubuk, 1) . ' ' . round($y + $r, 1) . 'V' . ($ustBosluk + $alanY) . 'Z"/>';
        }
        if ($gunSayisi <= 14 || $i % 3 === ($gunSayisi - 1) % 3) echo '<text class="eksen" x="' . round($sol + $i * $dilim + $dilim / 2, 1) . '" y="' . ($yuk - 8) . '" text-anchor="middle">' . date('d.m', strtotime($g)) . '</text>';
        echo '<rect class="isabet" x="' . round($sol + $i * $dilim, 1) . '" y="' . $ustBosluk . '" width="' . round($dilim, 1) . '" height="' . $alanY . '" tabindex="0" data-ipucu="' . e(date('d.m.Y', strtotime($g)) . '|' . n($d['tekil']) . ' oyuncu|' . n($d['giris']) . ' giriş') . '"/>';
        $i++;
    }
    echo '</svg><div class="ipucu" hidden></div></div><details><summary>Tablo olarak göster</summary><table><tr><th>Gün</th><th class="s">Tekil oyuncu</th><th class="s">Giriş</th></tr>';
    foreach (array_reverse($gunler, true) as $g => $d) echo '<tr><td>' . date('d.m.Y', strtotime($g)) . '</td><td class="s">' . n($d['tekil']) . '</td><td class="s">' . n($d['giris']) . '</td></tr>';
    echo '</table></details></section>';

    // Bölüm hunisi (zorluk moduna göre süzülebilir)
    $modSuz = isset(TM_MODLAR[(string) ($_GET['mod'] ?? '')]) ? (string) $_GET['mod'] : '';
    $modKosul = $modSuz !== '' ? " AND zorluk = '" . $modSuz . "'" : '';   // yalnızca sabit listeden gelir
    $huni = [];
    foreach (tm_satirlar("SELECT CASE WHEN bolum >= 100 THEN 100 ELSE bolum END AS bolum, COUNT(*) AS deneme, COUNT(DISTINCT oyuncu_id) AS oyuncu,
        SUM(CASE WHEN sonuc='kazandi' THEN 1 ELSE 0 END) AS kazanma, SUM(CASE WHEN sonuc='kaybetti' THEN 1 ELSE 0 END) AS kaybetme,
        AVG(CASE WHEN sonuc<>'' THEN sure END) AS ort_sure FROM kosular WHERE 1=1$modKosul GROUP BY CASE WHEN bolum >= 100 THEN 100 ELSE bolum END") as $r) $huni[(int) $r['bolum']] = $r;
    $nedenAdi = ['arac' => 'Araç', 'kule' => 'Koli kulesi', 'kapi' => 'Berber tabelası', 'bariyer' => 'Bariyer', 'yan' => 'Yandan araç', 'cukur' => 'Çukur', 'yuksek' => 'Yüksek engel', 'tabela' => 'Tabela', 'tunel' => 'Tünel', 'lastik' => 'Lastik', 'kutu' => 'Alçak engel', 'genis' => 'Bank', 'koli' => 'Koli'];
    echo '<section class="panel"><div class="panel-ust"><h2>Bölüm performansı</h2><div class="suzgec">';
    foreach (['' => 'Tüm modlar'] + TM_MODLAR as $mk => $ma) echo '<a href="?s=genel&amp;gun=' . $gunSayisi . '&amp;mod=' . $mk . '"' . ($mk === $modSuz ? ' class="secili"' : '') . '>' . $ma . '</a>';
    echo '</div></div><p class="soluk">Oyuncuların nerede takıldığını gösterir. Geçme oranı = kazanılan / tüm denemeler.</p><div class="tablo-kaydir"><table><tr><th>Bölüm</th><th class="s">Oyuncu</th><th class="s">Deneme</th><th>Geçme oranı</th><th class="s">Ort. süre</th><th>En çok takılınan</th></tr>';
    foreach ([TM_UC => ['ad' => '3D Koşu'], 0 => ['ad' => '2D Sonsuz mod']] + tm_bolumler() as $no => $b) {
        $r = $huni[$no] ?? null;
        $bolumMu = $no && $no !== TM_UC;
        $oran = $r && $r['deneme'] && $bolumMu ? round($r['kazanma'] * 100 / $r['deneme']) : null;
        $neden = $r ? tm_deger("SELECT neden FROM kosular WHERE (bolum = ? OR (? = 100 AND bolum > 100)) AND neden <> ''$modKosul GROUP BY neden ORDER BY COUNT(*) DESC LIMIT 1", [$no, $no]) : '';
        echo '<tr><td>' . ($bolumMu ? $no . '. ' : '') . e($b['ad']) . '</td><td class="s">' . n($r['oyuncu'] ?? 0) . '</td><td class="s">' . n($r['deneme'] ?? 0) . '</td><td>';
        echo $oran === null ? '—' : '<span class="oran"><progress max="100" value="' . $oran . '"></progress> %' . $oran . '</span>';
        echo '</td><td class="s">' . ($r && $r['ort_sure'] !== null ? round((float) $r['ort_sure']) . ' sn' : '—') . '</td><td>' . e($neden ? ($nedenAdi[$neden] ?? $neden) : '—') . '</td></tr>';
    }
    echo '</table></div></section>';

    $modSayi = [];
    foreach (tm_satirlar('SELECT zorluk, COUNT(*) AS adet, COUNT(DISTINCT oyuncu_id) AS oyuncu FROM kosular GROUP BY zorluk') as $r) $modSayi[$r['zorluk']] = $r;
    echo '<section class="panel"><h2>Zorluk tercihi</h2><table><tr><th>Mod</th><th class="s">Oyuncu</th><th class="s">Deneme</th></tr>';
    foreach (TM_MODLAR as $mk => $ma) echo '<tr><td>' . $ma . '</td><td class="s">' . n($modSayi[$mk]['oyuncu'] ?? 0) . '</td><td class="s">' . n($modSayi[$mk]['adet'] ?? 0) . '</td></tr>';
    echo '</table></section>';

    $rotaSayi = tm_satirlar('SELECT bolum, COUNT(*) AS adet, COUNT(DISTINCT oyuncu_id) AS oyuncu, MAX(skor) AS rekor FROM kosular WHERE bolum > 100 GROUP BY bolum ORDER BY adet DESC LIMIT 30');
    echo '<section class="panel"><h2>3D rotalar</h2><div class="tablo-kaydir"><table><tr><th>Rota</th><th class="s">Oyuncu</th><th class="s">Deneme</th><th class="s">Rekor</th></tr>';
    foreach ($rotaSayi as $r) echo '<tr><td>' . ((int) $r['bolum'] - TM_UC) . '. ' . e(tm_rota_adi((int) $r['bolum'] - TM_UC)) . '</td><td class="s">' . n($r['oyuncu']) . '</td><td class="s">' . n($r['adet']) . '</td><td class="s">' . n($r['rekor']) . '</td></tr>';
    if (!$rotaSayi) echo '<tr><td colspan="4" class="soluk">Henüz 3D koşu yok.</td></tr>';
    echo '</table></div></section>';

    echo '<div class="iki">';
    foreach ([['Platform', 'platform', ['web' => 'Web tarayıcı', 'pwa' => 'Ana ekrana eklenen', 'android' => 'Android uygulaması']], ['Geliş kaynağı', 'kaynak', ['' => 'Doğrudan / uygulama']]] as [$ad, $alan, $esle]) {
        echo '<section class="panel"><h2>' . $ad . '</h2><table><tr><th>' . $ad . '</th><th class="s">Giriş</th></tr>';
        $satirlar = tm_satirlar("SELECT $alan AS ad, COUNT(*) AS adet FROM oturumlar GROUP BY $alan ORDER BY adet DESC LIMIT 8");
        foreach ($satirlar as $r) echo '<tr><td>' . e($esle[$r['ad']] ?? $r['ad']) . '</td><td class="s">' . n($r['adet']) . '</td></tr>';
        if (!$satirlar) echo '<tr><td colspan="2" class="soluk">Henüz veri yok.</td></tr>';
        echo '</table></section>';
    }
    echo '</div>';
}

if ($s === 'oyuncular') {
    $ara = trim((string) ($_GET['ara'] ?? ''));
    $sayfaNo = max(1, (int) ($_GET['p'] ?? 1));
    $kosul = ''; $p = [];
    if ($ara !== '') { $kosul = 'WHERE o.ad LIKE ? OR o.id = ?'; $p = ['%' . $ara . '%', (int) ltrim($ara, '#')]; }
    $toplam = (int) tm_deger("SELECT COUNT(*) FROM oyuncular o $kosul", $p);
    $liste = tm_satirlar("SELECT o.*, (SELECT COUNT(*) FROM kosular k WHERE k.oyuncu_id = o.id) AS kosu,
        (SELECT MAX(k.bolum) FROM kosular k WHERE k.oyuncu_id = o.id AND k.sonuc = 'kazandi' AND k.bolum < 100) AS en_bolum
        FROM oyuncular o $kosul ORDER BY o.son_gorulme DESC LIMIT 50 OFFSET " . (($sayfaNo - 1) * 50), $p);
    echo '<h1>Oyuncular <small>' . n($toplam) . '</small></h1><form class="ara" method="get"><input type="hidden" name="s" value="oyuncular"><input name="ara" value="' . e($ara) . '" placeholder="Takma ad veya #numara"><button>Ara</button></form>';
    echo '<section class="panel tablo-kaydir"><table><tr><th>#</th><th>Takma ad</th><th>Platform</th><th class="s">Giriş</th><th class="s">Deneme</th><th class="s">Geçtiği bölüm</th><th>İlk giriş</th><th>Son görülme</th><th></th></tr>';
    foreach ($liste as $o) {
        echo '<tr' . ($o['engelli'] ? ' class="pasif"' : '') . '><td>' . (int) $o['id'] . '</td><td>' . e($o['ad'] !== '' ? $o['ad'] : '—') . ($o['engelli'] ? ' <span class="etiket kotu">⛔ engelli</span>' : '') . '</td><td>' . e($o['platform']) . '</td><td class="s">' . n($o['giris_sayisi']) . '</td><td class="s">' . n($o['kosu']) . '</td><td class="s">' . (int) $o['en_bolum'] . '</td><td>' . tarih($o['ilk_gorulme']) . '</td><td>' . tarih($o['son_gorulme']) . '</td><td class="islem">';
        foreach (['engelle' => $o['engelli'] ? 'Engeli kaldır' : 'Engelle', 'adsil' => 'Adı sil', 'sil' => 'Sil'] as $ne => $yazi) {
            echo '<form method="post"' . ($ne === 'sil' ? ' data-onay="Bu oyuncu ve tüm skorları kalıcı olarak silinsin mi?"' : '') . '>' . csrf() . '<input type="hidden" name="eylem" value="oyuncu"><input type="hidden" name="id" value="' . (int) $o['id'] . '"><input type="hidden" name="ne" value="' . $ne . '"><button' . ($ne === 'sil' ? ' class="tehlike"' : '') . '>' . $yazi . '</button></form>';
        }
        echo '</td></tr>';
    }
    if (!$liste) echo '<tr><td colspan="9" class="soluk">Oyuncu bulunamadı.</td></tr>';
    echo '</table></section><div class="sayfalar">';
    if ($sayfaNo > 1) echo '<a href="?s=oyuncular&amp;ara=' . urlencode($ara) . '&amp;p=' . ($sayfaNo - 1) . '">← Önceki</a>';
    if ($sayfaNo * 50 < $toplam) echo '<a href="?s=oyuncular&amp;ara=' . urlencode($ara) . '&amp;p=' . ($sayfaNo + 1) . '">Sonraki →</a>';
    echo '</div>';
}

if ($s === 'skorlar') {
    $suz = ($_GET['suz'] ?? '') === 'supheli' ? 'supheli' : 'tum';
    $liste = tm_satirlar('SELECT k.*, o.ad, o.engelli FROM kosular k JOIN oyuncular o ON o.id = k.oyuncu_id WHERE k.skor > 0' . ($suz === 'supheli' ? ' AND k.supheli = 1' : '') . ' ORDER BY ' . ($suz === 'supheli' ? 'k.id DESC' : 'k.skor DESC') . ' LIMIT 100');
    echo '<h1>Skorlar</h1><div class="suzgec"><a href="?s=skorlar"' . ($suz === 'tum' ? ' class="secili"' : '') . '>En yüksek 100</a><a href="?s=skorlar&amp;suz=supheli"' . ($suz === 'supheli' ? ' class="secili"' : '') . '>Şüpheli (' . n(tm_deger('SELECT COUNT(*) FROM kosular WHERE supheli = 1')) . ')</a></div>';
    echo '<p class="soluk">Fiziksel olarak mümkün olmayan skorlar otomatik “şüpheli” işaretlenir ve sıralamada görünmez.</p><section class="panel tablo-kaydir"><table><tr><th>Oyuncu</th><th>Bölüm</th><th>Mod</th><th class="s">Skor</th><th class="s">Tarak</th><th class="s">Süre</th><th>Sonuç</th><th>Tarih</th><th>Durum</th><th></th></tr>';
    $sonucAdi = ['kazandi' => 'Kazandı', 'kaybetti' => 'Kaybetti', 'cikti' => 'Çıktı', '' => 'Yarım'];
    foreach ($liste as $k) {
        echo '<tr' . ($k['gizli'] ? ' class="pasif"' : '') . '><td>' . e($k['ad'] !== '' ? $k['ad'] : 'Oyuncu #' . $k['oyuncu_id']) . '</td><td>' . ((int) $k['bolum'] >= TM_UC ? '3D · ' . e(tm_rota_adi((int) $k['bolum'] - TM_UC)) : ($k['bolum'] ? (int) $k['bolum'] : '2D Sonsuz')) . '</td><td>' . e(TM_MODLAR[$k['zorluk']] ?? '') . ($k['devam'] ? ' · devam' : '') . '</td><td class="s">' . n($k['skor']) . '</td><td class="s">' . n($k['tarak']) . '</td><td class="s">' . round((float) $k['sure']) . ' sn</td><td>' . ($sonucAdi[$k['sonuc']] ?? '') . '</td><td>' . tarih($k['baslangic']) . '</td><td>'
            . ($k['supheli'] ? '<span class="etiket uyar">⚠ şüpheli</span>' : '') . ($k['gizli'] ? ' <span class="etiket kotu">🚫 gizli</span>' : '') . (!$k['supheli'] && !$k['gizli'] ? '<span class="etiket iyi">✓ geçerli</span>' : '') . '</td><td class="islem">';
        echo '<form method="post">' . csrf() . '<input type="hidden" name="eylem" value="skor"><input type="hidden" name="id" value="' . (int) $k['id'] . '"><button>' . ($k['gizli'] ? 'Göster' : 'Gizle') . '</button></form>';
        if ($k['supheli']) echo '<form method="post">' . csrf() . '<input type="hidden" name="eylem" value="skor_onay"><input type="hidden" name="id" value="' . (int) $k['id'] . '"><button>Onayla</button></form>';
        echo '</td></tr>';
    }
    if (!$liste) echo '<tr><td colspan="10" class="soluk">Kayıt yok.</td></tr>';
    echo '</table></section>';
}

if ($s === 'bolumler') {
    $kapali = array_map('intval', array_filter(explode(',', $ayar['kapali_bolumler']), 'strlen'));
    echo '<h1>Bölümler</h1><form method="post">' . csrf() . '<input type="hidden" name="eylem" value="bolumler"><section class="panel"><label class="dar">Oyun hızı çarpanı (0,80 – 1,25)<input name="hiz_carpani" type="number" step="0.01" min="0.8" max="1.25" value="' . e($ayar['hiz_carpani']) . '"></label><p class="soluk">1,00 test edilen değerdir. Oyuncular zorlanıyorsa 0,92 gibi bir değerle kolaylaştırabilirsin.</p></section>';
    echo '<section class="panel tablo-kaydir"><table><tr><th>Açık</th><th>Bölüm</th><th>Dünya</th><th>Müşteri</th><th class="s">Hız (K / O / Z)</th></tr>';
    foreach (tm_bolumler() as $no => $b) echo '<tr><td><input type="checkbox" name="acik[]" value="' . $no . '"' . (in_array($no, $kapali, true) ? '' : ' checked') . ' aria-label="Bölüm ' . $no . ' açık"></td><td>' . $no . '. ' . e($b['ad']) . '</td><td>' . e($b['dunya']) . '</td><td>' . e($b['musteri']) . '</td><td class="s">' . e(implode(' / ', array_map(static fn($x) => (int) $x['hiz'], $b['modlar']))) . '</td></tr>';
    echo '</table><p class="soluk">Bölümler sırayla açıldığı için bir bölümü kapatmak, onu henüz geçmemiş oyuncuların sonraki bölümlere ilerlemesini de durdurur.</p></section><button class="ana">Kaydet</button></form>';
}

if ($s === 'sponsorlar') {
    $b = tm_bolgeler();
    echo '<h1>Sponsorlar</h1><p class="soluk">Sponsor işletmenin reklamı, oyunda <b>il/ilçesini o bölge olarak seçen</b> oyunculara görünür: hangi ilin haritasında oynarlarsa oynasınlar şehir binalarında ve yol kenarı panolarında çıkar. Koşu başına sponsor başına bir gösterim sayılır. Tarak Mobil berber paneli bu sayıları <code>sponsorIstatistik</code> ucundan alır.</p>';
    echo '<section class="panel"><h2>Yeni sponsor</h2><form method="post" enctype="multipart/form-data" class="iki">' . csrf() . '<input type="hidden" name="eylem" value="sponsor_ekle">
        <label>İşletme adı<input name="ad" maxlength="80" required placeholder="Yıldırım Barber"></label>
        <label>Hediye / hizmet<input name="hizmet" maxlength="60" placeholder="Sakal Tıraşı"></label>
        <label>İl<select name="il" required><option value="">Seç…</option>';
    foreach (array_keys($b) as $il) echo '<option>' . e($il) . '</option>';
    echo '</select></label>
        <label>İlçe (boşsa ilin tamamı)<input name="ilce" maxlength="40" list="ilceler" placeholder="Çankaya"></label>
        <datalist id="ilceler">';
    foreach ($b as $il => $l) foreach ($l as $x) echo '<option value="' . e($x) . '">' . e($il) . '</option>';
    echo '</datalist>
        <label>Logo (PNG / JPG / WEBP, en fazla 600 KB)<input type="file" name="logo" accept="image/png,image/jpeg,image/webp"></label>
        <label>Pano rengi<input type="color" name="renk" value="#1c2023"></label>
        <label>Bitiş tarihi (boşsa süresiz)<input type="date" name="bitis"></label>
        <label>Tarak Mobil işletme numarası (berber paneli için)<input name="tarak_id" maxlength="40"></label>
        <button class="ana">Sponsoru ekle</button></form></section>';
    $esik = date('Y-m-d', time() - 29 * 86400);
    $liste = tm_satirlar('SELECT s.*, (SELECT COUNT(*) FROM sponsor_gosterim g WHERE g.sponsor_id = s.id) AS toplam,
        (SELECT COUNT(DISTINCT g.oyuncu_id) FROM sponsor_gosterim g WHERE g.sponsor_id = s.id) AS tekil,
        (SELECT COUNT(*) FROM sponsor_gosterim g WHERE g.sponsor_id = s.id AND g.gun >= ?) AS son30,
        (SELECT COUNT(*) FROM oyuncular p WHERE p.il = s.il AND (s.ilce = \'\' OR p.ilce = s.ilce)) AS bolgedeki FROM sponsorlar s ORDER BY s.id DESC', [$esik]);
    echo '<section class="panel tablo-kaydir"><h2>Sponsor işletmeler</h2><table><tr><th>Logo</th><th>İşletme</th><th>Bölge</th><th>Hizmet</th><th class="s">Gösterim</th><th class="s">Tekil oyuncu</th><th class="s">Son 30 gün</th><th class="s">Bölgedeki oyuncu</th><th>Durum</th><th></th></tr>';
    foreach ($liste as $sp) {
        echo '<tr><td>' . ($sp['logo'] !== '' ? '<img src="../' . e($sp['logo']) . '" alt="" style="height:32px;max-width:80px;object-fit:contain;background:#fff;border-radius:6px">' : '—') . '</td><td>' . e($sp['ad']) . ($sp['tarak_id'] !== '' ? '<br><small class="soluk">Tarak #' . e($sp['tarak_id']) . '</small>' : '') . '</td><td>' . e($sp['il'] . ($sp['ilce'] !== '' ? ' / ' . $sp['ilce'] : ' (tüm il)')) . '</td><td>' . e($sp['hizmet']) . '</td>
            <td class="s">' . (int) $sp['toplam'] . '</td><td class="s">' . (int) $sp['tekil'] . '</td><td class="s">' . (int) $sp['son30'] . '</td><td class="s">' . (int) $sp['bolgedeki'] . '</td>
            <td>' . ((int) $sp['aktif'] ? 'Yayında' : 'Durduruldu') . ($sp['bitis'] ? '<br><small class="soluk">' . date('d.m.Y', (int) $sp['bitis']) . '’e kadar</small>' : '') . '</td><td class="islem">';
        echo '<form method="post">' . csrf() . '<input type="hidden" name="eylem" value="sponsor_durum"><input type="hidden" name="id" value="' . (int) $sp['id'] . '"><button>' . ((int) $sp['aktif'] ? 'Durdur' : 'Yayınla') . '</button></form>';
        echo '<form method="post" data-onay="Sponsor ve logosu silinsin mi? Gösterim kayıtları kalır.">' . csrf() . '<input type="hidden" name="eylem" value="sponsor_durum"><input type="hidden" name="id" value="' . (int) $sp['id'] . '"><input type="hidden" name="ne" value="sil"><button class="tehlike">Sil</button></form>';
        echo '</td></tr>';
    }
    if (!$liste) echo '<tr><td colspan="10" class="soluk">Henüz sponsor yok. Oyunda boş panolarda "Berberler: oyuna sponsor ol" reklamı görünür.</td></tr>';
    echo '</table></section>';
}

if ($s === 'hediyeler') {
    $yil = (int) date('Y');
    $say = static fn(string $d) => (int) tm_deger('SELECT COUNT(*) FROM hediyeler WHERE yil = ? AND durum = ?', [$yil, $d]);
    $parcaToplam = (int) tm_deger("SELECT COALESCE(SUM(parca), 0) FROM kosular WHERE supheli = 0 AND gun >= ?", [$yil . '-01-01']);
    echo '<h1>Hediyeler</h1><p class="soluk">Oyuncular zor yerlerdeki hediye parçalarını toplar; ' . (int) $ayar['hediye_parca'] . ' parçaya ulaşan oyuncu yılda bir kez Tarak Mobil\'de kullanılacak hediye kodu alır. Parçalar sunucuda, şüpheli olmayan koşulardan sayılır (koşu başına en fazla 3).</p>';
    echo '<div class="kartlar"><div class="kart"><b>' . $say('verildi') . '</b><span>Bekleyen kod (' . $yil . ')</span></div><div class="kart"><b>' . $say('kullanildi') . '</b><span>Kullanılan</span></div><div class="kart"><b>' . $say('suresi_doldu') . '</b><span>Süresi dolan (30 gün)</span></div><div class="kart"><b>' . $say('iptal') . '</b><span>İptal</span></div><div class="kart"><b>' . $parcaToplam . '</b><span>Bu yıl toplanan parça</span></div></div>';
    echo '<div class="iki"><section class="panel"><h2>Ayarlar</h2><form method="post">' . csrf() . '<input type="hidden" name="eylem" value="hediye_ayar">
        <label class="kutu"><input type="checkbox" name="hediye_aktif"' . ($ayar['hediye_aktif'] === '1' ? ' checked' : '') . '> Hediye kodu verilsin</label>
        <label>Bir hediye için gereken parça (5 – 100)<input name="hediye_parca" type="number" min="5" max="100" value="' . e($ayar['hediye_parca']) . '"></label>
        <label>Erkek hediyesi (Koko ile oynayanlar)<input name="hediye_erkek" maxlength="60" value="' . e($ayar['hediye_erkek']) . '"></label>
        <label>Kadın hediyesi (Kiki ile oynayanlar)<input name="hediye_kadin" maxlength="60" value="' . e($ayar['hediye_kadin']) . '"></label>
        <p class="soluk">20 Aralık – 15 Ocak arasında verilen kodların adı "Yılbaşı Hediyesi" olarak başlar.</p>
        <button class="ana">Kaydet</button></form></section>
        <section class="panel"><h2>Tarak Mobil entegrasyonu</h2>
        <p class="soluk">Tarak Mobil sunucusu kodu şu adreslerle doğrular ve kullanır (başlık: <code>X-Tarak-Anahtar</code>):</p>
        <p><code>GET ../api/index.php?islem=hediyeDogrula&amp;kod=TRK-XXXX-XXXX</code><br><code>POST ../api/index.php?islem=hediyeKullan&amp;kod=TRK-XXXX-XXXX</code></p>
        <label>Entegrasyon anahtarı<input readonly value="' . e(tm_entegrasyon_anahtari()) . '" onclick="this.select()"></label>
        <form method="post" data-onay="Anahtar yenilensin mi? Tarak Mobil tarafındaki anahtar da değiştirilmeli.">' . csrf() . '<input type="hidden" name="eylem" value="anahtar_yenile"><button>Anahtarı yenile</button></form>
        </section></div>';
    $liste = tm_satirlar('SELECT h.*, p.ad AS oyuncu FROM hediyeler h JOIN oyuncular p ON p.id = h.oyuncu_id ORDER BY h.id DESC LIMIT 200');
    echo '<section class="panel tablo-kaydir"><h2>Son kodlar</h2><table><tr><th>Kod</th><th>Hediye</th><th>Oyuncu</th><th>Tarih</th><th>Son kullanma</th><th>Durum</th><th></th></tr>';
    foreach ($liste as $h) {
        $h['durum'] = tm_kupon_durumu($h);
        echo '<tr><td><code>' . e($h['kod']) . '</code></td><td>' . e($h['ad']) . '</td><td>' . e($h['oyuncu'] !== '' ? $h['oyuncu'] : 'Oyuncu #' . $h['oyuncu_id']) . '</td><td>' . date('d.m.Y H:i', (int) $h['olusturma']) . '</td><td>' . ((int) $h['son_tarih'] ? date('d.m.Y', (int) $h['son_tarih']) : '—') . '</td><td>' . e($h['durum']) . ($h['kullanma'] ? ' · ' . date('d.m.Y', (int) $h['kullanma']) : '') . '</td><td class="islem">';
        foreach (['kullanildi' => 'Kullanıldı', 'iptal' => 'İptal', 'verildi' => 'Geri al'] as $d => $yazi) {
            if ($h['durum'] === $d) continue;
            echo '<form method="post">' . csrf() . '<input type="hidden" name="eylem" value="hediye_durum"><input type="hidden" name="id" value="' . (int) $h['id'] . '"><input type="hidden" name="durum" value="' . $d . '"><button>' . $yazi . '</button></form>';
        }
        echo '</td></tr>';
    }
    if (!$liste) echo '<tr><td colspan="7" class="soluk">Henüz hediye kodu verilmedi.</td></tr>';
    echo '</table></section>';
}

if ($s === 'ayarlar') {
    echo '<h1>Ayarlar</h1><div class="iki"><section class="panel"><h2>Oyun</h2><form method="post">' . csrf() . '<input type="hidden" name="eylem" value="ayarlar">
        <label class="kutu"><input type="checkbox" name="oyun_aktif"' . ($ayar['oyun_aktif'] === '1' ? ' checked' : '') . '> Oyun yayında</label>
        <label>Bakım mesajı<input name="bakim_mesaji" maxlength="200" value="' . e($ayar['bakim_mesaji']) . '"></label>
        <label>Ana ekran duyurusu (boşsa görünmez)<input name="duyuru" maxlength="120" value="' . e($ayar['duyuru']) . '"></label>
        <label>Randevu düğmesi adresi (boşsa görünmez)<input name="randevu_url" maxlength="300" value="' . e($ayar['randevu_url']) . '"></label>
        <label>Randevu düğmesi yazısı<input name="randevu_metni" maxlength="40" value="' . e($ayar['randevu_metni']) . '"></label>
        <label>Tarak Mobil web adresi (bilgisayardan oynayanlar)<input name="uygulama_url" maxlength="300" value="' . e($ayar['uygulama_url'] ?? '') . '"></label>
        <label>App Store adresi (iPhone / iPad)<input name="uygulama_ios" maxlength="300" value="' . e($ayar['uygulama_ios'] ?? '') . '"></label>
        <label>Google Play adresi (Android)<input name="uygulama_android" maxlength="300" value="' . e($ayar['uygulama_android'] ?? '') . '"></label>
        <label>Sponsor yazısı (menüde, molada ve sonuç ekranında)<input name="sponsor_metni" maxlength="120" value="' . e($ayar['sponsor_metni'] ?? '') . '"></label>
        <h3>Tarak bağlantısı</h3>
        <p class="ipucu">Doluysa oyuncular "Tarak ile giriş" yapar; hediye kuponu Tarak’ta üretilir (müşteri profili + sponsor berberin paneli), sponsorlar Tarak’taki "Oyuna Sponsor Ol" kayıtlarından gelir. Boşsa oyun kendi kuponunu üretir.</p>
        <label>Tarak API adresi<input name="tarak_api" maxlength="200" placeholder="https://tarak.app/api" value="' . e($ayar['tarak_api'] ?? '') . '"></label>
        <label>Oyun anahtarı (Tarak sunucusundaki GAME_SERVER_KEY) ' . (($ayar['tarak_oyun_anahtari'] ?? '') !== '' ? '· kayıtlı, değiştirmek için yenisini yazın' : '· henüz yok') . '<input name="tarak_oyun_anahtari" type="password" autocomplete="off" maxlength="200"></label>
        <button class="ana">Kaydet</button></form></section>
        <section class="panel"><h2>Şifre değiştir</h2><form method="post">' . csrf() . '<input type="hidden" name="eylem" value="sifre">
        <label>Mevcut şifre<input type="password" name="eski" required autocomplete="current-password"></label>
        <label>Yeni şifre (en az 10 karakter)<input type="password" name="yeni" required minlength="10" autocomplete="new-password"></label>
        <button class="ana">Şifreyi değiştir</button></form></section></div>';
}
echo '</main></body></html>';
