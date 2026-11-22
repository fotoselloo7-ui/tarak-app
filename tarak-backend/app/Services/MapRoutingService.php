<?php

namespace App\Services;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Turn-by-turn road routing proxy for Tarak Harita.
 *
 * Production deployments MUST set `MAP_ROUTING_BASE_URL` (self-hosted Valhalla /
 * OSRM or managed OpenRouteService) via `.env`. Non-production local/testing
 * defaults to FOSSGIS Valhalla with FOSSGIS OSRM fallback so real road paths,
 * distances, and durations work out of the box without depending on public OSRM
 * demo infrastructure in production.
 *
 * Never fabricates straight crow-flies lines when routing fails.
 */
class MapRoutingService
{
    private const DEV_VALHALLA_URL = 'https://valhalla1.openstreetmap.de/route';
    private const DEV_OSRM_CAR_URL = 'https://routing.openstreetmap.de/routed-car';
    private const DEV_OSRM_FOOT_URL = 'https://routing.openstreetmap.de/routed-foot';
    private const USER_AGENT = 'TarakApp/1.1 (+https://tarak.app)';

    /**
     * @return array{
     *   status: 'OK'|'NO_ROUTE'|'NOT_CONFIGURED'|'UNAVAILABLE',
     *   provider?: string,
     *   profile?: string,
     *   cached?: bool,
     *   distance_meters?: int,
     *   duration_seconds?: int,
     *   geometry?: array{type: 'LineString', coordinates: array<int, array{0: float, 1: float}>},
     *   bounds?: array{south: float, west: float, north: float, east: float},
     *   message?: string
     * }
     */
    public function calculateRoute(
        float $originLat,
        float $originLng,
        float $destLat,
        float $destLng,
        string $profile = 'driving',
    ): array {
        $normalizedProfile = $profile === 'walking' ? 'walking' : 'driving';
        $cacheKey = sprintf(
            'map:route:v1:%s:%.4f:%.4f:%.4f:%.4f',
            $normalizedProfile,
            $originLat,
            $originLng,
            $destLat,
            $destLng,
        );

        $cached = Cache::get($cacheKey);
        if (is_array($cached) && ($cached['status'] ?? null) === 'OK') {
            $cached['cached'] = true;

            return $cached;
        }

        $configuredProvider = strtolower(trim((string) config('services.map_routing.provider', 'valhalla')));
        $configuredUrl = trim((string) config('services.map_routing.base_url', ''));
        $apiKey = trim((string) config('services.map_routing.api_key', ''));

        if (app()->environment('production') && $configuredUrl === '') {
            return [
                'status' => 'NOT_CONFIGURED',
                'message' => 'Üretim yönlendirme sunucusu (MAP_ROUTING_BASE_URL) yapılandırılmadı.',
            ];
        }

        $ttlMinutes = max(1, (int) config('services.map_routing.cache_ttl_minutes', 10));

        if ($configuredUrl !== '') {
            $primary = match ($configuredProvider) {
                'ors', 'openrouteservice' => $this->queryOrs($configuredUrl, $apiKey, $originLat, $originLng, $destLat, $destLng, $normalizedProfile),
                'osrm' => $this->queryOsrm($configuredUrl, $originLat, $originLng, $destLat, $destLng, $normalizedProfile),
                default => $this->queryValhalla($configuredUrl, $originLat, $originLng, $destLat, $destLng, $normalizedProfile),
            };
        } else {
            // Non-production dev/testing: FOSSGIS Valhalla primary -> FOSSGIS OSRM fallback.
            $primary = $this->queryValhalla(self::DEV_VALHALLA_URL, $originLat, $originLng, $destLat, $destLng, $normalizedProfile);
            if ($primary['status'] === 'UNAVAILABLE') {
                $osrmUrl = $normalizedProfile === 'walking' ? self::DEV_OSRM_FOOT_URL : self::DEV_OSRM_CAR_URL;
                $primary = $this->queryOsrm($osrmUrl, $originLat, $originLng, $destLat, $destLng, $normalizedProfile);
            }
        }

        if ($primary['status'] === 'OK') {
            $primary['cached'] = false;
            Cache::put($cacheKey, $primary, now()->addMinutes($ttlMinutes));
        }

        return $primary;
    }

    /**
     * @return array<string, mixed>
     */
    private function queryValhalla(
        string $baseUrl,
        float $oLat,
        float $oLng,
        float $dLat,
        float $dLng,
        string $profile,
    ): array {
        $endpoint = rtrim($baseUrl, '/');
        if (!str_ends_with($endpoint, '/route')) {
            $endpoint .= '/route';
        }

        try {
            $response = Http::acceptJson()
                ->withHeaders(['User-Agent' => self::USER_AGENT])
                ->timeout(8)
                ->post($endpoint, [
                    'locations' => [
                        ['lat' => $oLat, 'lon' => $oLng],
                        ['lat' => $dLat, 'lon' => $dLng],
                    ],
                    'costing' => $profile === 'walking' ? 'pedestrian' : 'auto',
                    'units' => 'kilometers',
                    'language' => 'tr-TR',
                ]);

            if ($response->status() === 400) {
                return [
                    'status' => 'NO_ROUTE',
                    'message' => 'Başlangıç konumunuz ile işletme arasında kara yolu rotası bulunamadı.',
                ];
            }

            if (!$response->successful()) {
                Log::warning('MapRoutingService Valhalla HTTP error', [
                    'status' => $response->status(),
                ]);

                return ['status' => 'UNAVAILABLE'];
            }

            $json = $response->json();
            $legs = $json['trip']['legs'] ?? null;
            if (!is_array($legs) || empty($legs[0]['shape'])) {
                return ['status' => 'NO_ROUTE'];
            }

            $coordinates = [];
            $totalKm = 0.0;
            $totalSec = 0.0;

            foreach ($legs as $leg) {
                if (!is_array($leg) || empty($leg['shape'])) {
                    continue;
                }
                $pts = self::decodePolyline((string) $leg['shape'], 1e6);
                foreach ($pts as $idx => $pt) {
                    if ($idx === 0 && $coordinates !== [] && $coordinates[array_key_last($coordinates)] === $pt) {
                        continue;
                    }
                    $coordinates[] = $pt;
                }
                $legSummary = is_array($leg['summary'] ?? null) ? $leg['summary'] : [];
                $totalKm += (float) ($legSummary['length'] ?? 0);
                $totalSec += (float) ($legSummary['time'] ?? 0);
            }

            $summary = is_array($json['trip']['summary'] ?? null) ? $json['trip']['summary'] : [];
            if (isset($summary['length'])) {
                $totalKm = (float) $summary['length'];
            }
            if (isset($summary['time'])) {
                $totalSec = (float) $summary['time'];
            }

            if (count($coordinates) < 2) {
                return ['status' => 'NO_ROUTE'];
            }

            return $this->okPayload(
                provider: 'valhalla',
                profile: $profile,
                distanceMeters: (int) round($totalKm * 1000),
                durationSeconds: (int) round($totalSec),
                coordinates: $coordinates,
            );
        } catch (\Throwable $ex) {
            Log::warning('MapRoutingService Valhalla failed', ['error' => $ex->getMessage()]);

            return ['status' => 'UNAVAILABLE'];
        }
    }

    /**
     * @return array<string, mixed>
     */
    private function queryOsrm(
        string $baseUrl,
        float $oLat,
        float $oLng,
        float $dLat,
        float $dLng,
        string $profile,
    ): array {
        $trimmed = rtrim($baseUrl, '/');
        if ($profile === 'walking' && str_ends_with($trimmed, '/routed-car')) {
            $trimmed = substr($trimmed, 0, -strlen('/routed-car')) . '/routed-foot';
        }
        $osrmProfile = $profile === 'walking' ? 'foot' : 'driving';
        $endpoint = sprintf(
            '%s/route/v1/%s/%.6F,%.6F;%.6F,%.6F',
            $trimmed,
            $osrmProfile,
            $oLng,
            $oLat,
            $dLng,
            $dLat,
        );

        try {
            $response = Http::acceptJson()
                ->withHeaders(['User-Agent' => self::USER_AGENT])
                ->timeout(8)
                ->get($endpoint, [
                    'overview' => 'full',
                    'geometries' => 'geojson',
                ]);

            if ($response->status() === 400) {
                return [
                    'status' => 'NO_ROUTE',
                    'message' => 'Başlangıç konumunuz ile işletme arasında kara yolu rotası bulunamadı.',
                ];
            }

            if (!$response->successful()) {
                return ['status' => 'UNAVAILABLE'];
            }

            $json = $response->json();
            if (($json['code'] ?? '') === 'NoRoute' || empty($json['routes'][0])) {
                return ['status' => 'NO_ROUTE'];
            }

            $route = $json['routes'][0];
            $rawCoords = $route['geometry']['coordinates'] ?? null;
            if (!is_array($rawCoords) || count($rawCoords) < 2) {
                return ['status' => 'NO_ROUTE'];
            }

            $coordinates = [];
            foreach ($rawCoords as $pt) {
                if (is_array($pt) && count($pt) >= 2 && is_numeric($pt[0]) && is_numeric($pt[1])) {
                    $coordinates[] = [(float) $pt[0], (float) $pt[1]];
                }
            }
            if (count($coordinates) < 2) {
                return ['status' => 'NO_ROUTE'];
            }

            return $this->okPayload(
                provider: 'osrm',
                profile: $profile,
                distanceMeters: (int) round((float) ($route['distance'] ?? 0)),
                durationSeconds: (int) round((float) ($route['duration'] ?? 0)),
                coordinates: $coordinates,
            );
        } catch (\Throwable $ex) {
            Log::warning('MapRoutingService OSRM failed', ['error' => $ex->getMessage()]);

            return ['status' => 'UNAVAILABLE'];
        }
    }

    /**
     * @return array<string, mixed>
     */
    private function queryOrs(
        string $baseUrl,
        string $apiKey,
        float $oLat,
        float $oLng,
        float $dLat,
        float $dLng,
        string $profile,
    ): array {
        $orsProfile = $profile === 'walking' ? 'foot-walking' : 'driving-car';
        $endpoint = rtrim($baseUrl, '/') . "/v2/directions/{$orsProfile}/geojson";

        try {
            $headers = ['User-Agent' => self::USER_AGENT];
            if ($apiKey !== '') {
                $headers['Authorization'] = $apiKey;
            }

            $response = Http::acceptJson()
                ->withHeaders($headers)
                ->timeout(8)
                ->post($endpoint, [
                    'coordinates' => [
                        [$oLng, $oLat],
                        [$dLng, $dLat],
                    ],
                ]);

            if ($response->status() === 404 || $response->status() === 400) {
                return ['status' => 'NO_ROUTE'];
            }
            if (!$response->successful()) {
                return ['status' => 'UNAVAILABLE'];
            }

            $json = $response->json();
            $feat = $json['features'][0] ?? null;
            $rawCoords = $feat['geometry']['coordinates'] ?? null;
            if (!is_array($rawCoords) || count($rawCoords) < 2) {
                return ['status' => 'NO_ROUTE'];
            }

            $coordinates = [];
            foreach ($rawCoords as $pt) {
                if (is_array($pt) && count($pt) >= 2) {
                    $coordinates[] = [(float) $pt[0], (float) $pt[1]];
                }
            }
            $summary = $feat['properties']['summary'] ?? [];

            return $this->okPayload(
                provider: 'ors',
                profile: $profile,
                distanceMeters: (int) round((float) ($summary['distance'] ?? 0)),
                durationSeconds: (int) round((float) ($summary['duration'] ?? 0)),
                coordinates: $coordinates,
            );
        } catch (\Throwable $ex) {
            Log::warning('MapRoutingService ORS failed', ['error' => $ex->getMessage()]);

            return ['status' => 'UNAVAILABLE'];
        }
    }

    /**
     * Decodes a Google/Valhalla encoded polyline string into GeoJSON [lng, lat] pairs.
     *
     * @return array<int, array{0: float, 1: float}>
     */
    public static function decodePolyline(string $encoded, float $precision = 1e6): array
    {
        $length = strlen($encoded);
        $index = 0;
        $lat = 0;
        $lng = 0;
        $points = [];

        while ($index < $length) {
            $shift = 0;
            $result = 0;
            do {
                if ($index >= $length) {
                    break 2;
                }
                $b = ord($encoded[$index++]) - 63;
                $result |= ($b & 0x1f) << $shift;
                $shift += 5;
            } while ($b >= 0x20);
            $dlat = ($result & 1) ? ~($result >> 1) : ($result >> 1);
            $lat += $dlat;

            $shift = 0;
            $result = 0;
            do {
                if ($index >= $length) {
                    break 2;
                }
                $b = ord($encoded[$index++]) - 63;
                $result |= ($b & 0x1f) << $shift;
                $shift += 5;
            } while ($b >= 0x20);
            $dlng = ($result & 1) ? ~($result >> 1) : ($result >> 1);
            $lng += $dlng;

            $points[] = [
                round($lng / $precision, 6),
                round($lat / $precision, 6),
            ];
        }

        return $points;
    }

    /**
     * @param array<int, array{0: float, 1: float}> $coordinates
     * @return array<string, mixed>
     */
    private function okPayload(
        string $provider,
        string $profile,
        int $distanceMeters,
        int $durationSeconds,
        array $coordinates,
    ): array {
        $minLat = $coordinates[0][1];
        $maxLat = $coordinates[0][1];
        $minLng = $coordinates[0][0];
        $maxLng = $coordinates[0][0];

        foreach ($coordinates as [$lng, $lat]) {
            if ($lat < $minLat) {
                $minLat = $lat;
            }
            if ($lat > $maxLat) {
                $maxLat = $lat;
            }
            if ($lng < $minLng) {
                $minLng = $lng;
            }
            if ($lng > $maxLng) {
                $maxLng = $lng;
            }
        }

        return [
            'status' => 'OK',
            'provider' => $provider,
            'profile' => $profile,
            'cached' => false,
            'distance_meters' => max(0, $distanceMeters),
            'duration_seconds' => max(0, $durationSeconds),
            'geometry' => [
                'type' => 'LineString',
                'coordinates' => $coordinates,
            ],
            'bounds' => [
                'south' => $minLat,
                'west' => $minLng,
                'north' => $maxLat,
                'east' => $maxLng,
            ],
        ];
    }
}
