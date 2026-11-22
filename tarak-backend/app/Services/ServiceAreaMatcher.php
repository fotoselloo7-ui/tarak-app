<?php

namespace App\Services;

use App\Models\ProviderProfile;
use App\Models\ProviderServiceArea;
use App\Support\Geo;

/**
 * Evaluates whether a provider serves a customer location either by the existing
 * coordinate radius (`service_radius_km`) or by explicit district/neighborhood
 * selections (`provider_service_areas`).
 */
class ServiceAreaMatcher
{
    public function matchesExplicitArea(
        ProviderProfile $profile,
        ?string $province,
        ?string $district,
        ?string $neighborhood = null,
    ): bool {
        $normProvince = ProviderServiceArea::normalizePart($province);
        $normDistrict = ProviderServiceArea::normalizePart($district);
        if ($normProvince === '' || $normDistrict === '') {
            return false;
        }

        $normNeighborhood = ProviderServiceArea::normalizePart($neighborhood);
        $wildKey = "{$normProvince}|{$normDistrict}|*";
        $exactKey = $normNeighborhood !== '' ? "{$normProvince}|{$normDistrict}|{$normNeighborhood}" : null;

        $keysToCheck = $exactKey !== null ? [$exactKey, $wildKey] : [$wildKey];

        if ($profile->relationLoaded('serviceAreas')) {
            return $profile->serviceAreas->contains(fn (ProviderServiceArea $area) => in_array($area->normalized_key, $keysToCheck, true));
        }

        return $profile->serviceAreas()->whereIn('normalized_key', $keysToCheck)->exists();
    }

    /**
     * @return array{covered: bool, distance_km: ?float, matched_by: ?string}
     */
    public function coversLocation(
        ProviderProfile $profile,
        ?float $lat,
        ?float $lng,
        ?string $province = null,
        ?string $district = null,
        ?string $neighborhood = null,
    ): array {
        $distance = null;
        if ($lat !== null && $lng !== null && $profile->latitude !== null && $profile->longitude !== null) {
            $distance = Geo::distanceKm($lat, $lng, $profile->latitude, $profile->longitude);
            $radius = (float) ($profile->service_radius_km ?: 15);
            if ($distance !== null && $distance <= $radius) {
                return [
                    'covered' => true,
                    'distance_km' => $distance,
                    'matched_by' => 'radius',
                ];
            }
        }

        if ($this->matchesExplicitArea($profile, $province, $district, $neighborhood)) {
            return [
                'covered' => true,
                'distance_km' => $distance,
                'matched_by' => 'service_area',
            ];
        }

        return [
            'covered' => false,
            'distance_km' => $distance,
            'matched_by' => null,
        ];
    }
}
