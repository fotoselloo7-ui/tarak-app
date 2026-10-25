<?php

/**
 * Offline design preview for Tarak.app, never a production backend.
 * Uses the bundled original web demo service catalog, and clearly labelled
 * synthetic DEMO professionals. No external requests, database, or Composer.
 */
declare(strict_types=1);

function tarakLocalDemoApi(string $requestPath): void
{
    header('Content-Type: application/json; charset=utf-8');
    header('Cache-Control: no-store');
    header('X-Tarak-Data-Source: local-demo');

    if (!in_array(strtoupper($_SERVER['REQUEST_METHOD'] ?? 'GET'), ['GET', 'HEAD'], true)) {
        http_response_code(405);
        header('Allow: GET, HEAD');
        echo json_encode(['success' => false, 'demo' => true,
            'message' => 'Yerel demo önizlemesinde hesap, ödeme ve veri değiştirme işlemleri kapalıdır.'],
            JSON_UNESCAPED_UNICODE);
        return;
    }

    $file = __DIR__ . '/demo-catalog.json';
    $fixture = is_file($file) ? json_decode((string) file_get_contents($file), true) : null;
    if (!is_array($fixture)) {
        http_response_code(503);
        echo json_encode(['success' => false, 'message' => 'Yerel demo kataloğu bulunamadı.']);
        return;
    }

    $route = preg_replace('~^/api/?~', '', $requestPath);
    $categories = $fixture['categories'] ?? [];
    $services = $fixture['services'] ?? [];
    $answer = null;
    $status = 200;

    switch ($route) {
        case 'service-categories':
            $answer = ['success' => true, 'demo' => true, 'data' => $categories];
            break;

        case 'services':
            $categoryId = (string) ($_GET['category_id'] ?? '');
            $filtered = $categoryId === '' ? $services
                : array_values(array_filter($services,
                    static fn (array $service) => (string) $service['category_id'] === $categoryId));
            $answer = ['success' => true, 'demo' => true, 'data' => $filtered];
            break;

        case 'site-config':
            require_once __DIR__ . '/../tarak-backend/app/Support/SiteContentDefaults.php';
            $answer = ['success' => true, 'demo' => true,
                'data' => \App\Support\SiteContentDefaults::all()];
            break;

        case 'stats/home':
            $answer = ['success' => true, 'demo' => true,
                'data' => ['items' => []]];
            break;

        case 'health':
        case 'up':
            $answer = ['success' => true, 'demo' => true, 'message' => 'Tarak offline demo is ready'];
            break;
    }

    // Synthetic specialists for layout testing. These are NOT real or verified businesses.
    $specialists = [
        ['id' => 90001, 'name' => 'DEMO · Alanya Berber', 'type' => 'barber',
         'city' => 'Antalya', 'district' => 'Alanya', 'lat' => 36.5438, 'lng' => 31.9980],
        ['id' => 90002, 'name' => 'DEMO · Kadın Kuaförü', 'type' => 'coiffeur',
         'city' => 'Antalya', 'district' => 'Alanya', 'lat' => 36.5352, 'lng' => 32.0121],
        ['id' => 90003, 'name' => 'DEMO · Mahmutlar Berber', 'type' => 'barber',
         'city' => 'Antalya', 'district' => 'Mahmutlar', 'lat' => 36.4919, 'lng' => 32.0971],
        ['id' => 90004, 'name' => 'DEMO · Oba Kuaför', 'type' => 'coiffeur',
         'city' => 'Antalya', 'district' => 'Oba', 'lat' => 36.5431, 'lng' => 32.0531],
        ['id' => 90005, 'name' => 'DEMO · Kestel Erkek Berberi', 'type' => 'barber',
         'city' => 'Antalya', 'district' => 'Kestel', 'lat' => 36.5160, 'lng' => 32.0795],
        ['id' => 90006, 'name' => 'DEMO · Konaklı Kuaför', 'type' => 'coiffeur',
         'city' => 'Antalya', 'district' => 'Konaklı', 'lat' => 36.5943, 'lng' => 31.8809],
    ];

    if (str_starts_with($route, 'providers')) {
        $lat = $_GET['lat'] ?? null;
        $lng = $_GET['lng'] ?? null;
        $hasOrigin = is_numeric($lat) && is_numeric($lng)
            && abs((float) $lat) <= 90 && abs((float) $lng) <= 180
            && !((float) $lat === 0.0 && (float) $lng === 0.0);
        $radius = isset($_GET['max_distance_km']) && is_numeric($_GET['max_distance_km'])
            ? max(0, min(500, (float) $_GET['max_distance_km'])) : 0;
        $type = (string) ($_GET['type'] ?? '');
        $fold = static fn (string $value) => function_exists('mb_strtolower')
            ? mb_strtolower($value, 'UTF-8') : strtolower($value);
        $term = $fold(trim((string) ($_GET['q'] ?? '')));
        $result = [];
        foreach ($specialists as $specialist) {
            if (in_array($type, ['barber', 'coiffeur'], true) && $type !== $specialist['type']) {
                continue;
            }
            if ($term !== '' && !str_contains(
                $fold($specialist['name'] . ' ' . $specialist['district']), $term
            )) {
                continue;
            }
            $distance = null;
            if ($hasOrigin) {
                $dlat = deg2rad((float) $specialist['lat'] - (float) $lat);
                $dlng = deg2rad((float) $specialist['lng'] - (float) $lng);
                $a = sin($dlat / 2) ** 2
                    + cos(deg2rad((float) $lat)) * cos(deg2rad((float) $specialist['lat']))
                    * sin($dlng / 2) ** 2;
                $distance = round(6371 * 2 * asin(min(1.0, sqrt($a))), 1);
                if ($radius > 0 && $distance > $radius) continue;
            }
            $result[] = [
                'id' => (string) $specialist['id'],
                'user_id' => (string) $specialist['id'],
                'name' => $specialist['name'],
                'business_name' => $specialist['name'],
                'provider_type' => $specialist['type'],
                'city' => $specialist['city'],
                'district' => $specialist['district'],
                'avatar_url' => null,
                'cover_url' => null,
                'is_approved' => false,
                'is_verified' => false,
                'is_online' => true,
                'rating' => null,
                'review_count' => 0,
                'service_count' => 5,
                'discount_percent' => 0,
                'distance_km' => $distance,
                'created_at' => '2026-10-20T09:00:00Z',
                'user' => ['id' => (string) $specialist['id'], 'name' => $specialist['name']],
            ];
        }

        if ($hasOrigin && ($_GET['sort'] ?? '') === 'distance') {
            usort($result, static fn (array $a, array $b) =>
                ($a['distance_km'] ?? INF) <=> ($b['distance_km'] ?? INF));
        }
        if (preg_match('~^providers/(\\d+)$~', $route, $matched)) {
            $profile = null;
            foreach ($result as $card) {
                if ((string) $card['user_id'] === $matched[1]) {
                    $profile = $card;
                    break;
                }
            }
            $status = $profile === null ? 404 : 200;
            $answer = ['success' => $profile !== null, 'demo' => true,
                'data' => $profile, 'message' => $profile ? null : 'Demo uzman bulunamadı.'];
        } elseif ($route === 'providers/spotlight') {
            $answer = ['success' => true, 'demo' => true,
                'data' => array_slice($result, 0, 4),
                'meta' => ['rotate_seconds' => 8]];
        } elseif ($route === 'providers/featured' || $route === 'providers/newest') {
            $limit = max(1, min(20, (int) ($_GET['limit'] ?? 8)));
            $answer = ['success' => true, 'demo' => true, 'data' => array_slice($result, 0, $limit)];
        } elseif ($route === 'providers') {
            $page = max(1, (int) ($_GET['page'] ?? 1));
            $perPage = max(1, min(30, (int) ($_GET['per_page'] ?? 12)));
            $total = count($result);
            $answer = [
                'success' => true, 'demo' => true,
                'data' => array_slice($result, ($page - 1) * $perPage, $perPage),
                'sponsored' => [],
                'meta' => [
                    'current_page' => $page,
                    'last_page' => max(1, (int) ceil($total / $perPage)),
                    'per_page' => $perPage, 'total' => $total,
                    'rotation_seconds' => 30,
                ],
            ];
        }
    }

    if ($answer === null) {
        $status = 501;
        $answer = [
            'success' => false, 'demo' => true,
            'message' => 'Bu API işlemi çevrimdışı tasarım önizlemesinde bulunmuyor. Tam işlemler için yerel Laravel backend gerekir.',
        ];
    }
    http_response_code($status);
    if (strtoupper($_SERVER['REQUEST_METHOD']) !== 'HEAD') {
        echo json_encode($answer, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    }
}
