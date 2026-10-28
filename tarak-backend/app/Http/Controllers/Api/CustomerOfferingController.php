<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\CustomerAddress;
use App\Models\ProviderProfile;
use App\Models\ProviderService;
use App\Models\Service;
use App\Services\ListingAdService;
use App\Services\ProviderDiscountService;
use App\Services\ProviderOfferingService;
use App\Support\Geo;
use App\Support\ProviderListFilters;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CustomerOfferingController extends Controller
{
    public function __construct(protected ProviderOfferingService $offerings, protected ListingAdService $listingAds, protected ProviderDiscountService $discounts) {}

    /**
     * Providers actively offering a catalog service, with their own price/duration and live call availability.
     */
    public function providersForService(Request $request, int $serviceId): JsonResponse
    {
        $service = Service::where('is_active', true)->find($serviceId);
        if (!$service) {
            return response()->json(['success' => false, 'message' => 'Hizmet bulunamadı.'], 404);
        }

        $location = $this->customerLocation($request);
        if ($location instanceof JsonResponse) {
            return $location;
        }

        // Search / stars / distance / sort + the sponsored "Liste Reklamı" slots (see ListingAdService).
        // The customer's position is the saved address (customer_address_id) or an explicit lat / lng.
        $origin = Geo::origin($request) ?? ($location['lat'] !== null && $location['lng'] !== null ? [$location['lat'], $location['lng']] : null);
        $filters = ProviderListFilters::fromRequest($request, null, [$service->id], $origin);

        $sponsoredProfiles = $this->listingAds->sponsored($filters);

        $build = function (ProviderService $ps, bool $isSponsored = false) use ($location, $origin) {
            $offer = $this->offerings->presentService($ps, $this->discounts->percentFor((int) $ps->providerProfile->user_id));
            $availability = $this->offerings->instantAvailability(
                $ps->providerProfile,
                $offer['duration_minutes'],
                $location['lat'],
                $location['lng'],
                $location['province']
            );
            $provider = $this->offerings->presentProvider($ps->providerProfile);
            $provider['distance_km'] = $origin ? Geo::distanceKm($origin[0], $origin[1], $ps->providerProfile->latitude, $ps->providerProfile->longitude) : null;
            if ($isSponsored) {
                $provider['is_sponsored'] = true;
                $provider['sponsored_label'] = ListingAdService::LABEL;
            }

            return ['provider' => $provider, 'offering' => $offer, 'availability' => $availability];
        };

        $sponsoredRows = $sponsoredProfiles->map(function ($profile) use ($service, $build) {
            $ps = ProviderService::with(['service', 'providerProfile.user', 'providerProfile.documents'])
                ->where('provider_profile_id', $profile->id)->where('service_id', $service->id)->where('is_active', true)->first();

            return $ps ? $build($ps, true) : null;
        })->filter()->values();

        if ($request->boolean('sponsored_only')) {
            // Just the rotating cards: the clients ask again every `rotation_seconds`.
            return response()->json([
                'success' => true,
                'data' => ['sponsored' => $sponsoredRows, 'meta' => ['has_origin' => $origin !== null] + $this->listingAds->meta()],
            ]);
        }

        $offerings = ProviderService::with(['service', 'providerProfile.user', 'providerProfile.documents'])
            ->where('service_id', $service->id)
            ->where('is_active', true)
            ->whereHas('providerProfile', fn ($q) => $q->where('is_approved', true)->where('identity_status', 'APPROVED'))
            ->get()
            ->filter(fn ($ps) => $ps->providerProfile?->isVerified());

        $data = $offerings
            ->map(fn (ProviderService $ps) => $build($ps))
            ->when($filters['term'] !== null, function ($rows) use ($filters) {
                $needle = mb_strtolower($filters['term']);

                return $rows->filter(fn ($r) => str_contains(mb_strtolower(implode(' ', array_filter([$r['provider']['business_name'], $r['provider']['name'], $r['provider']['city'], $r['provider']['district']]))), $needle));
            })
            ->when($filters['min_rating'] > 0, fn ($rows) => $rows->filter(fn ($r) => (float) ($r['provider']['rating'] ?? 0) >= $filters['min_rating']))
            ->when($origin && $filters['max_distance_km'], fn ($rows) => $rows->filter(fn ($r) => $r['provider']['distance_km'] !== null && $r['provider']['distance_km'] <= $filters['max_distance_km']));

        $sort = $filters['sort'] === 'distance' && !$origin ? 'relevance' : $filters['sort'];
        $data = match ($sort) {
            'rating' => $data->sortByDesc(fn ($r) => [(float) ($r['provider']['rating'] ?? 0), (int) $r['provider']['review_count']]),
            'reviews' => $data->sortByDesc(fn ($r) => (int) $r['provider']['review_count']),
            'distance' => $data->sortBy(fn ($r) => $r['provider']['distance_km'] ?? PHP_FLOAT_MAX),
            'price' => $data->sortBy(fn ($r) => $r['offering']['price']),
            // relevance: available right now first, then cheapest (the order this endpoint always had)
            default => $data->sortBy([
                fn ($a, $b) => (int) $b['availability']['available'] <=> (int) $a['availability']['available'],
                fn ($a, $b) => $a['offering']['price'] <=> $b['offering']['price'],
            ]),
        };

        return response()->json([
            'success' => true,
            'data' => [
                'service' => [
                    'id' => $service->id,
                    'name' => $service->name,
                    'category_id' => $service->category_id,
                ],
                'providers' => $data->values(),
                'sponsored' => $sponsoredRows,
                'meta' => ['has_origin' => $origin !== null] + $this->listingAds->meta(),
            ],
        ]);
    }

    /**
     * A provider's active services and packages, each with a price, duration and call availability.
     */
    public function providerOfferings(Request $request, int $providerUserId): JsonResponse
    {
        $profile = ProviderProfile::with(['user', 'documents'])->where('user_id', $providerUserId)->first();
        $demoPreview = $profile && $profile->user?->is_demo && $profile->is_approved && $profile->user->status === 'active';
        if (!$profile || (!$profile->isVerified() && !$demoPreview)) {
            return response()->json(['success' => false, 'message' => 'Hizmet veren bulunamadı.'], 404);
        }

        $location = $this->customerLocation($request);
        if ($location instanceof JsonResponse) {
            return $location;
        }

        $availabilityFor = fn (int $duration) => $demoPreview
            ? ['available' => false, 'reason' => 'Bu bir demo profildir; gerçek hizmet talebi oluşturulamaz.', 'distance_km' => null]
            : $this->offerings->instantAvailability(
            $profile,
            $duration,
            $location['lat'],
            $location['lng'],
            $location['province']
        );

        $discountPercent = $this->discounts->percentFor((int) $profile->user_id);

        $services = $profile->providerServices()
            ->with('service')
            ->where('is_active', true)
            ->whereHas('service', fn ($q) => $q->where('is_active', true))
            ->get()
            ->map(function (ProviderService $ps) use ($availabilityFor, $discountPercent) {
                $item = $this->offerings->presentService($ps, $discountPercent);
                $item['availability'] = $availabilityFor($item['duration_minutes']);
                return $item;
            })
            ->values();

        $packages = $profile->packages()
            ->with('services')
            ->where('is_active', true)
            ->get()
            ->filter(fn ($p) => $p->services->isNotEmpty() && $p->services->every(fn ($s) => $s->is_active))
            ->map(function ($p) use ($availabilityFor, $discountPercent) {
                $item = $this->offerings->presentPackage($p, $discountPercent);
                $item['availability'] = $availabilityFor($item['duration_minutes']);
                return $item;
            })
            ->values();

        return response()->json([
            'success' => true,
            'data' => [
                'provider' => $this->offerings->presentProvider($profile),
                'preview_only' => (bool) $demoPreview,
                'services' => $services,
                'packages' => $packages,
            ],
        ]);
    }

    /**
     * @return array{lat: ?float, lng: ?float, province: ?string}|JsonResponse
     */
    private function customerLocation(Request $request): array|JsonResponse
    {
        $addressId = $request->query('customer_address_id');
        if (!$addressId) {
            return ['lat' => null, 'lng' => null, 'province' => null];
        }

        $address = CustomerAddress::where('id', $addressId)
            ->where('customer_profile_id', $request->user()->customerProfile?->id)
            ->first();

        if (!$address) {
            return response()->json(['success' => false, 'message' => 'Seçilen adres hesabınıza ait değil.'], 403);
        }

        return [
            'lat' => $address->latitude !== null ? (float) $address->latitude : null,
            'lng' => $address->longitude !== null ? (float) $address->longitude : null,
            'province' => $address->province,
        ];
    }
}
