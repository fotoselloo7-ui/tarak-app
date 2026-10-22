<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\CustomerFavorite;
use App\Models\ProviderReview;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class FavoriteController extends Controller
{
    /**
     * Customer: list favourite providers with basic profile + rating.
     */
    public function index(Request $request): JsonResponse
    {
        $favorites = CustomerFavorite::query()
            ->where('customer_user_id', $request->user()->id)
            ->with(['provider:id,name', 'provider.providerProfile.documents'])
            ->latest()
            ->get()
            ->map(function (CustomerFavorite $f) {
                $p = $f->provider;
                $profile = $p?->providerProfile;
                $count = ProviderReview::query()->where('provider_user_id', $p?->id)->count();
                $avg = $count > 0
                    ? round((float) ProviderReview::query()->where('provider_user_id', $p?->id)->avg('rating'), 2)
                    : 0.0;

                return [
                    'provider_user_id' => $p?->id,
                    'name' => $p?->name,
                    'business_name' => $profile?->business_name,
                    'is_verified' => (bool) ($profile?->isVerified() ?? false),
                    'city' => $profile?->city,
                    'district' => $profile?->district,
                    'rating_average' => $avg,
                    'rating_count' => $count,
                ];
            })
            ->filter(fn ($row) => $row['provider_user_id'] !== null)
            ->values();

        return response()->json(['success' => true, 'data' => $favorites]);
    }

    /**
     * Customer: add a provider to favourites (idempotent).
     */
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'provider_user_id' => ['required', 'integer'],
        ]);

        $provider = User::query()
            ->where('id', $validated['provider_user_id'])
            ->where('role', User::ROLE_PROVIDER)
            ->first();
        if (! $provider) {
            return response()->json(['success' => false, 'message' => 'Hizmet veren bulunamadı.'], 404);
        }

        CustomerFavorite::query()->firstOrCreate([
            'customer_user_id' => $request->user()->id,
            'provider_user_id' => $provider->id,
        ]);

        return response()->json(['success' => true, 'message' => 'Favorilere eklendi.', 'data' => ['is_favorite' => true]]);
    }

    /**
     * Customer: remove a provider from favourites.
     */
    public function destroy(Request $request, int $provider): JsonResponse
    {
        CustomerFavorite::query()
            ->where('customer_user_id', $request->user()->id)
            ->where('provider_user_id', $provider)
            ->delete();

        return response()->json(['success' => true, 'message' => 'Favorilerden çıkarıldı.', 'data' => ['is_favorite' => false]]);
    }
}
