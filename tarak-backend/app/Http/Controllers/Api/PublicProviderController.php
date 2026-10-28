<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\FeaturedPromotion;
use App\Models\ProviderDocument;
use App\Models\ProviderProfile;
use App\Models\ProviderReview;
use App\Models\ProviderService;
use App\Models\SiteContent;
use App\Services\ListingAdService;
use App\Services\ProviderOfferingService;
use App\Support\Geo;
use App\Support\ProviderListFilters;
use App\Support\SiteContentDefaults;
use Illuminate\Database\Eloquent\Collection as EloquentCollection;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

class PublicProviderController extends Controller
{
    /** Bayesian weight for the Tarak score: how many "average" reviews every provider starts with. */
    private const SCORE_PRIOR_REVIEWS = 5;

    public function __construct(protected ProviderOfferingService $offerings, protected ListingAdService $listingAds) {}

    /**
     * "Doğrulanmış Hizmet Verenler": verified, publicly-listable providers ranked by
     * Tarak puanı (rating weighted by review count, so one lucky 5.0 can't outrank a
     * proven 4.8). Only the top `limit` are returned; `type=barber|coiffeur` filters
     * men / women. Rating / review count / service count are REAL (never hardcoded).
     */
    public function featured(Request $request): JsonResponse
    {
        $limit = max(1, min((int) $request->query('limit', 8), 20));

        $profiles = $this->rankedQuery($this->typeFilter($request))
            ->orderByDesc('tarak_score')
            ->orderByDesc(DB::raw('COALESCE(rs.review_total, 0)'))
            ->orderBy('provider_profiles.id')
            ->limit($limit)
            ->get();

        return response()->json(['success' => true, 'data' => $this->cards($profiles)]);
    }

    /**
     * "Tüm uzmanlar": every publicly-listable provider, paginated and filterable by
     * gender (`type`), review count (`min_reviews`), star average (`min_rating`), a search term
     * (`q`: name, business, city) and distance (`lat` + `lng`, optional `max_distance_km`).
     * `sort`: rating (Tarak puanı, default) | reviews | newest | distance (nearest first, needs lat + lng).
     * Rating / review count / distance are REAL. The response also carries `sponsored`: the
     * running "Liste Reklamı" providers for this search (see ListingAdService); the set changes every
     * `meta.rotation_seconds`, which the clients follow with `sponsored_only=1` (just the cards, no list).
     */
    public function index(Request $request): JsonResponse
    {
        $perPage = max(6, min((int) $request->query('per_page', 12), 30));
        $minReviews = (int) $request->query('min_reviews', 0);
        $filters = ProviderListFilters::fromRequest($request, $request->query('type'));
        $term = (string) ($filters['term'] ?? '');
        $minRating = $filters['min_rating'];
        $origin = $filters['origin'];
        $maxDistance = $filters['max_distance_km'];
        $sort = $filters['sort'] === 'relevance' ? 'rating' : $filters['sort'];
        if ($sort === 'distance' && !$origin) {
            $sort = 'rating';
        }

        $sponsored = $this->listingAds->sponsored($filters);
        $sponsoredCards = fn () => $this->cards($sponsored, $origin)->map(fn (array $card) => $card + ['is_sponsored' => true, 'sponsored_label' => ListingAdService::LABEL])->values();

        if ($request->boolean('sponsored_only')) {
            return response()->json(['success' => true, 'sponsored' => $sponsoredCards(), 'meta' => ['has_origin' => $origin !== null] + $this->listingAds->meta()]);
        }

        $query = $this->rankedQuery($filters['type'])
            ->when($minRating > 0, fn ($q) => $q->whereRaw('COALESCE(rs.review_avg, 0) >= ?', [$minRating]))
            ->when($minReviews > 0, fn ($q) => $q->whereRaw('COALESCE(rs.review_total, 0) >= ?', [$minReviews]))
            ->when($term !== '', fn ($q) => $q->where(function ($w) use ($term) {
                $like = '%' . str_replace(['\\', '%', '_'], ['\\\\', '\\%', '\\_'], $term) . '%';
                $w->where('provider_profiles.business_name', 'like', $like)
                    ->orWhere('provider_profiles.city', 'like', $like)
                    ->orWhere('provider_profiles.district', 'like', $like)
                    ->orWhereHas('user', fn ($u) => $u->where('name', 'like', $like));
            }));

        if ($origin) {
            [$distanceSql, $bindings] = Geo::sql($origin, 'provider_profiles.latitude', 'provider_profiles.longitude');
            if ($maxDistance) {
                $query->whereNotNull('provider_profiles.latitude')->whereNotNull('provider_profiles.longitude')
                    // PDO binds PHP floats as strings on SQLite; cast the radius to a
                    // number so SQLite compares distances numerically, like MySQL.
                    ->whereRaw($distanceSql . ' <= CAST(? AS REAL)', [...$bindings, $maxDistance]);
            }
            if ($sort === 'distance') {
                // Providers without coordinates sink to the end.
                $query->orderByRaw('(provider_profiles.latitude IS NULL OR provider_profiles.longitude IS NULL) ASC')
                    ->orderByRaw($distanceSql . ' ASC', $bindings);
            }
        }

        match ($sort) {
            'reviews' => $query->orderByDesc(DB::raw('COALESCE(rs.review_total, 0)'))->orderByDesc('tarak_score'),
            'newest' => $query->orderByRaw('COALESCE(provider_profiles.approved_at, provider_profiles.created_at) DESC'),
            'distance' => $query->orderByDesc('tarak_score'),
            default => $query->orderByDesc('tarak_score')->orderByDesc(DB::raw('COALESCE(rs.review_total, 0)')),
        };
        $query->orderBy('provider_profiles.id');

        $page = $query->paginate($perPage);

        return response()->json([
            'success' => true,
            'data' => $this->cards($page->getCollection(), $origin),
            'sponsored' => $page->currentPage() === 1 ? $sponsoredCards() : [],
            'meta' => [
                'current_page' => $page->currentPage(),
                'last_page' => $page->lastPage(),
                'per_page' => $page->perPage(),
                'total' => $page->total(),
                'has_origin' => $origin !== null,
                'origin_source' => $request->attributes->get('nearby_origin_source'),
                'radius_km' => $request->attributes->get('nearby_radius_km'),
            ] + $this->listingAds->meta(),
        ]);
    }

    /**
     * The same filtered, ranked card query for web and Flutter home screens.
     * Device coordinates are opt-in query parameters; otherwise use the customer's
     * saved default address. A missing position is an explicit error so the client
     * can ask for location permission or an address instead of showing unrelated cards.
     */
    public function nearby(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'radius_km' => ['sometimes', 'numeric', 'between:1,50'],
            'lat' => ['required_with:lng', 'numeric', 'between:-90,90'],
            'lng' => ['required_with:lat', 'numeric', 'between:-180,180'],
            'type' => ['sometimes', 'in:barber,coiffeur'],
            'per_page' => ['sometimes', 'integer', 'between:1,30'],
            'page' => ['sometimes', 'integer', 'min:1'],
        ]);

        $radius = (float) ($validated['radius_km'] ?? 10);
        $source = 'device';
        if (isset($validated['lat'], $validated['lng'])) {
            $latitude = (float) $validated['lat'];
            $longitude = (float) $validated['lng'];
        } else {
            $profile = $request->user()->customerProfile;
            $address = null;
            if ($profile) {
                $address = $profile->defaultAddress()->whereNotNull('latitude')->whereNotNull('longitude')->first()
                    ?? $profile->addresses()->whereNotNull('latitude')->whereNotNull('longitude')->orderByDesc('is_default')->first();
            }
            $latitude = $address?->latitude !== null ? (float) $address->latitude : null;
            $longitude = $address?->longitude !== null ? (float) $address->longitude : null;
            $source = 'saved_address';
        }

        if ($latitude === null || $longitude === null || ($latitude === 0.0 && $longitude === 0.0)) {
            return response()->json([
                'success' => false,
                'message' => 'Yakındaki berberler için kayıtlı koordinatlı bir adres veya konum izni gerekli.',
            ], 422);
        }

        $request->query->set('lat', (string) $latitude);
        $request->query->set('lng', (string) $longitude);
        $request->query->set('max_distance_km', (string) $radius);
        $request->query->set('sort', 'distance');
        $request->attributes->set('nearby_origin_source', $source);
        $request->attributes->set('nearby_radius_km', $radius);

        return $this->index($request);
    }

    /**
     * Listable providers joined with their review stats and a Tarak score (rating
     * weighted by review count, so one lucky 5.0 can't outrank a proven 4.8).
     */
    private function rankedQuery(?string $type): \Illuminate\Database\Eloquent\Builder
    {
        $stats = DB::table('provider_reviews')
            ->join('users as review_customers', 'review_customers.id', '=', 'provider_reviews.customer_user_id')
            ->where('review_customers.is_demo', false)
            ->select('provider_user_id', DB::raw('COUNT(*) as review_total'), DB::raw('AVG(rating) as review_avg'))
            ->groupBy('provider_user_id');
        $globalAvg = (float) (DB::table('provider_reviews')
            ->join('users as review_customers', 'review_customers.id', '=', 'provider_reviews.customer_user_id')
            ->where('review_customers.is_demo', false)->avg('rating') ?: 4.0);
        $m = self::SCORE_PRIOR_REVIEWS;

        return ProviderProfile::query()
            ->publiclyListed()
            ->leftJoinSub($stats, 'rs', 'rs.provider_user_id', '=', 'provider_profiles.user_id')
            ->select('provider_profiles.*')
            ->selectRaw('((COALESCE(rs.review_total, 0) * COALESCE(rs.review_avg, 0)) + ? * ?) / (COALESCE(rs.review_total, 0) + ?) as tarak_score', [$m, $globalAvg, $m])
            ->when($type, fn ($q) => $q->where('provider_profiles.provider_type', $type));
    }

    /**
     * "Öne Çıkan Profesyoneller": providers with a running paid (or gifted) period,
     * in random order so every promoted profile gets its turn. The period end is the
     * only thing that removes a profile — no cron involved.
     */
    public function spotlight(Request $request): JsonResponse
    {
        $limit = max(1, min((int) $request->query('limit', 36), 60));
        $type = $this->typeFilter($request);

        $promotedIds = FeaturedPromotion::query()->active()->placement(FeaturedPromotion::PLACEMENT_HOME)->distinct()->pluck('provider_user_id');

        $profiles = $promotedIds->isEmpty() ? collect() : ProviderProfile::query()
            ->publiclyListed()
            ->whereIn('user_id', $promotedIds)
            ->when($type, fn ($q) => $q->where('provider_type', $type))
            ->inRandomOrder()
            ->limit($limit)
            ->get();

        $cards = $this->cards($profiles)->map(fn (array $card) => $card + ['is_promoted' => true]);

        return response()->json([
            'success' => true,
            'data' => $cards->values(),
            'meta' => [
                'total' => $cards->count(),
                'rotate_seconds' => $this->spotlightRotateSeconds(),
            ],
        ]);
    }

    /** "Yeni Katılan Profesyoneller": the most recently approved providers. */
    public function newest(Request $request): JsonResponse
    {
        $limit = max(1, min((int) $request->query('limit', 8), 20));
        $type = $this->typeFilter($request);

        $profiles = ProviderProfile::query()
            ->publiclyListed()
            ->when($type, fn ($q) => $q->where('provider_type', $type))
            ->orderByRaw('COALESCE(approved_at, created_at) DESC')
            ->orderByDesc('id')
            ->limit($limit)
            ->get();

        $joined = $profiles->mapWithKeys(fn (ProviderProfile $p) => [(string) $p->user_id => ($p->approved_at ?? $p->created_at)?->toIso8601String()]);
        $cards = $this->cards($profiles)->map(fn (array $card) => $card + ['joined_at' => $joined[$card['user_id']] ?? null]);

        return response()->json(['success' => true, 'data' => $cards->values()]);
    }

    /**
     * Public detail for ONE publicly-listable provider, so a logged-out visitor
     * arriving from a homepage card sees a real profile instead of a dead route.
     *
     * Exposes exactly the same safe presentation fields as featured() — no
     * offerings, pricing, availability or contact data, which stay behind the
     * authenticated customer endpoints.
     */
    public function show(int $provider): JsonResponse
    {
        $profile = ProviderProfile::query()
            ->publiclyListed()
            ->with('user')
            ->where('user_id', $provider)
            ->first();

        if (!$profile) {
            return response()->json([
                'success' => false,
                'message' => 'Hizmet veren bulunamadı veya yayında değil.',
            ], 404);
        }

        return response()->json(['success' => true, 'data' => $this->cards(new EloquentCollection([$profile]))->first()]);
    }

    /** `type` query: barber (men) | coiffeur (women); anything else = no filter. */
    private function typeFilter(Request $request): ?string
    {
        $type = $request->query('type');

        return in_array($type, ['barber', 'coiffeur'], true) ? $type : null;
    }

    private function spotlightRotateSeconds(): int
    {
        $stored = SiteContent::query()->oldest('id')->first()?->content ?? [];
        $seconds = $stored['home']['spotlight']['rotate_seconds'] ?? SiteContentDefaults::home()['spotlight']['rotate_seconds'];

        return max(3, min((int) $seconds, 120));
    }

    /**
     * Safe public cards for a set of profiles with REAL rating / review count /
     * service count, computed with two grouped queries instead of per-card lookups.
     *
     * @param Collection<int, ProviderProfile> $profiles
     * @return Collection<int, array<string, mixed>>
     */
    private function cards(Collection $profiles, ?array $origin = null): Collection
    {
        if ($profiles->isEmpty()) {
            return collect();
        }
        if ($profiles instanceof EloquentCollection) {
            $profiles->load(['user', 'documents']);
        }

        $reviewStats = ProviderReview::query()
            ->whereIn('provider_user_id', $profiles->pluck('user_id'))
            ->whereHas('customer', fn ($query) => $query->where('is_demo', false))
            ->groupBy('provider_user_id')
            ->selectRaw('provider_user_id, COUNT(*) as review_total, AVG(rating) as review_avg')
            ->get()
            ->keyBy('provider_user_id');

        $serviceCounts = ProviderService::query()
            ->whereIn('provider_profile_id', $profiles->pluck('id'))
            ->where('is_active', true)
            ->groupBy('provider_profile_id')
            ->selectRaw('provider_profile_id, COUNT(*) as service_total')
            ->pluck('service_total', 'provider_profile_id');

        $discounts = app(\App\Services\ProviderDiscountService::class)->percentsFor($profiles->pluck('user_id'));

        return $profiles->map(function (ProviderProfile $profile) use ($reviewStats, $serviceCounts, $origin, $discounts) {
            $row = $profile->user?->is_demo ? null : $reviewStats->get($profile->user_id);
            $verified = $profile->isVerified();

            $card = $this->offerings->presentProvider($profile, [
                'count' => (int) ($row->review_total ?? 0),
                'avg' => $row ? (float) $row->review_avg : null,
            ], $verified, (int) ($discounts[(int) $profile->user_id] ?? 0));
            $card['service_count'] = (int) ($serviceCounts[$profile->id] ?? 0);
            if ($origin) {
                $card['distance_km'] = Geo::distanceKm($origin[0], $origin[1], $profile->latitude, $profile->longitude);
            }

            return $card;
        })->values();
    }
}
