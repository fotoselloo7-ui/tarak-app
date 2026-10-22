<?php

namespace App\Services;

use App\Models\ProviderDiscount;

/**
 * The campaign discount of a provider ("bildirim reklamı"): one percentage off every service and package while it
 * runs. Customer-facing prices go through here (offerings, price snapshots, appointment totals); the provider's own
 * price list keeps showing the base prices.
 */
class ProviderDiscountService
{
    public function activeFor(int $providerUserId): ?ProviderDiscount
    {
        return ProviderDiscount::query()->active()->where('provider_user_id', $providerUserId)->latest('id')->first();
    }

    public function percentFor(int $providerUserId): int
    {
        return (int) ($this->activeFor($providerUserId)?->percent ?? 0);
    }

    /**
     * One query for a whole list of providers (the customer's provider lists).
     *
     * @return array<int, int> provider user id => percent (0 when none)
     */
    public function percentsFor(iterable $providerUserIds): array
    {
        $ids = collect($providerUserIds)->map(fn ($id) => (int) $id)->unique()->values();
        $map = $ids->mapWithKeys(fn ($id) => [$id => 0])->all();
        ProviderDiscount::query()->active()->whereIn('provider_user_id', $ids)->orderBy('id')->get()
            ->each(function (ProviderDiscount $d) use (&$map) {
                $map[$d->provider_user_id] = $d->percent;
            });

        return $map;
    }

    public static function discounted(float $price, int $percent): float
    {
        return $percent > 0 ? round($price * (100 - $percent) / 100, 2) : round($price, 2);
    }

    /**
     * @return array{price: float, original_price: ?float, discount_percent: int}
     */
    public function apply(int $providerUserId, float $price): array
    {
        return $this->applyPercent($price, $this->percentFor($providerUserId));
    }

    /**
     * @return array{price: float, original_price: ?float, discount_percent: int}
     */
    public function applyPercent(float $price, int $percent): array
    {
        $price = round($price, 2);

        return [
            'price' => self::discounted($price, $percent),
            'original_price' => $percent > 0 ? $price : null,
            'discount_percent' => max(0, $percent),
        ];
    }

    /** Starts a campaign discount now; a running one is replaced (one discount at a time). */
    public function start(int $providerUserId, int $percent, int $days, ?int $notificationAdId = null): ProviderDiscount
    {
        $this->end($providerUserId);

        return ProviderDiscount::create([
            'provider_user_id' => $providerUserId,
            'percent' => $percent,
            'starts_at' => now(),
            'ends_at' => now()->addDays($days),
            'notification_ad_id' => $notificationAdId,
        ]);
    }

    /** Ends the running discount (the provider's "bitir" or a replacement). Returns how many were ended. */
    public function end(int $providerUserId): int
    {
        return ProviderDiscount::query()->active()->where('provider_user_id', $providerUserId)->update(['cancelled_at' => now()]);
    }
}
