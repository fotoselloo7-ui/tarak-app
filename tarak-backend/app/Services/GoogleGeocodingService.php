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
        $cacheKey = 'geo:search:v2:' . sha1(mb_strtolower($address));
        $cached = Cache::get($cacheKey);
        if (is_array($cached)) return $cached;

        $response = $this->requestPhoton(self::PHOTON_SEARCH, [
            'q' => $address,
            'limit' => 5,
            'lat' => 39,
            'lon' => 35,
        ]);
        $result = $response === null ? ['status' => 'UNAVAILABLE'] : $this->fromPhoton($response, null, $address);
        if ($result['status'] !== 'OK') {
            $fallback = $this->requestNominatim(self::NOMINATIM_SEARCH, [
                'q' => $address,
                'format' => 'jsonv2',
                'addressdetails' => 1,
                'countrycodes' => 'tr',
                'limit' => 5,
            ]);
            if ($fallback !== null) $result = $this->fromNominatim($fallback, null, $address);
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
                ->timeout(3)->get($url, $params);
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
        if (!Cache::add('geo:nominatim:request-lock', true, now()->addSeconds(1))) return null;
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
    private function fromNominatim(mixed $payload, ?array $pin = null, ?string $query = null): array
    {
        $place = is_array($payload) && array_is_list($payload)
            ? $this->pickBestNominatimPlace($payload, $query)
            : $payload;
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
    private function fromPhoton(mixed $payload, ?array $pin = null, ?string $query = null): array
    {
        $features = is_array($payload['features'] ?? null) ? $payload['features'] : [];
        $feature = $this->pickBestPhotonFeature($features, $query);
        if (!is_array($feature)) {
            return ['status' => 'ZERO_RESULTS'];
        }

        $properties = is_array($feature['properties'] ?? null) ? $feature['properties'] : [];
        $coordinates = $feature['geometry']['coordinates'] ?? [];

        $longitude = $pin[1] ?? ($coordinates[0] ?? null);
        $latitude = $pin[0] ?? ($coordinates[1] ?? null);

        if (!is_numeric($latitude) || !is_numeric($longitude)) {
            return ['status' => 'UNAVAILABLE'];
        }

        $isAdminPlace = in_array($properties['type'] ?? null, ['city', 'district', 'county', 'state', 'country'], true);
        $street = $isAdminPlace
            ? $this->firstString($properties, ['street'])
            : $this->firstString($properties, ['street', 'name']);
        $buildingNo = $this->firstString($properties, ['housenumber']);
        // Photon `city` may be İstanbul while `county` is Şişli.
        // Keep province/city separate from the actual district.
        $neighborhood = $this->firstString($properties, ['suburb', 'locality', 'neighbourhood']);
        $district = $this->firstString($properties, ['county', 'district', 'city']);
        $province = $this->firstString($properties, ['state']);
        $featureName = $this->firstString($properties, ['name']);
        if (
            $district === null
            && in_array($properties['type'] ?? null, ['city', 'district', 'county', 'locality'], true)
            && $featureName !== null
            && ($province === null || $this->normalizeGeoToken($featureName) !== $this->normalizeGeoToken($province))
        ) {
            $district = $featureName;
        }

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

    /**
     * @param array<int, mixed> $features
     * @return array<string, mixed>|null
     */
    private function pickBestPhotonFeature(array $features, ?string $query): ?array
    {
        $parts = $this->parseQueryParts($query);
        if ($parts === []) {
            return is_array($features[0] ?? null) ? $features[0] : null;
        }

        $primary = $parts[0];
        $secondary = $parts[1] ?? null;
        $best = null;
        $bestWeighted = PHP_INT_MIN;

        foreach (array_values($features) as $idx => $feature) {
            if (!is_array($feature)) continue;
            $props = is_array($feature['properties'] ?? null) ? $feature['properties'] : [];
            $score = 0;

            if (strtolower((string) ($props['countrycode'] ?? '')) === 'tr') {
                $score += 15;
            }

            $name = $this->normalizeGeoToken($this->firstString($props, ['name']));
            $county = $this->normalizeGeoToken($this->firstString($props, ['county']));
            $districtProp = $this->normalizeGeoToken($this->firstString($props, ['district']));
            $city = $this->normalizeGeoToken($this->firstString($props, ['city']));
            $suburb = $this->normalizeGeoToken($this->firstString($props, ['suburb']));
            $locality = $this->normalizeGeoToken($this->firstString($props, ['locality']));
            $state = $this->normalizeGeoToken($this->firstString($props, ['state']));

            if ($name === $primary) {
                $score += 100;
            } elseif (in_array($primary, [$county, $districtProp, $city, $suburb, $locality], true)) {
                $score += 45;
            } elseif ($name !== '' && str_contains($name, $primary)) {
                $score += 15;
            }

            if ($secondary !== null && $secondary !== '') {
                if ($state === $secondary || $city === $secondary) {
                    $score += 40;
                } elseif ($state !== '' && str_contains($state, $secondary)) {
                    $score += 15;
                }
            }

            $osmKey = (string) ($props['osm_key'] ?? '');
            $osmValue = (string) ($props['osm_value'] ?? '');
            $type = (string) ($props['type'] ?? '');
            if (
                in_array($osmKey, ['place', 'boundary'], true)
                || in_array($osmValue, ['town', 'city', 'district', 'county', 'suburb', 'municipality', 'administrative', 'village', 'quarter', 'neighbourhood'], true)
                || in_array($type, ['city', 'district', 'county', 'locality'], true)
            ) {
                $score += 35;
            }
            if (in_array($osmKey, ['amenity', 'highway', 'railway', 'tourism', 'aeroway', 'shop', 'leisure', 'building'], true)) {
                $score -= 25;
            }

            $weighted = $score * 100 - $idx;
            if ($weighted > $bestWeighted) {
                $bestWeighted = $weighted;
                $best = $feature;
            }
        }

        return $best ?? (is_array($features[0] ?? null) ? $features[0] : null);
    }

    /**
     * @param array<int, mixed> $places
     * @return array<string, mixed>|null
     */
    private function pickBestNominatimPlace(array $places, ?string $query): ?array
    {
        $parts = $this->parseQueryParts($query);
        if ($parts === []) {
            return is_array($places[0] ?? null) ? $places[0] : null;
        }

        $primary = $parts[0];
        $secondary = $parts[1] ?? null;
        $best = null;
        $bestWeighted = PHP_INT_MIN;

        foreach (array_values($places) as $idx => $place) {
            if (!is_array($place)) continue;
            $address = is_array($place['address'] ?? null) ? $place['address'] : [];
            $score = 0;

            if (strtolower((string) ($address['country_code'] ?? '')) === 'tr') {
                $score += 15;
            }

            $name = $this->normalizeGeoToken(isset($place['name']) && is_string($place['name']) ? $place['name'] : null);
            $town = $this->normalizeGeoToken($this->firstString($address, ['town']));
            $cityDistrict = $this->normalizeGeoToken($this->firstString($address, ['city_district']));
            $county = $this->normalizeGeoToken($this->firstString($address, ['county']));
            $municipality = $this->normalizeGeoToken($this->firstString($address, ['municipality']));
            $suburb = $this->normalizeGeoToken($this->firstString($address, ['suburb']));
            $city = $this->normalizeGeoToken($this->firstString($address, ['city']));
            $province = $this->normalizeGeoToken($this->firstString($address, ['province']));
            $state = $this->normalizeGeoToken($this->firstString($address, ['state']));

            if ($name === $primary) {
                $score += 100;
            } elseif (in_array($primary, [$town, $cityDistrict, $county, $municipality, $suburb, $city], true)) {
                $score += 45;
            } elseif ($name !== '' && str_contains($name, $primary)) {
                $score += 15;
            }

            if ($secondary !== null && $secondary !== '') {
                if ($province === $secondary || $state === $secondary) {
                    $score += 40;
                } elseif (($province !== '' && str_contains($province, $secondary)) || ($state !== '' && str_contains($state, $secondary))) {
                    $score += 15;
                }
            }

            $category = (string) ($place['category'] ?? '');
            $type = (string) ($place['type'] ?? '');
            $addressType = (string) ($place['addresstype'] ?? '');
            if (
                in_array($category, ['place', 'boundary'], true)
                || in_array($addressType, ['town', 'city', 'district', 'county', 'suburb', 'municipality', 'village', 'quarter', 'neighbourhood'], true)
                || in_array($type, ['administrative', 'town', 'city', 'district', 'county', 'suburb', 'village'], true)
            ) {
                $score += 35;
            }
            if (in_array($category, ['amenity', 'highway', 'railway', 'tourism', 'aeroway', 'shop', 'leisure', 'building'], true)) {
                $score -= 25;
            }

            $weighted = $score * 100 - $idx;
            if ($weighted > $bestWeighted) {
                $bestWeighted = $weighted;
                $best = $place;
            }
        }

        return $best ?? (is_array($places[0] ?? null) ? $places[0] : null);
    }

    /** @return array<int, string> */
    private function parseQueryParts(?string $query): array
    {
        if ($query === null || trim($query) === '') {
            return [];
        }

        $rawParts = array_values(array_filter(array_map(
            fn (string $part): string => $this->normalizeGeoToken($part),
            explode(',', $query)
        ), fn (string $part): bool => $part !== ''));

        while ($rawParts !== [] && in_array(end($rawParts), ['turkiye', 'turkey'], true)) {
            array_pop($rawParts);
        }

        return $rawParts;
    }

    private function normalizeGeoToken(?string $value): string
    {
        if ($value === null) {
            return '';
        }

        $folded = strtr(trim($value), [
            'İ' => 'i', 'I' => 'i', 'ı' => 'i',
            'Ş' => 's', 'ş' => 's',
            'Ğ' => 'g', 'ğ' => 'g',
            'Ü' => 'u', 'ü' => 'u',
            'Ö' => 'o', 'ö' => 'o',
            'Ç' => 'c', 'ç' => 'c',
            'Â' => 'a', 'â' => 'a',
            'Î' => 'i', 'î' => 'i',
            'Û' => 'u', 'û' => 'u',
        ]);

        $folded = mb_strtolower($folded, 'UTF-8');
        return trim((string) preg_replace('/\s+/u', ' ', $folded));
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
