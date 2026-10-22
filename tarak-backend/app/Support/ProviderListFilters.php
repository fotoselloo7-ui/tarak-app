<?php

namespace App\Support;

use App\Models\User;
use Illuminate\Http\Request;

/**
 * The filters every provider list understands, read the same way by every endpoint
 * (public Hizmet Verenler list, the appointment provider step, the per-service "Uzmanlar" list):
 *
 *   q                 name / business / city / district search
 *   min_rating        minimum star average (0-5)
 *   lat, lng          where the customer is (default address or device); adds `distance_km` to each card
 *   max_distance_km   only providers within this radius (needs lat + lng)
 *   sort              relevance | rating | distance | reviews | newest
 *   preview=1         a signed-in provider checking their own list ad (see ListingAdService)
 */
final class ProviderListFilters
{
    public const SORTS = ['relevance', 'rating', 'distance', 'reviews', 'newest', 'price'];

    /**
     * @param array<int, int> $serviceIds
     * @return array<string, mixed> context for ListingAdService::sponsored() plus the sort
     */
    public static function fromRequest(Request $request, ?string $type = null, array $serviceIds = [], ?array $origin = null): array
    {
        $term = trim((string) $request->query('q', ''));
        $sort = (string) $request->query('sort', 'relevance');

        return [
            'type' => in_array($type, ['barber', 'coiffeur'], true) ? $type : null,
            'service_ids' => array_values(array_unique(array_map('intval', $serviceIds))),
            'term' => $term !== '' ? mb_substr($term, 0, 80) : null,
            'min_rating' => max(0.0, min((float) $request->query('min_rating', 0), 5.0)),
            'origin' => $origin ?? Geo::origin($request),
            'max_distance_km' => Geo::maxDistance($request),
            'sort' => in_array($sort, self::SORTS, true) ? $sort : 'relevance',
            'seed' => self::seed($request),
            'preview_provider_id' => self::previewProviderId($request),
        ];
    }

    /** Stable per customer (signed in) or per visitor (IP + browser), so a browsing session sees one sponsored set. */
    public static function seed(Request $request): string
    {
        $user = $request->user('sanctum');

        return $user ? 'u' . $user->id : 'g' . substr(sha1($request->ip() . '|' . $request->userAgent()), 0, 12);
    }

    /** Only a signed-in provider may preview, and only their own ad. */
    public static function previewProviderId(Request $request): ?int
    {
        if (!$request->boolean('preview')) {
            return null;
        }
        $user = $request->user('sanctum');

        return $user && $user->role === User::ROLE_PROVIDER ? (int) $user->id : null;
    }
}
