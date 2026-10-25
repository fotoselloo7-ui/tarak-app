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
 * This router serves the Vite-built frontend independently. API requests
 * use explicit offline demo mode or an isolated localhost Laravel instance;
 * no requests are ever forwarded to the live Tarak.app/cPanel API.
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

// Real LOCAL Laravel API mode. Useful for testing registration/login/OTP
// against an isolated local database without touching production or cPanel.
if (getenv('TARAK_DEV_LOCAL_API') === '1' && preg_match('~^/api(?:/|$)~', $path)) {
    $method = strtoupper($_SERVER['REQUEST_METHOD'] ?? 'GET');
    $query = parse_url($_SERVER['REQUEST_URI'] ?? '', PHP_URL_QUERY);
    $target = 'http://127.0.0.1:8000' . $path . ($query ? '?' . $query : '');
    $incoming = function_exists('getallheaders') ? getallheaders() : [];
    $headers = ['Accept: application/json'];
    foreach ($incoming as $key => $value) {
        if (in_array(strtolower($key), ['authorization', 'content-type', 'accept'], true)) {
            $headers[] = $key . ': ' . $value;
        }
    }
    $auth = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? null;
    if ($auth && !array_filter($headers, static fn($v) => stripos($v, 'authorization:') === 0)) {
        $headers[] = 'Authorization: ' . $auth;
    }
    if (!function_exists('curl_init')) {
        http_response_code(503);
        header('Content-Type: application/json; charset=utf-8');
        echo json_encode(['success' => false,
            'message' => 'Yerel Laravel API proxy için PHP cURL eklentisi gerekli.']);
        return true;
    }
    $ch = curl_init($target);
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_CUSTOMREQUEST => $method,
        CURLOPT_HTTPHEADER => $headers,
        CURLOPT_TIMEOUT => 30,
        CURLOPT_CONNECTTIMEOUT => 3,
        CURLOPT_FOLLOWLOCATION => false,
    ]);
    if (!in_array($method, ['GET', 'HEAD'], true)) {
        curl_setopt($ch, CURLOPT_POSTFIELDS, file_get_contents('php://input'));
    }
    $response = curl_exec($ch);
    $status = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $type = curl_getinfo($ch, CURLINFO_CONTENT_TYPE);
    curl_close($ch);
    if (!is_string($response) || !$status) {
        http_response_code(502);
        header('Content-Type: application/json; charset=utf-8');
        echo json_encode(['success' => false, 'message' =>
            'Yerel Laravel API kapalı. Ayrı CMD: cd tarak-backend && php artisan serve --host=127.0.0.1 --port=8000'],
            JSON_UNESCAPED_UNICODE);
        return true;
    }
    http_response_code($status);
    header('Cache-Control: no-store');
    header('Content-Type: ' . ($type ?: 'application/json; charset=utf-8'));
    if ($method !== 'HEAD') echo $response;
    return true;
}

// Local-only bundled fixtures. They take precedence over any older live-API flag.
// Explicit opt-in avoids accidentally presenting demo records as production users.
if (getenv('TARAK_DEV_DEMO') === '1' && preg_match('~^/api(?:/|$)~', $path)) {
    require_once __DIR__ . '/local-demo-api.php';
    tarakLocalDemoApi($path);
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
