<?php

namespace App\Services;

use App\Models\FeaturedPlacementSetting;
use App\Models\FeaturedPromotion;
use App\Models\ProviderProfile;
use App\Support\Geo;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

/**
 * "Liste Reklamı": which paid providers fill the recommended slots at the top of a provider list.
 *
 * Deliberately NOT the homepage algorithm. The homepage showcase lists every running promotion in
 * random order and pages through them. A list ad is contextual and scarce:
 *   1. Eligibility: a running `listing` period AND the provider matches what the customer is
 *      looking at right now (gender type, the requested service(s), the search term, the minimum
 *      star rating and the maximum distance). A barber is never sponsored into a women's list.
 *   2. Weighting: quality x proximity. quality = the Tarak score (review-weighted rating, so an
 *      unrated newcomer is not punished to zero but cannot beat a proven 4.8); proximity = 1/(1+km/15)
 *      when the customer's position is known. Paying buys a slot in the draw, not a guaranteed rank.
 *   3. Draw: a weighted draw WITHOUT replacement (Efraimidis-Spirakis) seeded by the customer and a
 *      time bucket of `rotation_seconds` (default 20). The set is stable inside one bucket and changes
 *      with the next one (the clients ask again every bucket), different customers see different sets:
 *      with hundreds of advertisers every active ad keeps getting its turn.
 *   4. Slots: at most `slots` cards (admin setting). The organic list is NOT thinned: the clients hide
 *      the providers currently in the slots from it, so a provider that rotates out reappears there.
 */
class ListingAdService
{
    /** Shown on the card: the list ad reads as a recommendation, not as an advertisement. */
    public const LABEL = 'Önerilen';

    public function settings(): FeaturedPlacementSetting
    {
        return FeaturedPlacementSetting::for(FeaturedPromotion::PLACEMENT_LISTING);
    }

    /** What the clients need to rotate the slots: how many cards and how many seconds a set stays. */
    public function meta(): array
    {
        $settings = $this->settings();

        return ['sponsored_slots' => $settings->slots, 'rotation_seconds' => max(1, $settings->rotation_seconds)];
    }

    /**
     * @param array{
     *   type?: ?string, service_ids?: array<int, int>, term?: ?string, min_rating?: float,
     *   origin?: ?array{0: float, 1: float}, max_distance_km?: ?float, seed?: string, preview_provider_id?: ?int,
     *   require_service_radius?: bool
     * } $context
     * @return Collection<int, ProviderProfile> at most `slots` profiles, best draw first
     */
    public function sponsored(array $context = []): Collection
    {
        $settings = $this->settings();
        $slots = max(0, $settings->slots);
        if ($slots === 0) {
            return collect();
        }

        $providerIds = FeaturedPromotion::query()->active()->placement(FeaturedPromotion::PLACEMENT_LISTING)->distinct()->pluck('provider_user_id');
        if ($providerIds->isEmpty()) {
            return collect();
        }

        $preview = isset($context['preview_provider_id']) ? (int) $context['preview_provider_id'] : null;

        $profiles = $this->candidates($providerIds->all(), $context, $preview);
        if ($profiles->isEmpty()) {
            return collect();
        }

        $ratings = $this->ratingStats($profiles->pluck('user_id')->all());
        $origin = $context['origin'] ?? null;
        $bucket = intdiv(now()->timestamp, max(1, $settings->rotation_seconds));
        $seed = (string) ($context['seed'] ?? 'anon');

        $scored = $profiles->map(function (ProviderProfile $profile) use ($ratings, $origin, $bucket, $seed) {
            $weight = $this->quality($ratings[$profile->user_id] ?? null) * $this->proximity($origin, $profile);
            // u in (0, 1]: stable for (seed, bucket, provider): the set only changes when the time bucket does.
            // (A cryptographic hash, not crc32: crc32 of near-identical strings is linearly related.)
            $u = (hexdec(substr(sha1($seed . '|' . $bucket . '|' . $profile->user_id), 0, 8)) + 1) / 4294967297;

            return ['profile' => $profile, 'key' => -log($u) / max($weight, 0.01)];
        })->sortBy('key')->values();

        $picked = $scored->pluck('profile');

        if ($preview !== null) {
            // The provider checking their own ad: it leads the slots (it IS running), the rest follow the draw.
            $own = $picked->firstWhere('user_id', $preview);
            if ($own) {
                $picked = $picked->reject(fn (ProviderProfile $p) => $p->user_id === $preview)->prepend($own);
            }
        }

        return $picked->take($slots)->values();
    }

    /** Whether the provider has a running list ad right now (drives the "customer view" check). */
    public function isRunning(int $providerUserId): bool
    {
        return FeaturedPromotion::query()->active()->placement(FeaturedPromotion::PLACEMENT_LISTING)->where('provider_user_id', $providerUserId)->exists();
    }

    /** How many running list ads compete with this provider in the same type / city. */
    public function competitors(ProviderProfile $profile): int
    {
        $ids = FeaturedPromotion::query()->active()->placement(FeaturedPromotion::PLACEMENT_LISTING)->distinct()->pluck('provider_user_id');

        return ProviderProfile::query()
            ->publiclyListed()
            ->whereIn('user_id', $ids)
            ->where('provider_type', $profile->provider_type)
            ->where('user_id', '!=', $profile->user_id)
            ->count();
    }

    /** @return Collection<int, ProviderProfile> */
    private function candidates(array $providerIds, array $context, ?int $preview): Collection
    {
        $query = ProviderProfile::query()->publiclyListed()->with('user')->whereIn('user_id', $providerIds);

        // A provider previewing their own ad is judged on "is my ad running", not on the filters;
        // every other ad still has to match the customer's context.
        if ($preview === null) {
            $this->applyContext($query, $context);
            $profiles = $query->get();
        } else {
            $others = (clone $query)->where('user_id', '!=', $preview);
            $this->applyContext($others, $context);
            $profiles = $others->get()->concat((clone $query)->where('user_id', $preview)->get());
        }

        $origin = $context['origin'] ?? null;
        $max = $context['max_distance_km'] ?? null;
        $requireServiceRadius = !empty($context['require_service_radius']);
        if ($origin && ($max || $requireServiceRadius)) {
            $profiles = $profiles->filter(function (ProviderProfile $p) use ($origin, $max, $preview, $requireServiceRadius) {
                if ($requireServiceRadius && ($p->user?->role !== 'PROVIDER' || $p->user?->status !== 'active'
                    || $p->latitude === null || $p->longitude === null
                    || abs((float) $p->latitude) > 90 || abs((float) $p->longitude) > 180
                    || ((float) $p->latitude === 0.0 && (float) $p->longitude === 0.0))) {
                    return false;
                }
                if ($preview !== null && $p->user_id === $preview) {
                    return true;
                }
                $km = Geo::distanceKm($origin[0], $origin[1], $p->latitude, $p->longitude);
                $limit = $requireServiceRadius
                    ? min($max ?? PHP_FLOAT_MAX, (float) ($p->service_radius_km ?: 15))
                    : $max;

                return $km !== null && $km <= $limit;
            });
        }

        return $profiles->values();
    }

    private function applyContext($query, array $context): void
    {
        if (!empty($context['type'])) {
            $query->where('provider_type', $context['type']);
        }
        foreach ((array) ($context['service_ids'] ?? []) as $serviceId) {
            $query->whereHas('providerServices', fn ($q) => $q->where('service_id', (int) $serviceId)->where('is_active', true));
        }
        $term = trim((string) ($context['term'] ?? ''));
        if ($term !== '') {
            $like = '%' . str_replace(['\\', '%', '_'], ['\\\\', '\\%', '\\_'], $term) . '%';
            $query->where(function ($w) use ($like) {
                $w->where('business_name', 'like', $like)
                    ->orWhere('city', 'like', $like)
                    ->orWhere('district', 'like', $like)
                    ->orWhereHas('user', fn ($u) => $u->where('name', 'like', $like));
            });
        }
        $minRating = (float) ($context['min_rating'] ?? 0);
        if ($minRating > 0) {
            $query->whereIn('user_id', DB::table('provider_reviews')
                ->select('provider_user_id')
                ->groupBy('provider_user_id')
                ->havingRaw('AVG(rating) >= ?', [min($minRating, 5)]));
        }
    }

    /** @return array<int, array{count: int, avg: float}> keyed by provider user id */
    private function ratingStats(array $userIds): array
    {
        return DB::table('provider_reviews')
            ->whereIn('provider_user_id', $userIds)
            ->groupBy('provider_user_id')
            ->selectRaw('provider_user_id, COUNT(*) as c, AVG(rating) as a')
            ->get()
            ->mapWithKeys(fn ($r) => [(int) $r->provider_user_id => ['count' => (int) $r->c, 'avg' => (float) $r->a]])
            ->all();
    }

    /** 0.4 .. 1.0: review-weighted rating (prior of 5 reviews at the platform average of 4.0). */
    private function quality(?array $stats): float
    {
        $count = $stats['count'] ?? 0;
        $avg = $stats['avg'] ?? 0.0;
        $score = ($count * $avg + 5 * 4.0) / ($count + 5);

        return max(0.4, min(1.0, $score / 5));
    }

    /** 1.0 when the position is unknown, otherwise 1/(1+km/15) bounded below at 0.2. */
    private function proximity(?array $origin, ProviderProfile $profile): float
    {
        if (!$origin) {
            return 1.0;
        }
        $km = Geo::distanceKm($origin[0], $origin[1], $profile->latitude, $profile->longitude);

        return $km === null ? 0.5 : max(0.2, 1 / (1 + $km / 15));
    }
}
