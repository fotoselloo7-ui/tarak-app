<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\NotificationAd;
use App\Models\ProviderProfile;
use App\Services\NotificationAdService;
use App\Services\ProviderDiscountService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Provider side of "bildirim reklamı": see the audiences and prices, estimate how many customers a send reaches, send
 * it (wallet balance or card via PayTR) and end the discount a campaign started.
 */
class ProviderNotificationAdController extends Controller
{
    public function __construct(
        private NotificationAdService $ads,
        private ProviderDiscountService $discounts,
    ) {
    }

    public function show(Request $request): JsonResponse
    {
        return response()->json(['success' => true, 'data' => $this->ads->overview($request->user())]);
    }

    public function districts(Request $request): JsonResponse
    {
        $province = trim((string) $request->query('province', ''));

        return response()->json(['success' => true, 'data' => $province === '' ? [] : $this->ads->districts($province)]);
    }

    /** "How many people does this reach, what does it cost?" for the audience the provider is looking at. */
    public function estimate(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'audience' => ['required', 'string', 'in:' . implode(',', NotificationAd::AUDIENCES)],
            'province' => ['nullable', 'string', 'max:100'],
            'district' => ['nullable', 'string', 'max:100'],
        ], ['audience.in' => 'Hedef kitle geçersiz.']);

        $profile = ProviderProfile::query()->where('user_id', $request->user()->id)->firstOrFail();

        return response()->json(['success' => true, 'data' => $this->ads->estimate($profile, $validated['audience'], $validated['province'] ?? null, $validated['district'] ?? null)]);
    }

    /**
     * `payment_method`: "wallet" (default) debits the wallet cash balance and sends at once; "card" opens a PayTR
     * payment (iFrame token), the notification goes out when PayTR confirms it.
     */
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'audience' => ['required', 'string'],
            'province' => ['nullable', 'string', 'max:100'],
            'district' => ['nullable', 'string', 'max:100'],
            'title' => ['required', 'string', 'max:200'],
            'body' => ['required', 'string', 'max:400'],
            'discount_percent' => ['required', 'integer', 'min:1', 'max:100'],
            'discount_days' => ['required', 'integer', 'min:1', 'max:365'],
            'payment_method' => ['sometimes', 'string', 'in:wallet,card'],
        ], [
            'title.required' => 'Bildirim başlığını yazın.',
            'body.required' => 'Bildirim açıklamasını yazın.',
            'discount_percent.required' => 'İndirim oranını girin.',
            'discount_days.required' => 'İndirimin kaç gün süreceğini seçin.',
            'payment_method.in' => 'Ödeme yöntemi geçersiz.',
        ]);

        $method = $validated['payment_method'] ?? 'wallet';
        unset($validated['payment_method']);

        if ($method === 'card') {
            $started = $this->ads->startCardOrder($request->user(), $validated, $request->ip());

            return response()->json([
                'success' => true,
                'message' => 'Ödeme oturumu hazırlandı.',
                'data' => [
                    'payment_method' => 'card',
                    'ad' => $started['ad']->present(),
                    'token' => $started['token'],
                    'iframe_url' => $started['iframe_url'],
                ],
            ], 201);
        }

        $ad = $this->ads->purchaseWithWallet($request->user(), $validated);

        return response()->json([
            'success' => true,
            'message' => 'Bildirim reklamınız gönderildi.',
            'data' => $this->ads->overview($request->user()) + ['payment_method' => 'wallet', 'sent' => $ad->present()],
        ], 201);
    }

    /** Polled while the card payment window is open. */
    public function status(Request $request, int $id): JsonResponse
    {
        $ad = NotificationAd::query()->where('provider_user_id', $request->user()->id)->findOrFail($id);
        $ad = $this->ads->refresh($ad);

        return response()->json(['success' => true, 'data' => $ad->present()]);
    }

    /** "Bitir": the campaign discount stops now (a notification already sent stays sent). */
    public function endDiscount(Request $request): JsonResponse
    {
        $ended = $this->discounts->end($request->user()->id);

        return response()->json(['success' => true, 'message' => $ended > 0 ? 'İndirim sonlandırıldı.' : 'Aktif bir indirim yok.', 'data' => $this->ads->overview($request->user())]);
    }
}
