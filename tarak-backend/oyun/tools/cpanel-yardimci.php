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

fwrite(STDERR, "kullanım: dbcnf | servis-ekle\n");
exit(1);
