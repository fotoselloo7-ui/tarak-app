<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Http\Client\ConnectionException;

/** Server-side geocoding so the billable Google API key never reaches web or mobile clients. */
class GoogleGeocodingService
{
    private const ENDPOINT = 'https://maps.googleapis.com/maps/api/geocode/json';

    /** @return array<string, mixed> */
    public function search(string $address): array
    {
        return $this->lookup(['address' => $address, 'region' => 'tr'], null);
    }

    /** @return array<string, mixed> */
    public function reverse(float $latitude, float $longitude): array
    {
        return $this->lookup(['latlng' => $latitude . ',' . $longitude], [$latitude, $longitude]);
    }

    /** @param array<string, string> $parameters
     *  @param array{0: float, 1: float}|null $pin
     *  @return array<string, mixed>
     */
    private function lookup(array $parameters, ?array $pin): array
    {
        $key = trim((string) config('services.google_maps.server_key'));
        if ($key === '') {
            return ['status' => 'NOT_CONFIGURED'];
        }

        try {
            $response = Http::acceptJson()
                // The production Maps server key is restricted to the hosting
                // server's IPv4 egress address. Force IPv4 so PHP/Guzzle does
                // not occasionally reach Google over an unlisted IPv6 address.
                ->withOptions(['force_ip_resolve' => 'v4'])
                ->timeout(8)
                ->get(self::ENDPOINT, $parameters + [
                    'language' => 'tr',
                    'key' => $key,
                ]);
        } catch (ConnectionException $e) {
            Log::warning('Google Geocoding connection failed', [
                'message' => $e->getMessage(),
            ]);
            return ['status' => 'UNAVAILABLE'];
        }

        if (!$response->successful()) {
            Log::warning('Google Geocoding HTTP request failed', [
                'http_status' => $response->status(),
            ]);
            return ['status' => 'UNAVAILABLE'];
        }

        $payload = $response->json();
        if (!is_array($payload)) {
            return ['status' => 'UNAVAILABLE'];
        }
        $status = $payload['status'] ?? 'UNKNOWN_ERROR';
        if ($status === 'ZERO_RESULTS') {
            return ['status' => 'ZERO_RESULTS'];
        }
        if ($status !== 'OK' || empty($payload['results'][0]) || !is_array($payload['results'][0])) {
            // Keep the API key private, but record Google's status/message so
            // production configuration problems are diagnosable from Laravel.
            Log::warning('Google Geocoding API rejected request', [
                'google_status' => $status,
                'error_message' => isset($payload['error_message'])
                    ? mb_substr((string) $payload['error_message'], 0, 500)
                    : null,
            ]);
            // Denied/over-quota errors must not be cached; an admin can correct settings immediately.
            return ['status' => 'UNAVAILABLE'];
        }

        $first = $payload['results'][0];
        $location = $first['geometry']['location'] ?? [];
        $latitude = $pin[0] ?? ($location['lat'] ?? null);
        $longitude = $pin[1] ?? ($location['lng'] ?? null);
        if (!is_numeric($latitude) || !is_numeric($longitude)) {
            return ['status' => 'UNAVAILABLE'];
        }

        $result = [
            'status' => 'OK',
            'data' => [
                'latitude' => (float) $latitude,
                'longitude' => (float) $longitude,
                'province' => $this->component($payload['results'], ['administrative_area_level_1']),
                'district' => $this->component($payload['results'], ['administrative_area_level_2', 'administrative_area_level_3']),
                'neighborhood' => $this->component($payload['results'], ['neighborhood', 'sublocality_level_1', 'sublocality']),
                'street' => $this->component($payload['results'], ['route']),
                'building_no' => $this->component($payload['results'], ['street_number']),
                'formatted_address' => $first['formatted_address'] ?? null,
                'place_id' => $first['place_id'] ?? null,
            ],
        ];
        // Do not persist Google's full response as a reusable address cache.
        // Request pacing is handled by client debounce and API throttling.
        return $result;
    }

    /** @param array<int, array<string, mixed>> $results
     *  @param array<int, string> $types
     */
    private function component(array $results, array $types): ?string
    {
        foreach ($types as $type) {
            foreach ($results as $result) {
                foreach ($result['address_components'] ?? [] as $component) {
                    if (in_array($type, $component['types'] ?? [], true)) {
                        return (string) ($component['long_name'] ?? '');
                    }
                }
            }
        }

        return null;
    }
}
