<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ProviderDocument;
use App\Models\ProviderProfile;
use App\Models\ProviderReview;
use App\Models\ProviderService;
use App\Models\ProviderServiceArea;
use App\Services\MapRoutingService;
use App\Services\ProviderDiscountService;
use App\Services\ProviderOfferingService;
use App\Services\ServiceAreaMatcher;
use App\Support\Geo;
use App\Support\MediaUrl;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

class MapDirectoryController extends Controller
{
    private const MAP_STYLE_URL = 'https://tiles.openfreemap.org/styles/liberty';
    private const SCORE_PRIOR_REVIEWS = 5;

    private const DAY_LABELS = [
        'monday' => 'Pazartesi',
        'tuesday' => 'Salı',
        'wednesday' => 'Çarşamba',
        'thursday' => 'Perşembe',
        'friday' => 'Cuma',
        'saturday' => 'Cumartesi',
        'sunday' => 'Pazar',
    ];

    public function __construct(
        private ServiceAreaMatcher $areaMatcher,
        private MapRoutingService $routingService,
        private ProviderOfferingService $offeringService,
        private ProviderDiscountService $discounts,
    ) {}

    /**
     * Public map & directory search endpoint.
     *
     * PRIVACY INVARIANT: Providers with `work_mode === 'mobile'` are NEVER returned
     * in `data` (map pins) and NEVER expose latitude, longitude, or street address.
     */
    public function index(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'min_lat' => ['nullable', 'numeric', 'between:-90,90'],
            'max_lat' => ['nullable', 'numeric', 'between:-90,90'],
            'min_lng' => ['nullable', 'numeric', 'between:-180,180'],
            'max_lng' => ['nullable', 'numeric', 'between:-180,180'],
            'lat' => ['nullable', 'required_with:lng', 'numeric', 'between:-90,90'],
            'lng' => ['nullable', 'required_with:lat', 'numeric', 'between:-180,180'],
            'radius_km' => ['nullable', 'numeric', 'between:1,200'],
            'type' => ['nullable', 'in:barber,coiffeur'],
            'work_mode' => ['nullable', 'in:venue,mobile,both'],
            'city' => ['nullable', 'string', 'max:100'],
            'district' => ['nullable', 'string', 'max:100'],
            'neighborhood' => ['nullable', 'string', 'max:150'],
            'q' => ['nullable', 'string', 'max:80'],
            'booking_only' => ['nullable', 'boolean'],
            'verified_only' => ['nullable', 'boolean'],
            'include_mobile' => ['nullable', 'boolean'],
            'limit' => ['nullable', 'integer', 'between:1,5000'],
        ]);

        $limit = (int) ($validated['limit'] ?? 5000);
        $origin = isset($validated['lat'], $validated['lng'])
            ? [(float) $validated['lat'], (float) $validated['lng']]
            : null;
        $radiusKm = isset($validated['radius_km']) ? (float) $validated['radius_km'] : null;
        $type = $validated['type'] ?? null;
        $workMode = $validated['work_mode'] ?? null;
        $city = trim((string) ($validated['city'] ?? ''));
        $district = trim((string) ($validated['district'] ?? ''));
        $neighborhood = trim((string) ($validated['neighborhood'] ?? ''));
        $q = trim((string) ($validated['q'] ?? ''));
        $bookingOnly = $request->boolean('booking_only');
        $verifiedOnly = $request->boolean('verified_only');
        $includeMobile = $request->has('include_mobile') ? $request->boolean('include_mobile') : true;

        $hasBounds = isset($validated['min_lat'], $validated['max_lat'], $validated['min_lng'], $validated['max_lng']);
        $hasTextOrAreaFilter = $city !== '' || $district !== '' || $neighborhood !== '' || $q !== '';
        $hasExplicitAreaScope = $city !== '' || $district !== '' || $neighborhood !== '' || $hasBounds;
        $hasDirSchema = ProviderProfile::hasDirectorySchema();
        $hasAreasTable = ProviderProfile::hasServiceAreasTable();

        $baseColumns = [
            'id', 'user_id', 'business_name', 'provider_type', 'work_mode',
            'is_approved', 'identity_status', 'is_online', 'accepts_new_clients',
            'service_radius_km', 'city', 'district', 'neighborhood', 'street',
            'building_no', 'address_detail', 'latitude', 'longitude', 'cover_url',
        ];
        if ($hasDirSchema) {
            array_push(
                $baseColumns,
                'slug',
                'logo_url',
                'directory_listed',
                'directory_status',
            );
        }

        $relations = ['user:id,name,avatar_url,status,is_demo'];
        if ($hasAreasTable && ($hasTextOrAreaFilter || $limit <= 300)) {
            $relations[] = 'serviceAreas';
        }
        if ($q !== '') {
            $relations[] = 'providerServices.service';
        }

        // 1. Public map pins: strictly venue or both, with valid non-zero coordinates.
        $pins = collect();
        $truncated = false;
        $totalEligiblePins = ProviderProfile::query()->mapPinEligible()->count();

        $pinQuery = ProviderProfile::query()
            ->select($baseColumns)
            ->mapPinEligible()
            ->with($relations)
            ->when($type, fn ($query) => $query->where('provider_type', $type))
            ->when($workMode === ProviderProfile::WORK_MODE_VENUE, fn ($query) => $query->whereIn('work_mode', [
                ProviderProfile::WORK_MODE_VENUE,
                ProviderProfile::WORK_MODE_BOTH,
            ]))
            ->when(
                $workMode === ProviderProfile::WORK_MODE_MOBILE || $workMode === ProviderProfile::WORK_MODE_BOTH,
                fn ($query) => $query->where('work_mode', ProviderProfile::WORK_MODE_BOTH),
            )
            ->when($bookingOnly, fn ($query) => $query
                ->where('accepts_new_clients', true)
                ->where('is_approved', true)
                ->where('identity_status', 'APPROVED'))
            ->when($verifiedOnly, fn ($query) => $query->publiclyListed());

        if ($hasBounds) {
            $minLat = min((float) $validated['min_lat'], (float) $validated['max_lat']);
            $maxLat = max((float) $validated['min_lat'], (float) $validated['max_lat']);
            $minLng = min((float) $validated['min_lng'], (float) $validated['max_lng']);
            $maxLng = max((float) $validated['min_lng'], (float) $validated['max_lng']);
            $pinQuery->whereBetween('latitude', [$minLat, $maxLat])
                ->whereBetween('longitude', [$minLng, $maxLng]);
        }

        if ($origin && $radiusKm !== null && !$hasExplicitAreaScope) {
            [$distanceSql, $bindings] = Geo::sql($origin, 'provider_profiles.latitude', 'provider_profiles.longitude');
            $pinQuery->whereRaw($distanceSql . ' <= CAST(? AS DECIMAL(12,6))', [...$bindings, $radiusKm]);
        }

        if ($origin) {
            [$distanceSql, $bindings] = Geo::sql($origin, 'provider_profiles.latitude', 'provider_profiles.longitude');
            $pinQuery->orderByRaw($distanceSql . ' ASC', $bindings);
        }
        $pinQuery->orderBy('provider_profiles.id');

        $fetchCap = $hasTextOrAreaFilter ? 5000 : ($limit + 1);
        $candidates = $pinQuery->limit($fetchCap)->get();

        if ($verifiedOnly) {
            $candidates = $candidates->filter(fn (ProviderProfile $p) => $p->isVerified())->values();
        }

        if ($hasTextOrAreaFilter) {
            $candidates = $this->applyLocationAndSearchFilters(
                $candidates,
                $city,
                $district,
                $neighborhood,
                $q,
            );
        }

        if ($candidates->count() > $limit) {
            $truncated = true;
            $candidates = $candidates->take($limit);
        }

        $pins = $this->presentSummaries($candidates->values(), $origin, includeCoordinates: true, hasDirSchema: $hasDirSchema);
        unset($candidates);

        // 2. Mobile-only providers: returned ONLY in `mobile_providers` with coordinates stripped.
        $mobileProviders = collect();
        if ($includeMobile && $workMode !== ProviderProfile::WORK_MODE_VENUE) {
            $mobileRelations = ['user:id,name,avatar_url,status,is_demo'];
            if ($hasAreasTable) {
                $mobileRelations[] = 'serviceAreas';
            }
            if ($q !== '') {
                $mobileRelations[] = 'providerServices.service';
            }

            $mobileQuery = ProviderProfile::query()
                ->select($baseColumns)
                ->directoryListedPublic()
                ->where('work_mode', ProviderProfile::WORK_MODE_MOBILE)
                ->with($mobileRelations)
                ->when($type, fn ($query) => $query->where('provider_type', $type))
                ->when($bookingOnly, fn ($query) => $query
                    ->where('accepts_new_clients', true)
                    ->where('is_approved', true)
                    ->where('identity_status', 'APPROVED'))
                ->when($verifiedOnly, fn ($query) => $query->publiclyListed())
                ->orderBy('id');

            $mobileCandidates = $mobileQuery->limit(400)->get();

            if ($verifiedOnly) {
                $mobileCandidates = $mobileCandidates->filter(fn (ProviderProfile $p) => $p->isVerified())->values();
            }

            if ($hasTextOrAreaFilter) {
                $mobileCandidates = $this->applyLocationAndSearchFilters(
                    $mobileCandidates,
                    $city,
                    $district,
                    $neighborhood,
                    $q,
                );
            }

            $originWithinTurkey = $origin !== null
                && $origin[0] >= 35.0 && $origin[0] <= 43.0
                && $origin[1] >= 25.0 && $origin[1] <= 45.0;

            if ($hasBounds && $city === '' && $district === '' && $neighborhood === '') {
                $minLat = min((float) $validated['min_lat'], (float) $validated['max_lat']);
                $maxLat = max((float) $validated['min_lat'], (float) $validated['max_lat']);
                $minLng = min((float) $validated['min_lng'], (float) $validated['max_lng']);
                $maxLng = max((float) $validated['min_lng'], (float) $validated['max_lng']);
                $mobileCandidates = $mobileCandidates->filter(function (ProviderProfile $p) use ($minLat, $maxLat, $minLng, $maxLng) {
                    if ($p->latitude === null || $p->longitude === null) {
                        return false;
                    }
                    $lat = (float) $p->latitude;
                    $lng = (float) $p->longitude;

                    return $lat >= $minLat && $lat <= $maxLat && $lng >= $minLng && $lng <= $maxLng;
                })->values();
            } elseif ($originWithinTurkey && $city === '' && $district === '' && $neighborhood === '' && $radiusKm !== null) {
                $mobileCandidates = $mobileCandidates->filter(function (ProviderProfile $p) use ($origin, $radiusKm) {
                    if ($p->latitude === null || $p->longitude === null) {
                        return false;
                    }
                    $dist = Geo::distanceKm($origin[0], $origin[1], $p->latitude, $p->longitude);
                    $maxDist = min($radiusKm, (float) ($p->service_radius_km ?: 15));

                    return $dist !== null && $dist <= $maxDist;
                })->values();
            }

            $mobileProviders = $this->presentSummaries($mobileCandidates->take(50)->values(), null, includeCoordinates: false, hasDirSchema: $hasDirSchema);
        }

        return response()->json([
            'success' => true,
            'data' => $pins->values(),
            'mobile_providers' => $mobileProviders->values(),
            'meta' => [
                'total_pins' => $pins->count(),
                'total_eligible_pins' => $totalEligiblePins,
                'demo_pins' => $pins->where('is_demo', true)->count(),
                'total_mobile' => $mobileProviders->count(),
                'map_provider' => 'openfreemap',
                'map_style_url' => self::MAP_STYLE_URL,
                'has_origin' => $origin !== null,
                'truncated' => $truncated,
            ],
        ]);
    }

    /**
     * Public showcase detail for a single business by `slug` or numeric `user_id`.
     */
    public function show(string $identifier): JsonResponse
    {
        $hasDirSchema = ProviderProfile::hasDirectorySchema();
        $hasAreasTable = ProviderProfile::hasServiceAreasTable();

        $relations = [
            'user',
            'documents',
            'weeklySchedules.breaks',
            'closedDates' => fn ($q) => $q->whereDate('date', '>=', now()->toDateString())->orderBy('date'),
            'providerServices.service',
            'packages.services',
            'staff.staffServices.service',
        ];
        if ($hasAreasTable) {
            $relations[] = 'serviceAreas';
        }

        $query = ProviderProfile::query()->with($relations);

        if (ctype_digit($identifier)) {
            $profile = $query->where('user_id', (int) $identifier)->first();
        } elseif ($hasDirSchema) {
            $profile = $query->where('slug', $identifier)->first();
        } else {
            $profile = null;
        }

        $activeUser = $profile?->user !== null && $profile->user->status === 'active';
        if (! $hasDirSchema) {
            $visible = $profile !== null
                && $activeUser
                && $profile->is_approved
                && $profile->identity_status === 'APPROVED';
        } else {
            $visible = $profile !== null
                && $activeUser
                && $profile->directory_status !== ProviderProfile::DIRECTORY_SUSPENDED
                && $profile->directory_status !== ProviderProfile::DIRECTORY_REJECTED
                && (
                    $profile->isDirectoryPubliclyVisible()
                    || ($profile->is_approved && $profile->identity_status === 'APPROVED')
                );
        }

        if (!$visible) {
            return response()->json([
                'success' => false,
                'message' => 'İşletme bulunamadı veya yayında değil.',
            ], 404);
        }

        if ($hasDirSchema) {
            $profile->ensureSlug();
            if ($profile->isDirty('slug')) {
                $profile->saveQuietly();
            }
        }

        $isDemo = (bool) ($profile->user?->is_demo ?? false);
        // Same canonical review source & window as ReviewController::providerSummary.
        $reviewQuery = ProviderReview::query()->where('provider_user_id', $profile->user_id);
        $reviewCount = (clone $reviewQuery)->count();
        $ratingAvg = $reviewCount > 0 ? round((float) (clone $reviewQuery)->avg('rating'), 2) : null;
        $recentReviews = (clone $reviewQuery)
            ->with('customer:id,name')
            ->latest()
            ->limit(30)
            ->get()
            ->map(fn (ProviderReview $r) => [
                'id' => $r->id,
                'rating' => $r->rating,
                'comment' => \App\Support\CustomerNote::forDisplay($r->comment),
                'customer_name' => $r->customer?->name ?? 'Müşteri',
                'is_demo' => false,
                'created_at' => $r->created_at?->toIso8601String(),
            ])->values();

        $hasPublicPin = $profile->hasPublicVenuePin();
        $slug = $hasDirSchema ? ((string) ($profile->getAttribute('slug') ?: $profile->user_id)) : (string) $profile->user_id;
        $discountPercent = $this->discounts->percentFor((int) $profile->user_id);
        $acceptsTarakBookings = $profile->canAcceptTarakBookings();

        $activeServices = $profile->providerServices
            ->filter(fn (ProviderService $ps) => $ps->is_active && $ps->service && $ps->service->is_active)
            ->map(function (ProviderService $ps) use ($discountPercent) {
                $presented = $this->offeringService->presentService($ps, $discountPercent);

                return array_merge($presented, [
                    'id' => (string) $ps->service_id,
                    'provider_service_id' => (string) $ps->id,
                ]);
            })->values();

        $activePackages = $profile->packages
            ->filter(fn ($pkg) => $pkg->is_active && $pkg->services->isNotEmpty() && $pkg->services->every(fn ($s) => $s->is_active))
            ->map(function ($pkg) use ($discountPercent) {
                $presented = $this->offeringService->presentPackage($pkg, $discountPercent);

                return [
                    'id' => (string) $pkg->id,
                    'provider_package_id' => (int) $pkg->id,
                    'title' => $presented['title'],
                    'description' => $presented['description'],
                    'price' => $presented['price'],
                    'original_price' => $presented['original_price'],
                    'discount_percent' => $presented['discount_percent'],
                    'duration_minutes' => $presented['duration_minutes'],
                    'services' => $pkg->services->map(fn ($s) => $s->name)->values(),
                    'service_items' => $presented['services'],
                ];
            })->values();

        $visibleStaff = $acceptsTarakBookings
            ? $profile->staff
                ->filter(fn ($s) => $s->is_active && $s->visible_to_customers && $s->archived_at === null)
                ->sortBy([['sort_order', 'asc'], ['id', 'asc']])
                ->values()
                ->map(fn ($s) => [
                    'id' => $s->id,
                    'first_name' => $s->first_name,
                    'last_name' => $s->last_name,
                    'full_name' => $s->full_name,
                    'photo_url' => MediaUrl::resolve($s->photo_url),
                    'title' => $s->title,
                    'specialty' => $s->specialty,
                    'accepts_appointments' => (bool) $s->accepts_appointments,
                    'services' => $s->staffServices->where('is_active', true)->values()->map(fn ($ss) => [
                        'service_id' => (int) $ss->service_id,
                        'service_name' => $ss->service?->name,
                        'custom_duration_minutes' => $ss->custom_duration_minutes,
                    ])->values(),
                ])
                ->values()
            : collect();

        $scheduleMap = $profile->weeklySchedules->keyBy(fn ($s) => strtolower((string) $s->day_of_week));
        $workingHours = collect(self::DAY_LABELS)->map(function (string $label, string $dayKey) use ($scheduleMap) {
            $row = $scheduleMap->get($dayKey);

            return [
                'day' => $dayKey,
                'label' => $label,
                'enabled' => $row ? (bool) $row->is_enabled : false,
                'start_time' => $row?->start_time ? substr($row->start_time, 0, 5) : null,
                'end_time' => $row?->end_time ? substr($row->end_time, 0, 5) : null,
                'breaks' => $row ? $row->breaks->map(fn ($b) => [
                    'start_time' => substr($b->start_time, 0, 5),
                    'end_time' => substr($b->end_time, 0, 5),
                ])->values() : [],
            ];
        })->values();

        $serviceAreas = $hasAreasTable && $profile->relationLoaded('serviceAreas')
            ? $profile->serviceAreas->map(fn ($a) => [
                'id' => (string) $a->id,
                'province' => $a->province,
                'district' => $a->district,
                'neighborhood' => $a->neighborhood,
            ])->values()
            : collect();

        $closedDates = $profile->closedDates
            ->filter(fn ($d) => $d->date !== null)
            ->map(fn ($d) => [
                'id' => (string) $d->id,
                'date' => $d->date->format('Y-m-d'),
                'reason' => $d->reason,
                'note' => $d->note,
            ])
            ->values();

        return response()->json([
            'success' => true,
            'data' => [
                'id' => (string) $profile->id,
                'user_id' => (string) $profile->user_id,
                'slug' => $slug,
                'public_url' => $hasDirSchema ? url('/isletme/' . $slug) : null,
                'business_name' => $profile->business_name ?: $profile->user?->name,
                'name' => $profile->user?->name,
                'title' => $profile->title,
                'bio' => $profile->bio,
                'provider_type' => $profile->provider_type,
                'work_mode' => $profile->work_mode,
                'is_demo' => $isDemo,
                'is_verified' => $profile->isVerified(),
                'directory_listed' => $hasDirSchema ? (bool) $profile->getAttribute('directory_listed') : true,
                'directory_status' => $hasDirSchema ? (string) ($profile->getAttribute('directory_status') ?: 'APPROVED') : 'APPROVED',
                'accepts_tarak_bookings' => $acceptsTarakBookings,
                'is_online' => (bool) $profile->is_online,
                'discount_percent' => $discountPercent,
                'experience_years' => $profile->experience_years,
                'avatar_url' => MediaUrl::resolve($profile->user?->avatar_url),
                'logo_url' => $hasDirSchema ? MediaUrl::resolve($profile->getAttribute('logo_url')) : null,
                'cover_url' => MediaUrl::resolve($profile->cover_url),
                'pin_image_url' => $profile->pinImageUrl(),
                'gallery' => array_values(array_filter(array_map(fn ($u) => MediaUrl::resolve($u), $profile->gallery ?? []))),
                'city' => $profile->city,
                'district' => $profile->district,
                'neighborhood' => $hasPublicPin ? $profile->neighborhood : null,
                'street' => $hasPublicPin ? $profile->street : null,
                'building_no' => $hasPublicPin ? $profile->building_no : null,
                'address_detail' => $hasPublicPin ? $profile->address_detail : null,
                'formatted_address' => $profile->publicFormattedAddress(),
                'latitude' => $hasPublicPin ? (float) $profile->latitude : null,
                'longitude' => $hasPublicPin ? (float) $profile->longitude : null,
                'has_public_pin' => $hasPublicPin,
                'can_get_directions' => $hasPublicPin,
                'service_radius_km' => (int) ($profile->service_radius_km ?: 15),
                'service_areas' => $serviceAreas,
                'working_hours' => $workingHours,
                'closed_dates' => $closedDates,
                'services' => $activeServices,
                'packages' => $activePackages,
                'staff' => $visibleStaff,
                'service_count' => $activeServices->count(),
                'rating' => $ratingAvg,
                'review_count' => $reviewCount,
                'reviews' => $recentReviews,
            ],
        ]);
    }

    /**
     * @param Collection<int, ProviderProfile> $profiles
     * @return Collection<int, ProviderProfile>
     */
    private function applyLocationAndSearchFilters(
        Collection $profiles,
        string $city,
        string $district,
        string $neighborhood,
        string $q,
    ): Collection {
        $normCity = ProviderServiceArea::normalizePart($city);
        $normDistrict = ProviderServiceArea::normalizePart($district);
        $normNeighborhood = ProviderServiceArea::normalizePart($neighborhood);
        $normQ = ProviderServiceArea::normalizePart($q);

        return $profiles->filter(function (ProviderProfile $profile) use ($normCity, $normDistrict, $normNeighborhood, $normQ, $city, $district, $neighborhood) {
            $areas = $profile->relationLoaded('serviceAreas') ? $profile->serviceAreas : collect();

            if ($normCity !== '' || $normDistrict !== '' || $normNeighborhood !== '') {
                $profileCity = ProviderServiceArea::normalizePart($profile->city);
                $profileDistrict = ProviderServiceArea::normalizePart($profile->district);
                $profileNeighborhood = ProviderServiceArea::normalizePart($profile->neighborhood);

                $matchesProfile = ($normCity === '' || $profileCity === $normCity)
                    && ($normDistrict === '' || $profileDistrict === $normDistrict)
                    && ($normNeighborhood === '' || $profileNeighborhood === $normNeighborhood);

                $matchesArea = false;
                if ($normCity !== '' && $normDistrict !== '' && $areas->isNotEmpty()) {
                    $matchesArea = $this->areaMatcher->matchesExplicitArea($profile, $city, $district, $neighborhood !== '' ? $neighborhood : null);
                    if (!$matchesArea && $normNeighborhood === '') {
                        $matchesArea = $areas->contains(
                            fn (ProviderServiceArea $a) => str_starts_with($a->normalized_key, "{$normCity}|{$normDistrict}|")
                        );
                    }
                } elseif ($normCity !== '' && $areas->isNotEmpty()) {
                    $matchesArea = $areas->contains(
                        fn (ProviderServiceArea $a) => ProviderServiceArea::normalizePart($a->province) === $normCity
                    );
                } elseif ($normDistrict !== '' && $areas->isNotEmpty()) {
                    $matchesArea = $areas->contains(
                        fn (ProviderServiceArea $a) => ProviderServiceArea::normalizePart($a->district) === $normDistrict
                    );
                }

                if (!$matchesProfile && !$matchesArea) {
                    return false;
                }
            }

            if ($normQ !== '') {
                $parts = [
                    $profile->business_name,
                    $profile->user?->name,
                    $profile->title,
                    $profile->city,
                    $profile->district,
                    $profile->hasPublicVenuePin() ? $profile->neighborhood : null,
                ];
                foreach ($areas as $area) {
                    $parts[] = $area->province;
                    $parts[] = $area->district;
                    $parts[] = $area->neighborhood;
                }
                $services = $profile->relationLoaded('providerServices') ? $profile->providerServices : collect();
                foreach ($services as $ps) {
                    if ($ps->is_active && $ps->service) {
                        $parts[] = $ps->service->name;
                    }
                }
                $haystack = ProviderServiceArea::normalizePart(implode(' ', array_filter($parts)));
                if (!str_contains($haystack, $normQ)) {
                    return false;
                }
            }

            return true;
        })->values();
    }

    /**
     * @param Collection<int, ProviderProfile> $profiles
     * @param array{0: float, 1: float}|null $origin
     * @return Collection<int, array<string, mixed>>
     */
    private function presentSummaries(Collection $profiles, ?array $origin, bool $includeCoordinates, bool $hasDirSchema): Collection
    {
        if ($profiles->isEmpty()) {
            return collect();
        }

        $profileIds = $profiles->pluck('id')->all();
        $userIds = $profiles->pluck('user_id')->all();

        $verifiedProfileIds = [];
        foreach (array_chunk($profileIds, 400) as $chunk) {
            $ids = ProviderDocument::query()
                ->whereIn('provider_profile_id', $chunk)
                ->where('status', ProviderDocument::STATUS_APPROVED)
                ->whereIn('document_type', [
                    ProviderDocument::TYPE_DIPLOMA,
                    ProviderDocument::TYPE_MASTER_CERTIFICATE,
                    ProviderDocument::TYPE_JOURNEYMAN_CERTIFICATE,
                ])
                ->distinct()
                ->pluck('provider_profile_id');
            foreach ($ids as $id) {
                $verifiedProfileIds[(int) $id] = true;
            }
        }

        $reviewStats = collect();
        foreach (array_chunk($userIds, 400) as $chunk) {
            $rows = DB::table('provider_reviews')
                ->whereIn('provider_user_id', $chunk)
                ->groupBy('provider_user_id')
                ->selectRaw('provider_user_id, COUNT(*) as review_total, AVG(rating) as review_avg')
                ->get();
            foreach ($rows as $row) {
                $reviewStats->put($row->provider_user_id, $row);
            }
        }

        $serviceCounts = [];
        foreach (array_chunk($profileIds, 400) as $chunk) {
            $counts = ProviderService::query()
                ->whereIn('provider_profile_id', $chunk)
                ->where('is_active', true)
                ->groupBy('provider_profile_id')
                ->selectRaw('provider_profile_id, COUNT(*) as service_total')
                ->pluck('service_total', 'provider_profile_id');
            foreach ($counts as $pid => $cnt) {
                $serviceCounts[(int) $pid] = (int) $cnt;
            }
        }

        $globalAvg = (float) (DB::table('provider_reviews')->avg('rating') ?: 4.0);
        $m = self::SCORE_PRIOR_REVIEWS;

        $items = [];
        foreach ($profiles as $profile) {
            $isDemo = (bool) ($profile->user?->is_demo ?? false);
            $stat = $reviewStats->get($profile->user_id);
            $count = $stat ? (int) $stat->review_total : 0;
            $avg = $count > 0 ? round((float) $stat->review_avg, 2) : null;
            $score = (($count * ($avg ?? 0.0)) + $m * $globalAvg) / ($count + $m);
            $hasPin = $includeCoordinates && $profile->hasPublicVenuePin();

            $isApprovedAndDoc = ! $isDemo
                && (bool) $profile->is_approved
                && $profile->identity_status === 'APPROVED'
                && isset($verifiedProfileIds[(int) $profile->id]);

            $acceptsTarak = (bool) $profile->accepts_new_clients && $isApprovedAndDoc;
            $slug = $hasDirSchema
                ? (($profile->getAttribute('slug') ?: null) ?? (string) $profile->user_id)
                : (string) $profile->user_id;

            $logoUrl = $hasDirSchema ? MediaUrl::resolve($profile->getAttribute('logo_url')) : null;
            $avatarUrl = MediaUrl::resolve($profile->user?->avatar_url);
            $coverUrl = MediaUrl::resolve($profile->cover_url);
            $pinImageUrl = $logoUrl ?: $avatarUrl ?: $coverUrl;

            $areas = $profile->relationLoaded('serviceAreas')
                ? $profile->serviceAreas->map(fn ($a) => [
                    'province' => $a->province,
                    'district' => $a->district,
                    'neighborhood' => $a->neighborhood,
                ])->values()->all()
                : [];

            $items[] = [
                'id' => (string) $profile->id,
                'user_id' => (string) $profile->user_id,
                'slug' => (string) $slug,
                'public_url' => $hasDirSchema ? url('/isletme/' . $slug) : null,
                'business_name' => $profile->business_name ?: $profile->user?->name,
                'name' => $profile->user?->name,
                'provider_type' => $profile->provider_type,
                'work_mode' => $profile->work_mode,
                'is_demo' => $isDemo,
                'pin_image_url' => $pinImageUrl,
                'logo_url' => $logoUrl,
                'avatar_url' => $avatarUrl,
                'cover_url' => $coverUrl,
                'rating' => $avg,
                'review_count' => $count,
                'is_verified' => $isApprovedAndDoc,
                'accepts_tarak_bookings' => $acceptsTarak,
                'is_online' => (bool) $profile->is_online,
                'city' => $profile->city,
                'district' => $profile->district,
                'neighborhood' => $hasPin ? $profile->neighborhood : null,
                'formatted_address' => $profile->publicFormattedAddress(),
                'latitude' => $hasPin ? (float) $profile->latitude : null,
                'longitude' => $hasPin ? (float) $profile->longitude : null,
                'has_public_pin' => $hasPin,
                'can_get_directions' => $hasPin,
                'distance_km' => ($hasPin && $origin) ? Geo::distanceKm($origin[0], $origin[1], $profile->latitude, $profile->longitude) : null,
                'service_count' => (int) ($serviceCounts[(int) $profile->id] ?? 0),
                'service_radius_km' => (int) ($profile->service_radius_km ?: 15),
                'service_areas' => $areas,
                '_tarak_score' => $score,
            ];
        }

        if (!$origin && count($items) > 1) {
            usort($items, static function (array $a, array $b): int {
                $cmp = $b['_tarak_score'] <=> $a['_tarak_score'];

                return $cmp !== 0 ? $cmp : ($b['review_count'] <=> $a['review_count']);
            });
        }

        foreach ($items as &$item) {
            unset($item['_tarak_score']);
        }
        unset($item);

        return collect($items);
    }

    /**
     * Public turn-by-turn road routing endpoint for Tarak Harita.
     */
    public function route(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'origin_lat' => ['required', 'numeric', 'between:-90,90'],
            'origin_lng' => ['required', 'numeric', 'between:-180,180'],
            'dest_lat' => ['required', 'numeric', 'between:-90,90'],
            'dest_lng' => ['required', 'numeric', 'between:-180,180'],
            'profile' => ['nullable', 'in:driving,walking'],
        ]);

        $result = $this->routingService->calculateRoute(
            (float) $validated['origin_lat'],
            (float) $validated['origin_lng'],
            (float) $validated['dest_lat'],
            (float) $validated['dest_lng'],
            (string) ($validated['profile'] ?? 'driving'),
        );

        return match ($result['status']) {
            'OK' => response()->json([
                'success' => true,
                'data' => [
                    'provider' => $result['provider'],
                    'profile' => $result['profile'],
                    'cached' => $result['cached'] ?? false,
                    'distance_meters' => $result['distance_meters'],
                    'duration_seconds' => $result['duration_seconds'],
                    'geometry' => $result['geometry'],
                    'bounds' => $result['bounds'],
                ],
            ]),
            'NO_ROUTE' => response()->json([
                'success' => false,
                'code' => 'NO_ROUTE',
                'message' => $result['message'] ?? 'Mevcut konumunuzdan bu işletmeye kara yolu rotası hesaplanamadı.',
            ], 422),
            default => response()->json([
                'success' => false,
                'code' => $result['status'],
                'message' => $result['message'] ?? 'Yol tarifi servisine şu anda ulaşılamıyor.',
            ], 503),
        };
    }
}
