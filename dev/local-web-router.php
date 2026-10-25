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

// Local-only bundled fixtures. They take precedence over any older live-API flag.
// Explicit opt-in avoids accidentally presenting demo records as production users.
if (getenv('TARAK_DEV_DEMO') === '1' && preg_match('~^/api(?:/|$)~', $path)) {
    require_once __DIR__ . '/local-demo-api.php';
    tarakLocalDemoApi($path);
    return true;
}

if (getenv('TARAK_DEV_LIVE_API') === '1' && preg_match('~^/api(?:/|$)~', $path)) {
    // Explicit opt-in preview: GETs read the real live catalog, and login
    // can return a bearer token for viewing customer/provider dashboards.
    // ALL other mutations are blocked so local clicks never edit production.
    $method = strtoupper($_SERVER['REQUEST_METHOD'] ?? 'GET');
    $login = ($path === '/api/auth/login' && $method === 'POST');
    if (!in_array($method, ['GET', 'HEAD'], true) && !$login) {
        http_response_code(405);
        header('Content-Type: application/json; charset=utf-8');
        header('Allow: GET, HEAD');
        echo json_encode(['success' => false,
            'message' => 'Bu yerel web önizlemesi salt okunurdur. Canlı veriyi değiştiren işlemler kapalıdır.'],
            JSON_UNESCAPED_UNICODE);
        return true;
    }

    $query = parse_url($_SERVER['REQUEST_URI'] ?? '', PHP_URL_QUERY);
    $url = 'https://tarak.app' . $path . ($query ? '?' . $query : '');
    $requestHeaders = ['Accept: application/json'];
    $incoming = function_exists('getallheaders') ? getallheaders() : [];
    foreach ($incoming as $key => $value) {
        $key = strtolower($key);
        if ($key === 'authorization' || $key === 'content-type') {
            $requestHeaders[] = $key . ': ' . $value;
        }
    }
    if (!array_filter($requestHeaders, static fn ($h) => str_starts_with($h, 'authorization:'))) {
        $bearer = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? null;
        if (is_string($bearer) && str_starts_with($bearer, 'Bearer ')) {
            $requestHeaders[] = 'Authorization: ' . $bearer;
        }
    }

    header('Cache-Control: no-store');
    if (function_exists('curl_init')) {
        $handle = curl_init($url);
        curl_setopt_array($handle, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_CUSTOMREQUEST => $method,
            CURLOPT_HTTPHEADER => $requestHeaders,
            CURLOPT_TIMEOUT => 20,
            CURLOPT_CONNECTTIMEOUT => 8,
            CURLOPT_FOLLOWLOCATION => false,
            CURLOPT_ENCODING => '',
        ]);
        if ($login) {
            curl_setopt($handle, CURLOPT_POSTFIELDS, file_get_contents('php://input'));
        }
        $response = curl_exec($handle);
        $status = (int) curl_getinfo($handle, CURLINFO_HTTP_CODE);
        $mime = curl_getinfo($handle, CURLINFO_CONTENT_TYPE);
        curl_close($handle);
        if (!is_string($response) || $status === 0) {
            http_response_code(502);
            header('Content-Type: application/json; charset=utf-8');
            echo json_encode(['success' => false,
                'message' => 'Canlı Tarak API sunucusuna erişilemiyor.']);
            return true;
        }
        http_response_code($status);
        header('Content-Type: ' . ($mime ?: 'application/json; charset=utf-8'));
        if ($method !== 'HEAD') echo $response;
        return true;
    }

    // PHP cURL extension is optional. The HTTPS stream wrapper is sufficient
    // for a local, read-only demo if allow_url_fopen is enabled.
    $body = $login ? file_get_contents('php://input') : '';
    $ctx = stream_context_create(['http' => [
        'method' => $method, 'timeout' => 20, 'ignore_errors' => true,
        'follow_location' => 0,
        'header' => implode("\r\n", $requestHeaders),
        'content' => $login ? $body : '',
    ]]);
    $response = @file_get_contents($url, false, $ctx);
    if ($response === false) {
        http_response_code(502);
        header('Content-Type: application/json; charset=utf-8');
        echo json_encode(['success' => false,
            'message' => 'Canlı API erişimi başarısız. PHP cURL veya HTTPS stream wrapper etkin olmalı.']);
        return true;
    }
    $status = 200;
    foreach (($http_response_header ?? []) as $line) {
        if (preg_match('~^HTTP/\\S+\\s+(\\d{3})~', $line, $match)) {
            $status = (int) $match[1];
        }
    }
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    if ($method !== 'HEAD') echo $response;
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
