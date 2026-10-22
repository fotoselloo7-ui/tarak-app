<?php

namespace App\Services;

use App\Models\FeaturedOrder;
use App\Models\FeaturedPackage;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\ValidationException;

/**
 * Card (PayTR) payment for an "öne çıkarma" package. The order is created PENDING with its
 * own merchant_oid (prefix FP); the promotion period is created only when PayTR confirms
 * the payment — through the callback, or the payment-status query when the provider comes
 * back before the callback has arrived. Both paths are idempotent.
 */
class FeaturedOrderService
{
    public function __construct(
        private PaytrService $paytr,
        private FeaturedPromotionService $promotions,
    ) {
    }

    public function cardEnabled(): bool
    {
        return $this->paytr->isConfigured();
    }

    /**
     * @return array{order: FeaturedOrder, token: string, iframe_url: string}
     */
    public function startCardOrder(User $provider, FeaturedPackage $package, ?string $ip = null): array
    {
        if (!$package->is_active) {
            throw ValidationException::withMessages(['package_id' => ['Bu paket şu anda satışta değil.']]);
        }
        $priceCents = FinancialService::parseToCents($package->price);
        if ($priceCents <= 0) {
            throw ValidationException::withMessages(['package_id' => ['Ücretsiz bir paket için kart ödemesi gerekmez.']]);
        }
        $placement = $package->placement ?: \App\Models\FeaturedPromotion::PLACEMENT_HOME;
        $this->promotions->assertPlacementOpen($placement);
        $this->promotions->assertListable($provider);
        if (!$this->cardEnabled()) {
            throw ValidationException::withMessages(['package_id' => ['Kartla ödeme şu anda kullanılamıyor. Cüzdan bakiyenizle ödeyebilirsiniz.']]);
        }

        $order = FeaturedOrder::create([
            'provider_user_id' => $provider->id,
            'placement' => $placement,
            'featured_package_id' => $package->id,
            'package_name' => $package->name,
            'duration_days' => $package->duration_days,
            'amount' => FinancialService::formatFromCents($priceCents),
            'status' => FeaturedOrder::STATUS_PENDING,
            'merchant_oid' => $this->paytr->generateMerchantOid(FeaturedOrder::OID_PREFIX),
            'user_ip' => $ip,
        ]);

        try {
            $token = $this->paytr->requestHostedToken(
                $order->merchant_oid,
                $priceCents,
                [[$package->name . ($placement === \App\Models\FeaturedPromotion::PLACEMENT_LISTING ? ' - Liste Reklamı' : ' - Öne Çıkarma'), number_format($priceCents / 100, 2, '.', ''), 1]],
                $provider->email ?: 'usta@berberimgelsin.com',
                $provider->name ?: 'Hizmet Veren',
                $provider->phone ?: '05555555555',
                $ip,
            );
        } catch (\Throwable $e) {
            $order->forceFill(['status' => FeaturedOrder::STATUS_FAILED, 'failure_message' => mb_substr($e->getMessage(), 0, 250)])->save();
            Log::warning('Featured card order token failed', ['order_id' => $order->id, 'error' => $e->getMessage()]);

            throw ValidationException::withMessages(['package_id' => [$e instanceof \LogicException
                ? 'Kartla ödeme şu anda kullanılamıyor.'
                : 'Ödeme oturumu açılamadı. Lütfen tekrar deneyin.']]);
        }

        return ['order' => $order, 'token' => $token['token'], 'iframe_url' => $token['iframe_url']];
    }

    /** PayTR server-to-server notification for an FP… merchant_oid. Always acknowledged with OK once the signature is valid. */
    public function handleCallback(array $payload): string
    {
        return DB::transaction(function () use ($payload) {
            $order = FeaturedOrder::where('merchant_oid', $payload['merchant_oid'])->lockForUpdate()->first();
            if (!$order || $order->status === FeaturedOrder::STATUS_PAID) {
                return 'OK';
            }

            if (strtolower((string) ($payload['status'] ?? '')) === 'success') {
                $paidMinor = (int) ($payload['payment_amount'] ?? $payload['total_amount'] ?? 0);
                $expectedMinor = FinancialService::parseToCents($order->amount);
                if ($paidMinor < $expectedMinor) {
                    $order->forceFill([
                        'status' => FeaturedOrder::STATUS_FAILED,
                        'failure_message' => "Beklenen tutar ({$expectedMinor}) ile ödenen ({$paidMinor}) eşleşmiyor.",
                        'callback_payload' => $payload,
                    ])->save();
                    Log::warning('Featured order amount mismatch', ['order_id' => $order->id]);

                    return 'OK';
                }
                $this->markPaid($order, $payload);

                return 'OK';
            }

            $order->forceFill([
                'status' => FeaturedOrder::STATUS_FAILED,
                'failure_message' => mb_substr((string) ($payload['failed_reason_msg'] ?? 'Ödeme tamamlanamadı.'), 0, 250),
                'callback_payload' => $payload,
            ])->save();

            return 'OK';
        });
    }

    /**
     * Status for the provider's screen. A PENDING order older than a few seconds is checked
     * against PayTR once, so the screen does not depend on the callback arriving first.
     */
    public function refresh(FeaturedOrder $order): FeaturedOrder
    {
        if ($order->status !== FeaturedOrder::STATUS_PENDING || !$this->cardEnabled() || $order->created_at->gt(now()->subSeconds(15))) {
            return $order;
        }

        $res = $this->paytr->queryPaymentStatus($order->merchant_oid);
        if (($res['status'] ?? null) !== 'success' || strtolower((string) ($res['payment_status'] ?? '')) !== 'success') {
            return $order;
        }

        $paidMinor = (int) round(((float) ($res['payment_amount'] ?? $res['payment_total'] ?? 0)) * 100);
        $expectedMinor = FinancialService::parseToCents($order->amount);
        if ($paidMinor > 0 && $paidMinor < $expectedMinor) {
            return $order;
        }

        DB::transaction(function () use ($order, $res) {
            $locked = FeaturedOrder::where('id', $order->id)->lockForUpdate()->first();
            if ($locked && $locked->status === FeaturedOrder::STATUS_PENDING) {
                $this->markPaid($locked, $res);
            }
        });

        return $order->refresh();
    }

    private function markPaid(FeaturedOrder $order, array $payload): void
    {
        $promotion = $this->promotions->fulfillPaidOrder($order);
        $order->forceFill([
            'status' => FeaturedOrder::STATUS_PAID,
            'paid_at' => now(),
            'promotion_id' => $promotion->id,
            'failure_message' => null,
            'callback_payload' => $payload,
        ])->save();
    }
}
