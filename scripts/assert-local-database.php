<?php

require dirname(__DIR__) . '/tarak-backend/vendor/autoload.php';
$env = Dotenv\Dotenv::parse(file_get_contents(dirname(__DIR__) . '/tarak-backend/.env'));
$connection = $env['DB_CONNECTION'] ?? '';
if (($env['APP_ENV'] ?? '') !== 'local' || !empty($env['DB_URL'])
    || !in_array($connection, ['sqlite', 'mysql'], true)
    || ($connection === 'mysql' && !in_array($env['DB_HOST'] ?? '', ['127.0.0.1', 'localhost', '::1'], true))) {
    fwrite(STDERR, "Only APP_ENV=local with SQLite or loopback MySQL and no DB_URL is permitted.\n");
    exit(1);
}
echo $connection;
