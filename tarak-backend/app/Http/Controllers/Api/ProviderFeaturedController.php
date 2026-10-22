<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\FeaturedOrder;
use App\Models\FeaturedPackage;
use App\Models\FeaturedPlacementSetting;
use App\Models\FeaturedPromotion;
use App\Models\NotificationAdSetting;
use App\Models\ProviderProfile;
use App\Models\User;
use App\Models\Wallet;
use App\Services\FeaturedOrderService;
use App\Services\FeaturedPromotionService;
use App\Services\ListingAdService;
use App\Services\ProviderDiscountService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Provider side of "öne çıkarma": see the packages, buy one (wallet balance OR card via
 * PayTR), see the status.
 */
class ProviderFeaturedController extends Controller
{
    public function __construct(
        private FeaturedPromotionService $featured,
        private FeaturedOrderService $orders,
        private ListingAdService $listingAds,
    ) {
    }

    public function show(Request $request): JsonResponse
    {
        return response()->json(['success' => true, 'data' => $this->payload($request)]);
    }

    /**
     * `payment_method`: "wallet" (default) debits the wallet cash balance and starts the period
     * at once; "card" opens a PayTR payment (iFrame token) — the period starts when PayTR confirms it.
     */
    public function purchase(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'package_id' => ['required', 'integer', 'exists:featured_packages,id'],
            'payment_method' => ['sometimes', 'string', 'in:wallet,card'],
        ], [
            'package_id.required' => 'Lütfen bir paket seçin.',
            'package_id.exists' => 'Paket bulunamadı.',
            'payment_method.in' => 'Ödeme yöntemi geçersiz.',
        ]);

        $package = FeaturedPackage::query()->findOrFail($validated['package_id']);

        if (($validated['payment_method'] ?? 'wallet') === 'card') {
            $started = $this->orders->startCardOrder($request->user(), $package, $request->ip());

            return response()->json([
                'success' => true,
                'message' => 'Ödeme oturumu hazırlandı.',
                'data' => [
                    'payment_method' => 'card',
                    'order' => $started['order']->present(),
                    'token' => $started['token'],
                    'iframe_url' => $started['iframe_url'],
                ],
            ], 201);
        }

        $promotion = $this->featured->purchase($request->user(), $package);

        return response()->json([
            'success' => true,
            'message' => 'Öne çıkarma paketiniz aktif edildi.',
            'data' => $this->payload($request) + ['payment_method' => 'wallet', 'purchased' => $promotion->present()],
        ], 201);
    }

    /** Polled while the card payment window is open. */
    public function orderStatus(Request $request, int $id): JsonResponse
    {
        $order = FeaturedOrder::query()->where('provider_user_id', $request->user()->id)->findOrFail($id);
        $order = $this->orders->refresh($order);

        return response()->json(['success' => true, 'data' => $order->load('promotion')->present() + [
            'featured' => $order->status === FeaturedOrder::STATUS_PAID ? $this->payload($request)['status'] : null,
        ]]);
    }

    /**
     * "Is my ad really running?": the provider's own view of every placement, plus how the list ad is
     * shared (slots, rotation, rivals). The clients pair it with the customer view (preview=1 lists).
     */
    public function visibility(Request $request): JsonResponse
    {
        $user = $request->user();
        $profile = ProviderProfile::query()->where('user_id', $user->id)->first();
        $listing = FeaturedPlacementSetting::for(FeaturedPromotion::PLACEMENT_LISTING);

        return response()->json(['success' => true, 'data' => [
            'home' => $this->featured->statusFor($user, FeaturedPromotion::PLACEMENT_HOME),
            'listing' => $this->featured->statusFor($user, FeaturedPromotion::PLACEMENT_LISTING) + [
                'running' => $this->listingAds->isRunning($user->id),
                'slots' => $listing->slots,
                'rotation_seconds' => $listing->rotation_seconds,
                'competitors' => $profile ? $this->listingAds->competitors($profile) : 0,
            ],
        ]]);
    }

    /** Static description of where each placement is shown (the clients pair it with a fixed screenshot). */
    private function placementPayload(\App\Models\User $user, string $placement): array
    {
        $settings = FeaturedPlacementSetting::for($placement);
        $listing = $placement === FeaturedPromotion::PLACEMENT_LISTING;

        return $settings->present() + [
            'where' => $listing
                ? [
                    'Randevu alırken "Hizmet Veren Seçimi" listesinin en üstü',
                    'Bir hizmetin "Uzmanlar" listesinin en üstü',
                    'Hizmet Verenler listelerinin en üstü (web ve mobil)',
                ]
                : [
                    'Ana sayfada "Öne Çıkan Profesyoneller" bölümü (kategorilerin hemen altı)',
                    'Giriş yapmış müşterilerin ana sayfası',
                ],
            'how' => $listing
                ? [
                    sprintf('Aynı anda en fazla %d hizmet veren listenin en üstünde "Önerilen" olarak görünür.', $settings->slots),
                    sprintf('Öneriler müşterinin aradığı hizmete, aramasına, puan ve mesafe filtresine uyan hizmet verenler arasından her %d saniyede bir yeniden seçilir; reklamı olan herkes sırayla görünür.', max(1, $settings->rotation_seconds)),
                    'Tarak puanın yüksekse ve müşteriye yakınsan görünme şansın artar.',
                ]
                : [
                    'Tüm ziyaretçiler görür; öne çıkanlar sırayla dönerek gösterilir.',
                    'Aktif paket süresi boyunca profilin bölümde yer alır.',
                ],
            'screenshots' => [
                'web' => '/assets/ads/' . $placement . '-web.png',
                'mobile' => '/assets/ads/' . $placement . '-mobile.png',
            ],
            'packages' => FeaturedPackage::query()->placement($placement)->where('is_active', true)->orderBy('sort_order')->orderBy('duration_days')->get()->map->present()->values(),
            'status' => $this->featured->statusFor($user, $placement),
        ];
    }

    /**
     * The third alternative next to the two placements: a paid discount notification. It has no packages or periods
     * (one price per audience, see `GET /provider/notification-ads`), so clients open their own form for `kind: notification`.
     */
    private function notificationPlacementPayload(User $user): array
    {
        $discount = app(ProviderDiscountService::class)->activeFor($user->id);
        $settings = NotificationAdSetting::current();
        $present = $settings->present();

        return [
            'placement' => 'notification',
            'kind' => 'notification',
            'is_enabled' => $present['is_enabled'],
            'slots' => 0,
            'rotation_seconds' => 0,
            'title' => $present['title'],
            'description' => $present['description'],
            'where' => [
                'Müşterilerin telefonuna gelen bildirim',
                'Müşterilerin uygulamadaki bildirim merkezi (dokununca profilin açılır)',
            ],
            'how' => [
                'Başlığı, açıklamayı ve indirim oranını sen yazarsın; indirim, seçtiğin gün boyunca fiyatlarına gerçekten uygulanır.',
                'Hizmet bölgendeki, seçtiğin konumdaki ya da tüm kullanıcılara gönderebilirsin; ücret hedefe göre değişir.',
                sprintf('Bildirimleri kapatan kullanıcılara gönderilmez; bir kullanıcı günde en fazla %d reklam bildirimi alır.', $settings->max_per_customer_per_day),
            ],
            'screenshots' => null,
            'packages' => [],
            'status' => ['is_featured' => false, 'featured_until' => null, 'active' => [], 'upcoming' => []],
            // The running campaign discount of this provider (what a notification ad started), if any.
            'active_discount' => $discount?->present(),
            'starting_price' => collect($present['audiences'])->min('price'),
        ];
    }

    private function payload(Request $request): array
    {
        $user = $request->user();
        $wallet = Wallet::query()->where('user_id', $user->id)->first();
        $cardEnabled = $this->orders->cardEnabled();

        return [
            // Legacy keys (homepage showcase) stay as they were; `placements` carries every placement.
            'packages' => FeaturedPackage::query()->placement(FeaturedPromotion::PLACEMENT_HOME)->where('is_active', true)->orderBy('sort_order')->orderBy('duration_days')->get()->map->present()->values(),
            'placements' => collect(FeaturedPromotion::PLACEMENTS)->map(fn (string $key) => $this->placementPayload($user, $key))->push($this->notificationPlacementPayload($user))->values(),
            'wallet' => [
                'usable_cash_balance' => $wallet ? (float) $wallet->usable_cash_balance : 0.0,
                'is_frozen' => (bool) ($wallet?->is_frozen),
            ],
            // Both ways to pay; card only appears when PayTR is configured.
            'payment' => [
                'wallet_enabled' => true,
                'card_enabled' => $cardEnabled,
                'card_unavailable_reason' => $cardEnabled ? null : 'Kartla ödeme şu anda kullanılamıyor.',
            ],
            'status' => $this->featured->statusFor($user, FeaturedPromotion::PLACEMENT_HOME),
            'history' => FeaturedPromotion::query()
                ->where('provider_user_id', $user->id)
                ->latest('id')
                ->limit(20)
                ->get()
                ->map->present()
                ->values(),
        ];
    }
}
