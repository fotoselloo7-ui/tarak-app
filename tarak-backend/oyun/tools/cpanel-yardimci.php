<?php
// cpanel-kur.sh yardımcıları (yalnız komut satırı). Sırları ekrana yazmaz.
//   php cpanel-yardimci.php dbcnf <backend> <cnf-dosyası>    -> MySQL ise istemci ayar dosyasını yazar, veritabanı adını basar
//   php cpanel-yardimci.php servis-ekle <config/services.php> -> 'game' ayarını (yoksa) dizinin sonuna ekler
if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
$islem = $argv[1] ?? '';

if ($islem === 'dbcnf') {
    $b = rtrim($argv[2], '/');
    require $b . '/vendor/autoload.php';
    $app = require $b . '/bootstrap/app.php';
    $app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
    $c = config('database.connections.' . config('database.default'));
    if (($c['driver'] ?? '') !== 'mysql') { echo "-\n"; exit(0); }
    $kac = fn($v) => '"' . str_replace(['\\', '"'], ['\\\\', '\\"'], (string) $v) . '"';
    file_put_contents($argv[3], "[client]\nuser=" . $kac($c['username']) . "\npassword=" . $kac($c['password']) . "\nhost=" . $c['host'] . "\nport=" . $c['port'] . "\n");
    chmod($argv[3], 0600);
    echo $c['database'], "\n";
    exit(0);
}

if ($islem === 'servis-ekle') {
    $f = $argv[2];
    $s = file_get_contents($f);
    if (strpos($s, "'game' =>") !== false) { echo "zaten var\n"; exit(0); }
    $ek = <<<'PHP'
    // "Randevuya Koş" oyunu: oyun sunucusunun anahtarı ve "Tarak ile giriş" sonrası dönülebilecek adresler
    'game' => [
        'key' => env('GAME_SERVER_KEY', ''),
        'return_urls' => array_values(array_filter(array_map('trim', explode(',', env('GAME_RETURN_URLS', 'https://tarak.app/oyun,https://mobil.tarak.app,tarakoyun://giris'))))),
    ],


PHP;
    $i = strrpos($s, '];');
    if ($i === false) { fwrite(STDERR, "services.php biçimi beklenmedik\n"); exit(1); }
    file_put_contents($f, substr($s, 0, $i) . $ek . substr($s, $i));
    echo "eklendi\n";
    exit(0);
}

if ($islem === 'rota-guncelle') {
    // Canlı routes/api.php içindeki oyun bloğunu depodakiyle değiştirir (yoksa sona ekler); bloğun dışına dokunmaz
    [$canliYol, $depoYol] = [$argv[2], $argv[3]];
    $blok = function (string $s) {
        $i = strpos($s, '| "Randevuya Koş" oyunu');
        if ($i === false) return null;
        $bas = strrpos(substr($s, 0, $i), '/*');
        $sonIsaret = '// --- Randevuya Koş oyunu: son ---';
        $j = strpos($s, $sonIsaret, $i);
        $son = $j === false ? strlen($s) : $j + strlen($sonIsaret);
        return [$bas, $son];
    };
    $canli = file_get_contents($canliYol);
    $depo = file_get_contents($depoYol);
    $d = $blok($depo);
    if (!$d) { fwrite(STDERR, "depoda oyun bloğu yok\n"); exit(1); }
    $yeni = substr($depo, $d[0], $d[1] - $d[0]);
    $c = $blok($canli);
    if ($c && substr($canli, $c[0], $c[1] - $c[0]) === $yeni) { echo "güncel\n"; exit(0); }
    $sonuc = $c ? substr($canli, 0, $c[0]) . $yeni . substr($canli, $c[1]) : rtrim($canli) . "\n\n" . $yeni . "\n";
    file_put_contents($canliYol, $sonuc);
    echo $c ? "güncellendi\n" : "eklendi\n";
    exit(0);
}

fwrite(STDERR, "kullanım: dbcnf | servis-ekle | rota-guncelle\n");
exit(1);
