<?php
// YALNIZCA YEREL TEST: rastgele şifreli yönetici oluşturur, bilgileri data/yerel-test-giris.txt dosyasına yazar.
// Canlı sunucuda kullanılmaz; orada hesap admin/ sayfasındaki kurulum formundan açılır.
if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
require __DIR__ . '/../../../tarak.app/oyun/inc/baslat.php';

if ((int) tm_deger('SELECT COUNT(*) FROM yoneticiler') > 0) { echo "Yönetici zaten var.\n"; exit; }
$sifre = bin2hex(random_bytes(8));
tm_sorgu('INSERT INTO yoneticiler (kullanici, sifre) VALUES (?, ?)', ['admin', password_hash($sifre, PASSWORD_DEFAULT)]);
file_put_contents(TM_VERI . '/yerel-test-giris.txt', "Adres: http://localhost:8812/admin/\nKullanici: admin\nSifre: $sifre\n");
echo "Hazır. Giriş bilgileri: tarak.app/oyun/data/yerel-test-giris.txt\n";
