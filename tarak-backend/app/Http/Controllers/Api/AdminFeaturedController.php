<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AdminLog;
use App\Models\FeaturedPackage;
use App\Models\FeaturedPlacementSetting;
use App\Models\FeaturedPromotion;
use App\Models\User;
use App\Services\FeaturedPromotionService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/** Admin: price the "öne çıkarma" packages, see who is featured, gift or stop a period. */
class AdminFeaturedController extends Controller
{
    public function __construct(private FeaturedPromotionService $featured) {}

    public function summary(Request $request): JsonResponse
    {
        $placement = $this->placement($request);
        $paid = FeaturedPromotion::query()->placement($placement)->whereIn('source', FeaturedPromotion::PAID_SOURCES);

        return response()->json(['success' => true, 'data' => [
            'placement' => $placement,
            'active' => FeaturedPromotion::query()->active()->placement($placement)->distinct()->count('provider_user_id'),
            'upcoming' => FeaturedPromotion::query()->upcoming()->placement($placement)->count(),
            'revenue_total' => (float) (clone $paid)->sum('price_paid'),
            'revenue_30d' => (float) (clone $paid)->where('created_at', '>=', now()->subDays(30))->sum('price_paid'),
            'purchases_30d' => (clone $paid)->where('created_at', '>=', now()->subDays(30))->count(),
        ]]);
    }

    // ------------------------------------------------------------ packages

    public function packages(Request $request): JsonResponse
    {
        $rows = FeaturedPackage::query()
            ->placement($this->placement($request))
            ->withCount(['promotions' => fn ($q) => $q->whereIn('source', FeaturedPromotion::PAID_SOURCES)]) // paid purchases only, not gifts
            ->orderBy('sort_order')->orderBy('duration_days')->get()
            ->map(fn (FeaturedPackage $p) => $p->present() + ['purchases' => $p->promotions_count]);

        return response()->json(['success' => true, 'data' => $rows->values()]);
    }

    public function storePackage(Request $request): JsonResponse
    {
        $package = FeaturedPackage::create($this->validatedPackage($request, true));
        AdminLog::logAction((int) $request->user()->id, AdminLog::ACTION_FEATURED_PACKAGE_SAVED, AdminLog::TARGET_FEATURED, (int) $package->id, ['created' => true, 'price' => (float) $package->price, 'days' => $package->duration_days]);

        return response()->json(['success' => true, 'message' => 'Paket eklendi.', 'data' => $package->present()], 201);
    }

    public function updatePackage(Request $request, int $id): JsonResponse
    {
        $package = FeaturedPackage::query()->findOrFail($id);
        $package->update($this->validatedPackage($request));
        AdminLog::logAction((int) $request->user()->id, AdminLog::ACTION_FEATURED_PACKAGE_SAVED, AdminLog::TARGET_FEATURED, (int) $package->id, ['price' => (float) $package->price, 'days' => $package->duration_days, 'active' => $package->is_active]);

        return response()->json(['success' => true, 'message' => 'Paket güncellendi.', 'data' => $package->present()]);
    }

    /** Past purchases keep their own snapshot (name/days/price), so a package can be removed safely. */
    public function destroyPackage(Request $request, int $id): JsonResponse
    {
        $package = FeaturedPackage::query()->findOrFail($id);
        $package->delete();
        AdminLog::logAction((int) $request->user()->id, AdminLog::ACTION_FEATURED_PACKAGE_DELETED, AdminLog::TARGET_FEATURED, $id, ['name' => $package->name]);

        return response()->json(['success' => true, 'message' => 'Paket silindi.']);
    }

    // ---------------------------------------------------------- promotions

    public function promotions(Request $request): JsonResponse
    {
        $status = (string) $request->query('status', 'active');
        $query = FeaturedPromotion::query()->placement($this->placement($request))->with('provider:id,name,email,phone,is_demo', 'provider.providerProfile:id,user_id,business_name,city,provider_type');

        match ($status) {
            'active' => $query->active(),
            'upcoming' => $query->upcoming(),
            'expired' => $query->whereNull('cancelled_at')->where('ends_at', '<=', now()),
            'cancelled' => $query->whereNotNull('cancelled_at'),
            default => null,
        };

        if ($term = trim((string) $request->query('q', ''))) {
            $query->whereHas('provider', fn ($q) => $q->where('name', 'like', "%{$term}%")->orWhere('email', 'like', "%{$term}%")
                ->orWhereHas('providerProfile', fn ($p) => $p->where('business_name', 'like', "%{$term}%")));
        }

        $page = $query->orderByDesc('ends_at')->paginate(min(max((int) $request->query('per_page', 25), 1), 100));

        $data = collect($page->items())->map(fn (FeaturedPromotion $p) => $p->present() + [
            'provider' => [
                'id' => $p->provider?->id,
                'name' => $p->provider?->providerProfile?->business_name ?: $p->provider?->name,
                'owner' => $p->provider?->name,
                'city' => $p->provider?->providerProfile?->city,
                'is_demo' => (bool) $p->provider?->is_demo,
            ],
        ]);

        return response()->json([
            'success' => true,
            'data' => $data->values(),
            'meta' => ['current_page' => $page->currentPage(), 'last_page' => $page->lastPage(), 'total' => $page->total()],
        ]);
    }

    /** Gift / campaign period (no wallet movement). */
    public function grant(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'provider_user_id' => ['required', 'integer', 'exists:users,id'],
            'package_id' => ['nullable', 'integer', 'exists:featured_packages,id'],
            'placement' => ['sometimes', 'string', 'in:' . implode(',', FeaturedPromotion::PLACEMENTS)],
            'days' => ['required_without:package_id', 'nullable', 'integer', 'min:1', 'max:730'],
            'note' => ['nullable', 'string', 'max:200'],
        ], [
            'provider_user_id.required' => 'Hizmet veren seçin.',
            'provider_user_id.exists' => 'Hizmet veren bulunamadı.',
            'days.required_without' => 'Gün sayısı veya paket seçin.',
        ]);

        $provider = User::query()->where('role', User::ROLE_PROVIDER)->find($validated['provider_user_id']);
        if (!$provider) {
            return response()->json(['success' => false, 'message' => 'Seçilen kullanıcı bir hizmet veren değil.'], 422);
        }

        $package = isset($validated['package_id']) ? FeaturedPackage::query()->find($validated['package_id']) : null;
        $days = (int) ($validated['days'] ?? $package?->duration_days ?? 1);
        $promotion = $this->featured->grant($provider, $days, (int) $request->user()->id, $package, $validated['note'] ?? null, $validated['placement'] ?? null);

        AdminLog::logAction((int) $request->user()->id, AdminLog::ACTION_FEATURED_GRANTED, AdminLog::TARGET_FEATURED, (int) $promotion->id, ['provider_user_id' => $provider->id, 'days' => $days, 'placement' => $promotion->placement]);

        return response()->json(['success' => true, 'message' => 'Öne çıkarma tanımlandı.', 'data' => $promotion->present()], 201);
    }

    public function cancel(Request $request, int $id): JsonResponse
    {
        $promotion = FeaturedPromotion::query()->findOrFail($id);
        $this->featured->cancel($promotion);
        AdminLog::logAction((int) $request->user()->id, AdminLog::ACTION_FEATURED_CANCELLED, AdminLog::TARGET_FEATURED, $id, ['provider_user_id' => $promotion->provider_user_id]);

        return response()->json(['success' => true, 'message' => 'Öne çıkarma durduruldu.', 'data' => $promotion->refresh()->present()]);
    }

    // ------------------------------------------------------------ placements

    /** Both placements with their admin settings and live numbers. */
    public function placements(): JsonResponse
    {
        $rows = collect(FeaturedPromotion::PLACEMENTS)->map(fn (string $key) => FeaturedPlacementSetting::for($key)->present() + [
            'active' => FeaturedPromotion::query()->active()->placement($key)->distinct()->count('provider_user_id'),
            'upcoming' => FeaturedPromotion::query()->upcoming()->placement($key)->count(),
            'packages' => FeaturedPackage::query()->placement($key)->where('is_active', true)->count(),
        ]);

        return response()->json(['success' => true, 'data' => $rows->values()]);
    }

    /** Open / close sales of a placement, slot count and rotation of the list ad, the copy providers read. */
    public function updatePlacement(Request $request, string $placement): JsonResponse
    {
        abort_unless(in_array($placement, FeaturedPromotion::PLACEMENTS, true), 404);

        $validated = $request->validate([
            'is_enabled' => ['sometimes', 'boolean'],
            'slots' => ['sometimes', 'integer', 'min:1', 'max:6'],
            'rotation_seconds' => ['sometimes', 'integer', 'min:5', 'max:3600'],
            'title' => ['sometimes', 'string', 'max:80'],
            'description' => ['sometimes', 'nullable', 'string', 'max:400'],
        ], [
            'slots.min' => 'En az 1 yuva olmalıdır.',
            'slots.max' => 'En fazla 6 yuva tanımlanabilir.',
            'rotation_seconds.min' => 'Dönüş süresi en az 5 saniye olmalıdır.',
        ]);

        $setting = FeaturedPlacementSetting::for($placement);
        $setting->update($validated);
        AdminLog::logAction((int) $request->user()->id, AdminLog::ACTION_FEATURED_PACKAGE_SAVED, AdminLog::TARGET_FEATURED, (int) $setting->id, ['placement' => $placement] + $validated);

        return response()->json(['success' => true, 'message' => 'Reklam alanı ayarları kaydedildi.', 'data' => $setting->refresh()->present()]);
    }

    private function placement(Request $request): string
    {
        $placement = (string) $request->query('placement', FeaturedPromotion::PLACEMENT_HOME);

        return in_array($placement, FeaturedPromotion::PLACEMENTS, true) ? $placement : FeaturedPromotion::PLACEMENT_HOME;
    }

    private function validatedPackage(Request $request, bool $creating = false): array
    {
        $rules = $creating ? ['placement' => ['sometimes', 'string', 'in:' . implode(',', FeaturedPromotion::PLACEMENTS)]] : [];

        return $request->validate($rules + [
            'name' => ['required', 'string', 'max:80'],
            'description' => ['nullable', 'string', 'max:200'],
            'badge' => ['nullable', 'string', 'max:40'],
            'duration_days' => ['required', 'integer', 'min:1', 'max:730'],
            'price' => ['required', 'numeric', 'min:0', 'max:1000000'],
            'is_active' => ['sometimes', 'boolean'],
            'sort_order' => ['sometimes', 'integer', 'min:0', 'max:1000'],
        ], [
            'name.required' => 'Paket adı zorunludur.',
            'duration_days.required' => 'Gün sayısı zorunludur.',
            'duration_days.min' => 'Gün sayısı en az 1 olmalıdır.',
            'price.required' => 'Fiyat zorunludur.',
        ]);
    }
}
