<?php

namespace App\Services;

use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;

/**
 * Free OpenStreetMap-based geocoding used by web and mobile.
 *
 * The legacy class name is intentionally kept so cPanel deployments can
 * overwrite the old Google-backed file without requiring file deletion.
 */
class GoogleGeocodingService
{
    private const PHOTON_SEARCH = 'https://photon.komoot.io/api/';
    private const PHOTON_REVERSE = 'https://photon.komoot.io/reverse';

    private const NOMINATIM_SEARCH = 'https://nominatim.openstreetmap.org/search';
    private const NOMINATIM_REVERSE = 'https://nominatim.openstreetmap.org/reverse';

    /** @return array<string, mixed> */
    public function search(string $address): array
    {
        $address = trim($address);
        $cacheKey = 'geo:search:' . sha1(mb_strtolower($address));
        $cached = Cache::get($cacheKey);
        if (is_array($cached)) return $cached;

        $response = $this->requestPhoton(self::PHOTON_SEARCH, [
            'q' => $address,
            'lang' => 'tr',
            'limit' => 1,
            'lat' => 39,
            'lon' => 35,
        ]);
        $result = $response === null ? ['status' => 'UNAVAILABLE'] : $this->fromPhoton($response);
        if ($result['status'] !== 'OK') {
            $fallback = $this->requestNominatim(self::NOMINATIM_SEARCH, [
                'q' => $address,
                'format' => 'jsonv2',
                'addressdetails' => 1,
                'countrycodes' => 'tr',
                'limit' => 1,
            ]);
            if ($fallback !== null) $result = $this->fromNominatim($fallback);
        }

        if ($result['status'] === 'OK') Cache::put($cacheKey, $result, now()->addHours(12));
        return $result;
    }

    /** @return array<string, mixed> */
    public function reverse(float $latitude, float $longitude): array
    {
        $cacheKey = 'geo:reverse:' . round($latitude, 5) . ':' . round($longitude, 5);
        $cached = Cache::get($cacheKey);
        if (is_array($cached)) return $cached;

        $response = $this->requestPhoton(self::PHOTON_REVERSE, [
            'lat' => $latitude,
            'lon' => $longitude,
            'lang' => 'tr',
            'limit' => 1,
        ]);
        $result = $response === null ? ['status' => 'UNAVAILABLE'] : $this->fromPhoton($response, [$latitude, $longitude]);
        if ($result['status'] !== 'OK') {
            $fallback = $this->requestNominatim(self::NOMINATIM_REVERSE, [
                'lat' => $latitude,
                'lon' => $longitude,
                'format' => 'jsonv2',
                'addressdetails' => 1,
                'zoom' => 18,
            ]);
            if ($fallback !== null) $result = $this->fromNominatim($fallback, [$latitude, $longitude]);
        }
        if ($result['status'] === 'OK') Cache::put($cacheKey, $result, now()->addHours(12));
        return $result;
    }

    /** @param array<string, mixed> $params */
    private function requestPhoton(string $url, array $params): ?array
    {
        try {
            $response = Http::acceptJson()
                ->withHeaders(['User-Agent' => 'Tarak.app/1.1 (+https://tarak.app)'])
                ->timeout(8)->get($url, $params);
            return $response->successful() && is_array($response->json()) ? $response->json() : null;
        } catch (\Throwable $e) {
            Log::warning('Photon geocoding unavailable', ['message' => $e->getMessage()]);
            return null;
        }
    }

    /**
     * Nominatim is a *rate-limited fallback*, not the primary geocoder.
     * Cache successful lookups, identify the application, and limit fallback calls
     * to at most one per second across workers using an atomic cache add.
     * A dedicated geocoding provider is appropriate for higher-volume traffic.
     * @param array<string, mixed> $params
     */
    private function requestNominatim(string $url, array $params): ?array
    {
        if (!Cache::add('geo:nominatim:request-lock', true, now()->addSeconds(2))) return null;
        try {
            $response = Http::acceptJson()
                ->withHeaders([
                    'User-Agent' => 'TarakApp/1.1 (https://tarak.app; contact via https://tarak.app/iletisim)',
                    'Accept-Language' => 'tr',
                ])
                ->timeout(8)->get($url, $params);
            return $response->successful() && is_array($response->json()) ? $response->json() : null;
        } catch (\Throwable $e) {
            Log::warning('Nominatim geocoding unavailable', ['message' => $e->getMessage()]);
            return null;
        }
    }

    /** @param mixed $payload
     *  @param array{0: float, 1: float}|null $pin
     *  @return array<string, mixed>
     */
    private function fromNominatim(mixed $payload, ?array $pin = null): array
    {
        $place = is_array($payload) && array_is_list($payload) ? ($payload[0] ?? null) : $payload;
        if (!is_array($place) || empty($place['lat']) || empty($place['lon'])) {
            return ['status' => 'ZERO_RESULTS'];
        }
        $address = is_array($place['address'] ?? null) ? $place['address'] : [];
        $district = $this->firstString($address, ['city_district', 'town', 'county', 'municipality', 'city', 'district']);
        $province = $this->firstString($address, ['province', 'state']);
        $neighborhood = $this->firstString($address, ['neighbourhood', 'suburb', 'quarter', 'village']);
        $street = $this->firstString($address, ['road', 'pedestrian', 'residential']);
        $building = $this->firstString($address, ['house_number']);
        return [
            'status' => 'OK',
            'data' => [
                'latitude' => $pin[0] ?? (float) $place['lat'],
                'longitude' => $pin[1] ?? (float) $place['lon'],
                'province' => $province,
                'district' => $district,
                'neighborhood' => $neighborhood,
                'street' => $street,
                'building_no' => $building,
                'formatted_address' => $place['display_name'] ?? null,
                'place_id' => isset($place['osm_id']) ? (string) $place['osm_id'] : null,
            ],
        ];
    }

    /**
     * @param mixed $payload
     * @param array{0: float, 1: float}|null $pin
     * @return array<string, mixed>
     */
    private function fromPhoton(mixed $payload, ?array $pin = null): array
    {
        if (!is_array($payload) || empty($payload['features'][0]) || !is_array($payload['features'][0])) {
            return ['status' => 'ZERO_RESULTS'];
        }

        $feature = $payload['features'][0];
        $properties = is_array($feature['properties'] ?? null) ? $feature['properties'] : [];
        $coordinates = $feature['geometry']['coordinates'] ?? [];

        $longitude = $pin[1] ?? ($coordinates[0] ?? null);
        $latitude = $pin[0] ?? ($coordinates[1] ?? null);

        if (!is_numeric($latitude) || !is_numeric($longitude)) {
            return ['status' => 'UNAVAILABLE'];
        }

        $street = $this->firstString($properties, ['street', 'name']);
        $buildingNo = $this->firstString($properties, ['housenumber']);
        // Photon `city` may be İstanbul while `county` is Şişli.
        // Keep province/city separate from the actual district.
        $neighborhood = $this->firstString($properties, ['suburb', 'locality', 'neighbourhood']);
        $district = $this->firstString($properties, ['county', 'district', 'city']);
        $province = $this->firstString($properties, ['state']);

        $parts = array_values(array_filter([
            $street ? trim($street . ($buildingNo ? ' ' . $buildingNo : '')) : null,
            $neighborhood,
            $district,
            $province,
            $this->firstString($properties, ['country']),
        ], fn ($value) => is_string($value) && trim($value) !== ''));

        return [
            'status' => 'OK',
            'data' => [
                'latitude' => (float) $latitude,
                'longitude' => (float) $longitude,
                'province' => $province,
                'district' => $district,
                'neighborhood' => $neighborhood,
                'street' => $street,
                'building_no' => $buildingNo,
                'formatted_address' => $parts ? implode(', ', array_unique($parts)) : null,
                'place_id' => $properties['osm_id'] ?? null,
            ],
        ];
    }

    /** @param array<string, mixed> $source
     *  @param array<int, string> $keys
     */
    private function firstString(array $source, array $keys): ?string
    {
        foreach ($keys as $key) {
            $value = $source[$key] ?? null;
            if (is_string($value) && trim($value) !== '') {
                return trim($value);
            }
        }

        return null;
    }
}
