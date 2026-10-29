<?php
// Tarak — bridge front controller, saved as  ~/public_html/index.php
//
//   /home/CPANEL_USER/public_html/      document root: React SPA + this file + .htaccess
//   /home/CPANEL_USER/tarak-backend/    Laravel (app, vendor, .env, storage ...) — NOT inside public_html
//
// .htaccess sends /api/*, /up and /payment-result/* here. This is Laravel's own public/index.php, only with the
// application folder one level up and the public path pointed at public_html (so /storage uploads resolve there).
// If you renamed the backend folder, change the one line below.

use Illuminate\Http\Request;

define('LARAVEL_START', microtime(true));

$backend = dirname(__DIR__).'/tarak-backend';

// cPanel-safe media fallback: serve managed public uploads even when storage:link
// is unavailable. The is_demo seed marker is unrelated to media and remains in DB.
$uriPath = rawurldecode((string) (parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/'));
if (preg_match('#^/(?:api/media/|storage/)(avatars|provider-media)/(.+)$#', $uriPath, $m)) {
    $relative = $m[1].'/'.ltrim(str_replace('\\\\', '/', $m[2]), '/');
    if ($relative === '' || str_contains($relative, '..') || str_contains($relative, "\0")) {
        http_response_code(404);
        exit;
    }

    $mediaRoot = realpath($backend.'/storage/app/public');
    $candidate = $mediaRoot ? realpath($mediaRoot.'/'.$relative) : false;

    if (!$mediaRoot || !$candidate || !str_starts_with($candidate, $mediaRoot.DIRECTORY_SEPARATOR) || !is_file($candidate)) {
        http_response_code(404);
        exit;
    }

    $mime = function_exists('mime_content_type') ? mime_content_type($candidate) : false;
    header('Content-Type: '.($mime ?: 'application/octet-stream'));
    header('Content-Length: '.filesize($candidate));
    header('Cache-Control: public, max-age=604800');
    header('X-Content-Type-Options: nosniff');
    readfile($candidate);
    exit;
}

if (! is_file($backend.'/vendor/autoload.php')) {
    http_response_code(503);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode(['success' => false, 'message' => 'Sunucu kurulumu tamamlanmadı: tarak-backend içinde "composer install --no-dev --optimize-autoloader" çalıştırılmalı.']);
    exit;
}

// Determine if the application is in maintenance mode...
if (file_exists($maintenance = $backend.'/storage/framework/maintenance.php')) {
    require $maintenance;
}

// Register the Composer autoloader...
require $backend.'/vendor/autoload.php';

// Bootstrap Laravel and handle the request...
$app = require_once $backend.'/bootstrap/app.php';
$app->usePublicPath(__DIR__);
$app->handleRequest(Request::capture());
