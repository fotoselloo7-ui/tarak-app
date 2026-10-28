<?php

// The PHP development server does not read tarak.app/.htaccess. This router
// gives it the same SPA/API split as the cPanel document root.
$webRoot = realpath(__DIR__ . '/../tarak.app');
$path = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';

if (str_contains($path, "\0") || preg_match('~(^|/)\.(?!well-known(?:/|$))~', $path)) {
    http_response_code(403);
    exit;
}

if (preg_match('~^/(api|up|payment-result)(?:/|$)~', $path)) {
    require $webRoot . '/index.php';
    return true;
}

if (str_starts_with($path, '/storage/')) {
    $relative = substr($path, strlen('/storage/'));
    $file = realpath(__DIR__ . '/../tarak-backend/storage/app/public/' . $relative);
    $storageRoot = realpath(__DIR__ . '/../tarak-backend/storage/app/public');
    if ($file && $storageRoot && str_starts_with($file, $storageRoot . DIRECTORY_SEPARATOR) && is_file($file)) {
        $mime = mime_content_type($file) ?: 'application/octet-stream';
        header('Content-Type: ' . $mime);
        readfile($file);
        return true;
    }
    http_response_code(404);
    exit;
}

$file = realpath($webRoot . $path);
if ($path !== '/' && $file && str_starts_with($file, $webRoot . DIRECTORY_SEPARATOR) && is_file($file)) {
    return false;
}

if (preg_match('~^/(assets|storage|demo-media)/~', $path)) {
    http_response_code(404);
    exit;
}

header('Content-Type: text/html; charset=utf-8');
header('Cache-Control: no-cache');
readfile($webRoot . '/index.html');
return true;
