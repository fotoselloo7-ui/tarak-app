<?php

namespace App\Services;

use App\Models\ProviderPackage;
use App\Models\ProviderProfile;
use App\Models\ProviderReview;
use App\Models\ProviderService;
use App\Models\ServiceRequest;
use Illuminate\Validation\ValidationException;
use App\Support\MediaUrl;

class ProviderOfferingService
{
    public const TYPE_SERVICE = 'SERVICE';
    public const TYPE_PACKAGE = 'PACKAGE';

    public function __construct(
        protected InstantMatchingService $matchingService,
        protected ProviderAvailabilityService $availabilityService,
        protected ProviderDiscountService $discounts,
    ) {}

    /**
     * Resolve a customer-selected offering into an immutable snapshot.
     *
     * @return array{profile: ProviderProfile, type: string, provider_service_id: ?int, provider_package_id: ?int,
     *               service_ids: array<int>, category_id: ?string, price: float, duration_minutes: int, snapshot: array}
     */
    public function resolveOffering(?int $providerServiceId, ?int $providerPackageId): array
    {
        if ($providerServiceId) {
            $ps = ProviderService::with(['service', 'providerProfile.user'])->find($providerServiceId);
            if (!$ps || !$ps->is_active || !$ps->service || !$ps->service->is_active) {
                throw ValidationException::withMessages([
                    'provider_service_id' => 'Seçilen hizmet şu anda bu uzman tarafından sunulmuyor.',
                ]);
            }

            $profile = $ps->providerProfile;
            // The price the customer pays: the base price minus a running campaign discount.
            $discount = $this->discounts->apply((int) $profile->user_id, $ps->effectivePrice());
            $price = $discount['price'];
            $duration = max(15, $ps->effectiveDurationMinutes());

            return [
                'profile' => $profile,
                'type' => self::TYPE_SERVICE,
                'provider_service_id' => $ps->id,
                'provider_package_id' => null,
                'service_ids' => [$ps->service_id],
                'category_id' => $ps->service->category_id,
                'price' => $price,
                'duration_minutes' => $duration,
                'snapshot' => [
                    'type' => self::TYPE_SERVICE,
                    'provider_service_id' => $ps->id,
                    'provider_user_id' => $profile->user_id,
                    'provider_name' => $this->providerDisplayName($profile),
                    'title' => $ps->service->name,
                    'description' => $ps->description,
                    'price' => $price,
                    'original_price' => $discount['original_price'],
                    'discount_percent' => $discount['discount_percent'],
                    'duration_minutes' => $duration,
                    'items' => [['service_id' => $ps->service_id, 'name' => $ps->service->name]],
                    'captured_at' => now()->toISOString(),
                ],
            ];
        }

        $package = $providerPackageId
            ? ProviderPackage::with(['services', 'providerProfile.user'])->find($providerPackageId)
            : null;

        if (!$package || !$package->is_active) {
            throw ValidationException::withMessages([
                'provider_package_id' => 'Seçilen paket şu anda aktif değil.',
            ]);
        }

        if ($package->services->isEmpty() || $package->services->contains(fn ($s) => !$s->is_active)) {
            throw ValidationException::withMessages([
                'provider_package_id' => 'Paketteki hizmetlerden biri şu anda sunulmuyor.',
            ]);
        }

        $profile = $package->providerProfile;
        $discount = $this->discounts->apply((int) $profile->user_id, (float) $package->price);
        $price = $discount['price'];
        $duration = max(15, (int) $package->duration_minutes);

        return [
            'profile' => $profile,
            'type' => self::TYPE_PACKAGE,
            'provider_service_id' => null,
            'provider_package_id' => $package->id,
            'service_ids' => $package->services->pluck('id')->all(),
            'category_id' => $package->services->first()?->category_id,
            'price' => $price,
            'duration_minutes' => $duration,
            'snapshot' => [
                'type' => self::TYPE_PACKAGE,
                'provider_package_id' => $package->id,
                'provider_user_id' => $profile->user_id,
                'provider_name' => $this->providerDisplayName($profile),
                'title' => $package->title,
                'description' => $package->description,
                'price' => $price,
                'original_price' => $discount['original_price'],
                'discount_percent' => $discount['discount_percent'],
                'duration_minutes' => $duration,
                'items' => $package->services->map(fn ($s) => ['service_id' => $s->id, 'name' => $s->name])->values()->all(),
                'captured_at' => now()->toISOString(),
            ],
        ];
    }

    /**
     * Can this provider be called right now for a job of this duration?
     * Reuses the instant eligibility rules (approval, documents, online, accepting clients, busy, radius)
     * plus the provider's working window (schedule, breaks, closed dates, appointments).
     *
     * @return array{available: bool, reason: ?string, distance_km: ?float}
     */
    public function instantAvailability(ProviderProfile $profile, int $durationMinutes, ?float $lat = null, ?float $lng = null, ?string $province = null): array
    {
        $providerUser = $profile->user;
        if (!$providerUser) {
            return ['available' => false, 'reason' => 'Hizmet veren bulunamadı.', 'distance_km' => null];
        }

        $probe = new ServiceRequest([
            'status' => ServiceRequest::STATUS_OPEN,
            'mode' => ServiceRequest::MODE_INSTANT,
            'target_provider_user_id' => $providerUser->id,
            'private_latitude' => $lat,
            'private_longitude' => $lng,
            'approx_province' => $province,
        ]);

        $check = $this->matchingService->isProviderEligibleForRequest($providerUser, $probe);
        if (!$check['eligible']) {
            return ['available' => false, 'reason' => $check['reason'], 'distance_km' => $check['distance_km']];
        }

        $window = $this->availabilityService->instantWindowCheck($profile, $durationMinutes);
        if (!$window['available']) {
            return ['available' => false, 'reason' => $window['reason'], 'distance_km' => $check['distance_km']];
        }

        return ['available' => true, 'reason' => null, 'distance_km' => $check['distance_km']];
    }

    /**
     * Provider card shared by discovery and service/package profiles.
     */
    /**
     * @param array{count:int, avg:?float}|null $reviewStats precomputed review stats (list endpoints), else queried here
     * @param bool|null $verified precomputed verified flag (list endpoints), else derived here
     */
    public function presentProvider(ProviderProfile $profile, ?array $reviewStats = null, ?bool $verified = null, ?int $discountPercent = null): array
    {
        $user = $profile->user;
        if ($reviewStats === null) {
            $reviews = ProviderReview::query()->where('provider_user_id', $profile->user_id);
            $reviewStats = ['count' => (clone $reviews)->count(), 'avg' => null];
            if ($reviewStats['count'] > 0) {
                $reviewStats['avg'] = (float) (clone $reviews)->avg('rating');
            }
        }
        $reviewCount = $reviewStats['count'];

        return [
            'id' => (string) $profile->id,
            'user_id' => (string) $profile->user_id,
            'name' => $user?->name,
            'business_name' => $this->providerDisplayName($profile),
            'avatar_url' => MediaUrl::resolve($user?->avatar_url),
            'cover_url' => MediaUrl::resolve($profile->cover_url),
            'gallery' => array_values(array_filter(array_map(fn ($url) => MediaUrl::resolve($url), $profile->gallery ?? []))),
            'provider_type' => $profile->provider_type,
            'title' => $profile->title,
            'bio' => $profile->bio,
            'city' => $profile->city,
            'district' => $profile->district,
            'experience_years' => $profile->experience_years,
            'is_demo' => false,
            'is_verified' => $verified ?? $profile->isVerified(),
            'is_online' => (bool) $profile->is_online,
            'rating' => $reviewCount > 0 ? round((float) $reviewStats['avg'], 2) : null,
            'review_count' => $reviewCount,
            // A running campaign discount (percent), 0 when none.
            'discount_percent' => $discountPercent ?? $this->discounts->percentFor((int) $profile->user_id),
        ];
    }

    /**
     * @param int $discountPercent the running campaign discount of the provider (customer-facing lists pass it; the
     *                             provider's own price list leaves it at 0 and so keeps seeing the base price)
     */
    public function presentService(ProviderService $ps, int $discountPercent = 0): array
    {
        $price = $this->discounts->applyPercent($ps->effectivePrice(), $discountPercent);

        return [
            'provider_service_id' => $ps->id,
            'service_id' => $ps->service_id,
            'category_id' => $ps->service?->category_id,
            'name' => $ps->service?->name,
            'description' => $ps->description,
            'price' => $price['price'],
            'original_price' => $price['original_price'],
            'discount_percent' => $price['discount_percent'],
            'duration_minutes' => max(15, $ps->effectiveDurationMinutes()),
        ];
    }

    public function presentPackage(ProviderPackage $package, int $discountPercent = 0): array
    {
        $price = $this->discounts->applyPercent((float) $package->price, $discountPercent);

        return [
            'provider_package_id' => $package->id,
            'title' => $package->title,
            'description' => $package->description,
            'price' => $price['price'],
            'original_price' => $price['original_price'],
            'discount_percent' => $price['discount_percent'],
            'duration_minutes' => (int) $package->duration_minutes,
            'is_active' => (bool) $package->is_active,
            'services' => $package->services->map(fn ($s) => [
                'service_id' => $s->id,
                'name' => $s->name,
                'category_id' => $s->category_id,
            ])->values()->all(),
        ];
    }

    private function providerDisplayName(ProviderProfile $profile): ?string
    {
        return $profile->business_name ?: $profile->user?->name;
    }
}
