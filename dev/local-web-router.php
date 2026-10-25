<?php
/**
 * Tarak.app static SPA router for PHP's local development server.
 *
 * Start from the repository root:
 * php -S 127.0.0.1:8010 -t tarak.app dev/local-web-router.php
 *
 * IMPORTANT: PHP's built-in server prioritises index.php over index.html.
 * Without this router, / opens the production Laravel bridge which requires
 * Composer and an installed production-like backend.
 *
 * This router serves the Vite-built frontend independently. API requests are
 * forwarded to the local Laravel bridge ONLY when vendor/ and the backend are
 * actually installed; otherwise they return an explicit 503 JSON response.
 */
declare(strict_types=1);

$public = realpath(__DIR__ . '/../tarak.app');
if ($public === false) {
    http_response_code(500);
    echo 'Tarak public directory is missing.';
    return true;
}

$path = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';
$path = rawurldecode($path);
if (str_contains($path, "\0") || str_contains($path, '\\') ||
    preg_match('~(^|/)\\.(?!well-known(?:/|$))~', $path)) {
    http_response_code(403);
    echo 'Forbidden';
    return true;
}

if (preg_match('~^/(api|up|payment-result)(/|$)~', $path)) {
    $backend = realpath(__DIR__ . '/../tarak-backend');
    if ($backend === false || !is_file($backend . '/vendor/autoload.php')) {
        http_response_code(503);
        header('Content-Type: application/json; charset=utf-8');
        header('Cache-Control: no-store');
        echo json_encode([
            'success' => false,
            'message' => 'Yerel Laravel backend kurulu değil. Web tasarımı çalışır; API işlemleri için tarak-backend içinde composer install ve .env yapılandırması gereklidir.',
        ], JSON_UNESCAPED_UNICODE);
        return true;
    }
    require $public . '/index.php';
    return true;
}

// The production root serves index.html, NOT the bridge index.php.
if ($path === '/' || $path === '/index.html') {
    header('Content-Type: text/html; charset=utf-8');
    header('Cache-Control: no-store');
    readfile($public . '/index.html');
    return true;
}

// Never expose the Laravel bridge at /index.php from a local static UI server.
if ($path === '/index.php') {
    http_response_code(404);
    echo 'Not Found';
    return true;
}

$file = realpath($public . $path);
if ($file !== false && str_starts_with($file, $public . DIRECTORY_SEPARATOR) && is_file($file)) {
    // Returning false lets PHP's built-in server serve static assets efficiently.
    // Restrict direct .php execution except for the explicitly routed API bridge.
    if (strtolower(pathinfo($file, PATHINFO_EXTENSION)) === 'php') {
        http_response_code(404);
        echo 'Not Found';
        return true;
    }
    return false;
}

// Missing assets must be real 404s, not an HTML page returned as JS.
if (preg_match('~^/(assets|storage|demo-media)/~', $path)) {
    http_response_code(404);
    echo 'Not Found';
    return true;
}

// React client-side routes (e.g. /legal/privacy).
header('Content-Type: text/html; charset=utf-8');
header('Cache-Control: no-store');
readfile($public . '/index.html');
return true;
