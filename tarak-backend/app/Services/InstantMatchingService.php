<?php

namespace App\Services;

use App\Models\ProviderProfile;
use App\Models\ServiceRequest;
use App\Models\User;
use Illuminate\Support\Collection;

class InstantMatchingService
{
    /**
     * Check if a specific provider is eligible for a service request.
     *
     * @return array{eligible: bool, reason: ?string, distance_km: ?float, is_approximate_match: bool}
     */
    public function isProviderEligibleForRequest(User $providerUser, ServiceRequest $request): array
    {
        // 1. Role must be PROVIDER
        if ($providerUser->role !== User::ROLE_PROVIDER) {
            return [
                'eligible' => false,
                'reason' => 'Kullanıcı hizmet veren rolünde değil.',
                'distance_km' => null,
                'is_approximate_match' => false,
            ];
        }

        // 2. Profile must exist
        $profile = $providerUser->providerProfile;
        if (!$profile) {
            return [
                'eligible' => false,
                'reason' => 'Hizmet veren profili bulunamadı.',
                'distance_km' => null,
                'is_approximate_match' => false,
            ];
        }

        // 3. Approval status
        if (!$profile->is_approved || $profile->identity_status !== 'APPROVED') {
            return [
                'eligible' => false,
                'reason' => 'Hizmet veren mesleki belgeleri henüz onaylanmamış.',
                'distance_km' => null,
                'is_approximate_match' => false,
            ];
        }

        // 4. Genuine verified check (At least 1 approved vocational document)
        if (!$profile->hasApprovedDocument()) {
            return [
                'eligible' => false,
                'reason' => 'Hizmet verenin onaylı mesleki belgesi bulunmuyor.',
                'distance_km' => null,
                'is_approximate_match' => false,
            ];
        }

        // 5. Must be online
        if (!$profile->is_online) {
            return [
                'eligible' => false,
                'reason' => 'Hizmet veren şu anda çevrimdışı.',
                'distance_km' => null,
                'is_approximate_match' => false,
            ];
        }

        // 6. Accepts new clients
        if (!$profile->accepts_new_clients) {
            return [
                'eligible' => false,
                'reason' => 'Hizmet veren yeni müşteri kabul etmiyor.',
                'distance_km' => null,
                'is_approximate_match' => false,
            ];
        }

        // 7. Request must be in OPEN status
        if ($request->status !== ServiceRequest::STATUS_OPEN) {
            return [
                'eligible' => false,
                'reason' => 'Hizmet talebi açık değil.',
                'distance_km' => null,
                'is_approximate_match' => false,
            ];
        }

        // 7b. Direct requests are only visible/eligible for the targeted provider.
        $isDirect = $request->target_provider_user_id !== null;
        if ($isDirect && (int) $request->target_provider_user_id !== (int) $providerUser->id) {
            return [
                'eligible' => false,
                'reason' => 'Bu talep başka bir hizmet verene yönelik.',
                'distance_km' => null,
                'is_approximate_match' => false,
            ];
        }

        // 8. Category & Provider Type Compatibility (direct requests carry the provider's own offering)
        if ($request->category_id && !$isDirect) {
            $catId = $request->category_id;
            if ($catId === 'cat-1' && $profile->provider_type !== 'barber') {
                return [
                    'eligible' => false,
                    'reason' => 'Erkek bakım hizmetini yalnızca erkek berberleri verebilir.',
                    'distance_km' => null,
                    'is_approximate_match' => false,
                ];
            }
            if ($catId === 'cat-2' && $profile->provider_type !== 'coiffeur') {
                return [
                    'eligible' => false,
                    'reason' => 'Kadın kuaför hizmetini yalnızca kadın kuaförleri verebilir.',
                    'distance_km' => null,
                    'is_approximate_match' => false,
                ];
            }
        }

        // 9. Service capability: Provider must offer at least one of the requested services actively
        $requestedServiceIds = $isDirect ? [] : $request->services()->pluck('services.id')->toArray();
        if (!empty($requestedServiceIds)) {
            $offeredServiceIds = $profile->services()
                ->wherePivot('is_active', true)
                ->pluck('services.id')
                ->toArray();

            $matchingServices = array_intersect($requestedServiceIds, $offeredServiceIds);
            if (empty($matchingServices)) {
                return [
                    'eligible' => false,
                    'reason' => 'Hizmet veren talep edilen hizmetleri sunmuyor.',
                    'distance_km' => null,
                    'is_approximate_match' => false,
                ];
            }
        }

        // 10. BUSY check: Active ASSIGNED or IN_PROGRESS instant requests
        $isBusy = ServiceRequest::where('assigned_provider_user_id', $providerUser->id)
            ->whereIn('status', [ServiceRequest::STATUS_ASSIGNED, 'IN_PROGRESS'])
            ->exists();

        if ($isBusy) {
            return [
                'eligible' => false,
                'reason' => 'Hizmet veren şu anda aktif bir işte görevli (BUSY).',
                'distance_km' => null,
                'is_approximate_match' => false,
            ];
        }

        // 11. Location & Radius check
        $hasReqCoords = $request->private_latitude !== null && $request->private_longitude !== null;
        $hasProvCoords = $profile->latitude !== null && $profile->longitude !== null;

        if ($hasReqCoords && $hasProvCoords) {
            $distance = $this->haversineDistanceKm(
                (float) $request->private_latitude,
                (float) $request->private_longitude,
                (float) $profile->latitude,
                (float) $profile->longitude
            );
            $radius = $profile->service_radius_km ?: 15;

            if ($distance > $radius) {
                return [
                    'eligible' => false,
                    'reason' => "Mesafe ({$distance} km) hizmet verenin servis yarıçapından ({$radius} km) fazla.",
                    'distance_km' => $distance,
                    'is_approximate_match' => false,
                ];
            }

            return [
                'eligible' => true,
                'reason' => null,
                'distance_km' => round($distance, 1),
                'is_approximate_match' => false,
            ];
        }

        // Approximate Regional Match (No coordinates: DO NOT fabricate distance or fake ETA!)
        $reqProv = mb_strtolower(trim($request->approx_province ?? ''));
        $pCity = mb_strtolower(trim($profile->city ?? ''));

        if ($reqProv !== '' && $pCity !== '' && !str_contains($reqProv, $pCity) && !str_contains($pCity, $reqProv)) {
            return [
                'eligible' => false,
                'reason' => 'Hizmet veren ili ile talep ili uyuşmuyor.',
                'distance_km' => null,
                'is_approximate_match' => false,
            ];
        }

        return [
            'eligible' => true,
            'reason' => null,
            'distance_km' => null,
            'is_approximate_match' => true,
        ];
    }

    /**
     * Compute Haversine distance in kilometers between two coordinates.
     */
    public function haversineDistanceKm(float $lat1, float $lon1, float $lat2, float $lon2): float
    {
        $earthRadius = 6371.0; // Earth radius in kilometers
        $dLat = deg2rad($lat2 - $lat1);
        $dLon = deg2rad($lon2 - $lon1);

        $a = sin($dLat / 2) * sin($dLat / 2) +
             cos(deg2rad($lat1)) * cos(deg2rad($lat2)) *
             sin($dLon / 2) * sin($dLon / 2);

        $c = 2 * atan2(sqrt($a), sqrt(1 - $a));
        return round($earthRadius * $c, 2);
    }

    /**
     * Find all eligible OPEN instant requests for a given provider.
     */
    public function getEligibleRequestsForProvider(User $providerUser): Collection
    {
        $profile = $providerUser->providerProfile;
        if (!$profile || !$profile->is_approved || $profile->identity_status !== 'APPROVED' || !$profile->is_online) {
            return collect();
        }

        // Query open instant requests
        $query = ServiceRequest::with(['services', 'category', 'customer'])
            ->where('mode', ServiceRequest::MODE_INSTANT)
            ->where('status', ServiceRequest::STATUS_OPEN)
            ->whereNull('assigned_provider_user_id')
            ->where(function ($q) use ($providerUser) {
                $q->whereNull('target_provider_user_id')
                    ->orWhere('target_provider_user_id', $providerUser->id);
            })
            ->orderBy('created_at', 'desc');

        // Filter by category where compatible (direct requests to this provider always pass)
        $allowedCategory = match ($profile->provider_type) {
            'barber' => 'cat-1',
            'coiffeur' => 'cat-2',
            default => null,
        };
        if ($allowedCategory) {
            $query->where(function ($q) use ($allowedCategory, $providerUser) {
                $q->whereNull('category_id')
                    ->orWhere('category_id', $allowedCategory)
                    ->orWhere('target_provider_user_id', $providerUser->id);
            });
        }

        $allOpenRequests = $query->get();

        $eligibleRequests = collect();
        foreach ($allOpenRequests as $request) {
            $check = $this->isProviderEligibleForRequest($providerUser, $request);
            if ($check['eligible']) {
                // Dynamically attach matching metadata for response presentation
                $request->distance_km = $check['distance_km'];
                $request->is_approximate_match = $check['is_approximate_match'];
                $eligibleRequests->push($request);
            }
        }

        return $eligibleRequests;
    }
}
