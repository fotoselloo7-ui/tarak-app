<?php

namespace App\Services;

use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;
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

    /** @return array<string, mixed> */
    public function search(string $address): array
    {
        try {
            $response = Http::acceptJson()
                ->withHeaders(['User-Agent' => 'Tarak.app/1.1 (+https://tarak.app)'])
                ->timeout(8)
                ->get(self::PHOTON_SEARCH, [
                    'q' => $address,
                    'lang' => 'tr',
                    'limit' => 1,
                ]);
        } catch (ConnectionException $e) {
            Log::warning('Photon geocoding connection failed', ['message' => $e->getMessage()]);
            return ['status' => 'UNAVAILABLE'];
        }

        if (!$response->successful()) {
            Log::warning('Photon geocoding HTTP request failed', ['http_status' => $response->status()]);
            return ['status' => 'UNAVAILABLE'];
        }

        return $this->fromPhoton($response->json());
    }

    /** @return array<string, mixed> */
    public function reverse(float $latitude, float $longitude): array
    {
        try {
            $response = Http::acceptJson()
                ->withHeaders(['User-Agent' => 'Tarak.app/1.1 (+https://tarak.app)'])
                ->timeout(8)
                ->get(self::PHOTON_REVERSE, [
                    'lat' => $latitude,
                    'lon' => $longitude,
                    'lang' => 'tr',
                    'limit' => 1,
                ]);
        } catch (ConnectionException $e) {
            Log::warning('Photon reverse geocoding connection failed', ['message' => $e->getMessage()]);
            return ['status' => 'UNAVAILABLE'];
        }

        if (!$response->successful()) {
            Log::warning('Photon reverse geocoding HTTP request failed', ['http_status' => $response->status()]);
            return ['status' => 'UNAVAILABLE'];
        }

        return $this->fromPhoton($response->json(), [$latitude, $longitude]);
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
        $neighborhood = $this->firstString($properties, ['district', 'suburb', 'locality']);
        $district = $this->firstString($properties, ['city', 'county', 'district']);
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
