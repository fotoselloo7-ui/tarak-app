<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\ProviderProfile;
use App\Models\ProviderReview;
use App\Models\ProviderService;
use App\Models\ProviderServiceArea;
use App\Support\MediaUrl;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Pagination\LengthAwarePaginator;
use Illuminate\Support\Facades\DB;
use Illuminate\View\View;

class BusinessDirectoryWebController extends Controller
{
    private const DAY_LABELS = [
        'monday' => ['label' => 'Pazartesi', 'schema' => 'Monday'],
        'tuesday' => ['label' => 'Salı', 'schema' => 'Tuesday'],
        'wednesday' => ['label' => 'Çarşamba', 'schema' => 'Wednesday'],
        'thursday' => ['label' => 'Perşembe', 'schema' => 'Thursday'],
        'friday' => ['label' => 'Cuma', 'schema' => 'Friday'],
        'saturday' => ['label' => 'Cumartesi', 'schema' => 'Saturday'],
        'sunday' => ['label' => 'Pazar', 'schema' => 'Sunday'],
    ];

    public function index(Request $request): View
    {
        $q = trim((string) $request->query('q', ''));
        $city = trim((string) $request->query('city', ''));
        $type = in_array($request->query('type'), ['barber', 'coiffeur'], true)
            ? (string) $request->query('type')
            : null;

        $allProfiles = ProviderProfile::query()
            ->directoryListedPublic()
            ->with(['user', 'documents', 'serviceAreas', 'providerServices.service'])
            ->when($type, fn ($query) => $query->where('provider_type', $type))
            ->orderByDesc('directory_approved_at')
            ->orderBy('id')
            ->get();

        $normQ = ProviderServiceArea::normalizePart($q);
        $normCity = ProviderServiceArea::normalizePart($city);

        $filtered = $allProfiles->filter(function (ProviderProfile $profile) use ($normQ, $normCity) {
            if ($normCity !== '') {
                $cityMatches = ProviderServiceArea::normalizePart($profile->city) === $normCity
                    || $profile->serviceAreas->contains(fn ($a) => ProviderServiceArea::normalizePart($a->province) === $normCity);
                if (!$cityMatches) {
                    return false;
                }
            }

            if ($normQ !== '') {
                $parts = [
                    $profile->business_name,
                    $profile->user?->name,
                    $profile->city,
                    $profile->district,
                    $profile->hasPublicVenuePin() ? $profile->neighborhood : null,
                ];
                foreach ($profile->serviceAreas as $area) {
                    $parts[] = $area->province;
                    $parts[] = $area->district;
                    $parts[] = $area->neighborhood;
                }
                foreach ($profile->providerServices as $ps) {
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

        foreach ($filtered as $profile) {
            if (empty($profile->slug)) {
                $profile->ensureSlug();
                $profile->saveQuietly();
            }
        }

        $perPage = 24;
        $page = max(1, (int) $request->query('page', 1));
        $slice = $filtered->slice(($page - 1) * $perPage, $perPage)->values();

        $reviewStats = $slice->isEmpty()
            ? collect()
            : ProviderReview::query()
                ->whereIn('provider_user_id', $slice->pluck('user_id'))
                ->groupBy('provider_user_id')
                ->selectRaw('provider_user_id, COUNT(*) as review_total, AVG(rating) as review_avg')
                ->get()
                ->keyBy('provider_user_id');

        $businesses = new LengthAwarePaginator(
            $slice,
            $filtered->count(),
            $perPage,
            $page,
            ['path' => $request->url(), 'query' => $request->query()]
        );

        $mapPins = $filtered
            ->filter(fn (ProviderProfile $p) => $p->hasPublicVenuePin())
            ->take(200)
            ->map(fn (ProviderProfile $p) => [
                'name' => $p->business_name ?: $p->user?->name,
                'slug' => $p->slug,
                'url' => url('/isletme/' . $p->slug),
                'type' => $p->provider_type,
                'address' => $p->publicFormattedAddress(),
                'lat' => (float) $p->latitude,
                'lng' => (float) $p->longitude,
                'image' => $p->pinImageUrl(),
            ])
            ->values();

        $cities = $allProfiles->pluck('city')->filter()->unique()->sort()->values();

        return view('directory.index', [
            'businesses' => $businesses,
            'reviewStats' => $reviewStats,
            'mapPins' => $mapPins,
            'cities' => $cities,
            'q' => $q,
            'city' => $city,
            'type' => $type,
            'canonicalUrl' => url('/isletmeler'),
        ]);
    }

    public function show(string $slug): View|\Illuminate\Http\RedirectResponse
    {
        $query = ProviderProfile::query()->with([
            'user',
            'documents',
            'serviceAreas',
            'weeklySchedules.breaks',
            'providerServices.service',
            'packages.services',
        ]);

        if (ctype_digit($slug)) {
            $byUser = (clone $query)->where('user_id', (int) $slug)->first();
            if ($byUser && $this->isPubliclyViewable($byUser)) {
                $byUser->ensureSlug();
                if ($byUser->isDirty('slug')) {
                    $byUser->saveQuietly();
                }

                return redirect('/isletme/' . $byUser->slug, 301);
            }
        }

        $profile = $query->where('slug', $slug)->first();
        if (!$profile || !$this->isPubliclyViewable($profile)) {
            abort(404);
        }

        $reviewQuery = ProviderReview::query()->where('provider_user_id', $profile->user_id);
        $reviewCount = (clone $reviewQuery)->count();
        $ratingAvg = $reviewCount > 0 ? round((float) (clone $reviewQuery)->avg('rating'), 2) : null;
        $reviews = (clone $reviewQuery)->with('customer:id,name')->latest()->limit(10)->get();

        $activeServices = $profile->providerServices
            ->filter(fn (ProviderService $ps) => $ps->is_active && $ps->service && $ps->service->is_active)
            ->values();

        $activePackages = $profile->packages
            ->filter(fn ($pkg) => $pkg->is_active && $pkg->services->isNotEmpty())
            ->values();

        $scheduleMap = $profile->weeklySchedules->keyBy(fn ($s) => strtolower((string) $s->day_of_week));
        $workingHours = collect(self::DAY_LABELS)->map(function (array $meta, string $dayKey) use ($scheduleMap) {
            $row = $scheduleMap->get($dayKey);

            return [
                'day' => $dayKey,
                'label' => $meta['label'],
                'schema_day' => $meta['schema'],
                'enabled' => $row ? (bool) $row->is_enabled : false,
                'start_time' => $row?->start_time ? substr($row->start_time, 0, 5) : null,
                'end_time' => $row?->end_time ? substr($row->end_time, 0, 5) : null,
            ];
        })->values();

        $hasPublicPin = $profile->hasPublicVenuePin();
        $displayName = $profile->business_name ?: ($profile->user?->name ?: 'İşletme');
        $typeLabel = $profile->provider_type === 'coiffeur' ? 'Kadın Kuaförü' : 'Erkek Berberi';
        $canonicalUrl = url('/isletme/' . $profile->slug);
        $publicAddress = $profile->publicFormattedAddress();

        $schema = [
            '@context' => 'https://schema.org',
            '@type' => $profile->provider_type === 'coiffeur' ? 'HairSalon' : 'BarberShop',
            'name' => $displayName,
            'url' => $canonicalUrl,
            'description' => $profile->bio ?: "{$displayName} - {$typeLabel} ({$profile->district}, {$profile->city})",
        ];

        if ($image = ($profile->pinImageUrl() ?: MediaUrl::resolve($profile->cover_url))) {
            $schema['image'] = $image;
        }

        if ($hasPublicPin) {
            $streetLine = trim(implode(' ', array_filter([$profile->street, $profile->building_no])));
            $schema['address'] = array_filter([
                '@type' => 'PostalAddress',
                'streetAddress' => $streetLine !== '' ? $streetLine : $profile->address_detail,
                'addressLocality' => $profile->district,
                'addressRegion' => $profile->city,
                'addressCountry' => 'TR',
            ]);
            $schema['geo'] = [
                '@type' => 'GeoCoordinates',
                'latitude' => (float) $profile->latitude,
                'longitude' => (float) $profile->longitude,
            ];
        } else {
            $areas = $profile->serviceAreas
                ->map(fn ($a) => trim(implode(', ', array_filter([$a->neighborhood, $a->district, $a->province]))))
                ->filter()
                ->values()
                ->all();
            if ($areas === [] && ($profile->district || $profile->city)) {
                $areas = [trim(implode(', ', array_filter([$profile->district, $profile->city])))];
            }
            if ($areas !== []) {
                $schema['areaServed'] = $areas;
            }
        }

        $openingSpecs = $workingHours
            ->filter(fn ($wh) => $wh['enabled'] && $wh['start_time'] && $wh['end_time'])
            ->map(fn ($wh) => [
                '@type' => 'OpeningHoursSpecification',
                'dayOfWeek' => 'https://schema.org/' . $wh['schema_day'],
                'opens' => $wh['start_time'],
                'closes' => $wh['end_time'],
            ])->values()->all();
        if ($openingSpecs !== []) {
            $schema['openingHoursSpecification'] = $openingSpecs;
        }

        if ($reviewCount > 0 && $ratingAvg !== null) {
            $schema['aggregateRating'] = [
                '@type' => 'AggregateRating',
                'ratingValue' => $ratingAvg,
                'reviewCount' => $reviewCount,
            ];
        }

        if ($activeServices->isNotEmpty()) {
            $schema['hasOfferCatalog'] = [
                '@type' => 'OfferCatalog',
                'name' => 'Hizmetler',
                'itemListElement' => $activeServices->map(fn (ProviderService $ps) => [
                    '@type' => 'Offer',
                    'priceCurrency' => 'TRY',
                    'price' => $ps->effectivePrice(),
                    'itemOffered' => [
                        '@type' => 'Service',
                        'name' => $ps->service->name,
                    ],
                ])->all(),
            ];
        }

        return view('directory.show', [
            'profile' => $profile,
            'displayName' => $displayName,
            'typeLabel' => $typeLabel,
            'canonicalUrl' => $canonicalUrl,
            'hasPublicPin' => $hasPublicPin,
            'publicAddress' => $publicAddress,
            'workingHours' => $workingHours,
            'activeServices' => $activeServices,
            'activePackages' => $activePackages,
            'ratingAvg' => $ratingAvg,
            'reviewCount' => $reviewCount,
            'reviews' => $reviews,
            'gallery' => array_values(array_filter(array_map(fn ($u) => MediaUrl::resolve($u), $profile->gallery ?? []))),
            'schemaJson' => json_encode($schema, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT),
        ]);
    }

    public function sitemap(): Response
    {
        $profiles = ProviderProfile::query()
            ->whereNotNull('slug')
            ->where('directory_status', '!=', ProviderProfile::DIRECTORY_SUSPENDED)
            ->where(function ($q) {
                $q->where(function ($dir) {
                    $dir->where('directory_listed', true)
                        ->where('directory_status', ProviderProfile::DIRECTORY_APPROVED);
                })->orWhere(function ($prov) {
                    $prov->where('is_approved', true)
                        ->where('identity_status', 'APPROVED');
                });
            })
            ->whereHas('user', fn ($u) => $u->where('role', 'PROVIDER')->where('status', 'active'))
            ->select(['slug', 'updated_at'])
            ->orderBy('id')
            ->get();

        $urls = [
            ['loc' => url('/'), 'lastmod' => now()->toAtomString()],
            ['loc' => url('/isletmeler'), 'lastmod' => now()->toAtomString()],
        ];

        foreach ($profiles as $profile) {
            if (!empty($profile->slug)) {
                $urls[] = [
                    'loc' => url('/isletme/' . $profile->slug),
                    'lastmod' => ($profile->updated_at ?? now())->toAtomString(),
                ];
            }
        }

        $xml = '<?xml version="1.0" encoding="UTF-8"?>' . "\n";
        $xml .= '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">' . "\n";
        foreach ($urls as $u) {
            $xml .= "  <url>\n";
            $xml .= '    <loc>' . htmlspecialchars($u['loc'], ENT_XML1 | ENT_QUOTES, 'UTF-8') . "</loc>\n";
            $xml .= '    <lastmod>' . htmlspecialchars($u['lastmod'], ENT_XML1 | ENT_QUOTES, 'UTF-8') . "</lastmod>\n";
            $xml .= "  </url>\n";
        }
        $xml .= '</urlset>';

        return response($xml, 200, ['Content-Type' => 'application/xml; charset=UTF-8']);
    }

    private function isPubliclyViewable(ProviderProfile $profile): bool
    {
        if (!$profile->user || $profile->user->status !== 'active') {
            return false;
        }
        if ($profile->directory_status === ProviderProfile::DIRECTORY_SUSPENDED) {
            return false;
        }

        return $profile->isDirectoryPubliclyVisible()
            || ($profile->is_approved && $profile->identity_status === 'APPROVED');
    }
}
