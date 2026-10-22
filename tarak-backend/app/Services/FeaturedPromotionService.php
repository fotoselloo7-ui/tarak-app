<?php

namespace App\Services;

use App\Models\FeaturedPackage;
use App\Models\FeaturedPlacementSetting;
use App\Models\FeaturedPromotion;
use App\Models\ProviderProfile;
use App\Models\User;
use App\Models\UserNotification;
use App\Models\Wallet;
use App\Models\WalletTransaction;
use Carbon\CarbonInterface;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * "Öne çıkarma": a provider pays (from the wallet cash balance or by card) for N days in a
 * PLACEMENT: the homepage showcase ("home") or the sponsored slots of the provider lists
 * ("listing"). Purchases stack per placement: buying while a period of the same placement is
 * running queues the new one right behind it. The profile leaves the placement by itself when
 * ends_at passes (the public queries only read active periods).
 */
class FeaturedPromotionService
{
    public function __construct(private NotificationService $notifications)
    {
    }

    /** Provider self-service purchase, paid from the wallet cash balance. */
    public function purchase(User $provider, FeaturedPackage $package): FeaturedPromotion
    {
        if (!$package->is_active) {
            throw ValidationException::withMessages(['package_id' => ['Bu paket şu anda satışta değil.']]);
        }
        $this->assertPlacementOpen($package->placement ?: FeaturedPromotion::PLACEMENT_HOME);
        $this->assertListable($provider);

        $promotion = DB::transaction(function () use ($provider, $package) {
            $priceCents = FinancialService::parseToCents($package->price);

            $wallet = Wallet::firstOrCreate(
                ['user_id' => $provider->id],
                ['balance' => 0.00, 'promo_balance' => 0.00, 'reserved_cash_balance' => 0.00, 'reserved_promo_balance' => 0.00, 'currency' => 'TRY', 'is_frozen' => false]
            );
            $wallet = Wallet::where('id', $wallet->id)->lockForUpdate()->first();

            if ($priceCents > 0) {
                if ($wallet->is_frozen) {
                    throw ValidationException::withMessages(['package_id' => ['Cüzdanınız dondurulmuş; satın alma yapılamıyor.']]);
                }
                $cashCents = FinancialService::parseToCents($wallet->balance);
                $usableCents = max(0, $cashCents - FinancialService::parseToCents($wallet->reserved_cash_balance));
                if ($usableCents < $priceCents) {
                    throw ValidationException::withMessages(['package_id' => [sprintf(
                        'Bakiyeniz yetersiz. Kullanılabilir bakiye: ₺%s, paket tutarı: ₺%s.',
                        number_format($usableCents / 100, 2, ',', '.'),
                        number_format($priceCents / 100, 2, ',', '.')
                    )]]);
                }
            }

            $promotion = $this->createPeriod($provider->id, $package->duration_days, $package->name, $package, FeaturedPromotion::SOURCE_WALLET, $package->price, null, null, $package->placement ?: FeaturedPromotion::PLACEMENT_HOME);

            if ($priceCents > 0) {
                WalletTransaction::create([
                    'wallet_id' => $wallet->id,
                    'user_id' => $provider->id,
                    'type' => WalletTransaction::TYPE_FEATURED_PURCHASE,
                    'direction' => WalletTransaction::DIRECTION_DEBIT,
                    'bucket' => WalletTransaction::BUCKET_CASH,
                    'amount' => FinancialService::formatFromCents($priceCents),
                    'reference_type' => 'FEATURED_PROMOTION',
                    'reference_id' => $promotion->id,
                    'idempotency_key' => 'FEATURED_PURCHASE:' . $promotion->id,
                    'description' => ($package->placement === FeaturedPromotion::PLACEMENT_LISTING ? 'Liste reklamı: ' : 'Öne çıkarma: ') . $package->name,
                ]);
                $wallet->balance = FinancialService::formatFromCents(FinancialService::parseToCents($wallet->balance) - $priceCents);
                $wallet->save();
            }

            return $promotion;
        });

        $this->notifyStarted($promotion);

        return $promotion;
    }

    /** Card payment confirmed by PayTR: create the period (wallet untouched), notify the provider. */
    public function fulfillPaidOrder(\App\Models\FeaturedOrder $order): FeaturedPromotion
    {
        $promotion = DB::transaction(fn () => $this->createPeriod(
            $order->provider_user_id,
            $order->duration_days,
            $order->package_name,
            $order->package,
            FeaturedPromotion::SOURCE_CARD,
            $order->amount,
            null,
            null,
            $order->placement ?: FeaturedPromotion::PLACEMENT_HOME
        ));
        $this->notifyStarted($promotion);

        return $promotion;
    }

    /** Admin gift / campaign: no wallet movement. */
    public function grant(User $provider, int $days, int $adminId, ?FeaturedPackage $package = null, ?string $note = null, ?string $placement = null): FeaturedPromotion
    {
        $this->assertListable($provider);
        $placement = $package?->placement ?: ($placement ?: FeaturedPromotion::PLACEMENT_HOME);

        $promotion = DB::transaction(fn () => $this->createPeriod(
            $provider->id,
            $days,
            $package?->name ?? ($days . ' Gün (hediye)'),
            $package,
            FeaturedPromotion::SOURCE_ADMIN,
            0,
            $adminId,
            $note,
            $placement
        ));

        $this->notifyStarted($promotion);

        return $promotion;
    }

    /** Stops a period now (admin). The queue behind it is NOT shifted: each row keeps its own dates. */
    public function cancel(FeaturedPromotion $promotion): FeaturedPromotion
    {
        if (!$promotion->cancelled_at) {
            $promotion->forceFill(['cancelled_at' => now()])->save();
        }

        return $promotion;
    }

    /**
     * Marks finished periods and tells the provider (once). The section itself does not
     * depend on this running — it only reads active periods.
     *
     * @return int number of providers notified
     */
    public function expireDue(): int
    {
        $count = 0;
        FeaturedPromotion::query()
            ->whereNull('cancelled_at')
            ->whereNull('expiry_notified_at')
            ->where('ends_at', '<=', now())
            ->orderBy('id')
            ->chunkById(100, function ($rows) use (&$count) {
                foreach ($rows as $promotion) {
                    // A queued period right behind this one means the provider is still featured.
                    $placement = $promotion->placement ?: FeaturedPromotion::PLACEMENT_HOME;
                    $stillFeatured = FeaturedPromotion::active()->placement($placement)->where('provider_user_id', $promotion->provider_user_id)->exists()
                        || FeaturedPromotion::upcoming()->placement($placement)->where('provider_user_id', $promotion->provider_user_id)->exists();
                    $promotion->forceFill(['expiry_notified_at' => now()])->save();
                    if ($stillFeatured) {
                        continue;
                    }
                    $this->notifications->notifyUser(
                        $promotion->provider_user_id,
                        UserNotification::TYPE_FEATURED_EXPIRED,
                        $placement === FeaturedPromotion::PLACEMENT_LISTING ? 'Liste reklamı süreniz doldu' : 'Öne çıkarma süreniz doldu',
                        $placement === FeaturedPromotion::PLACEMENT_LISTING
                            ? 'Profiliniz artık uzman listelerinin en üstünde önerilen olarak görünmüyor. Yeniden yer almak için bir paket seçebilirsiniz.'
                            : 'Profiliniz artık Öne Çıkan Profesyoneller bölümünde görünmüyor. Yeniden öne çıkmak için bir paket seçebilirsiniz.',
                        'FEATURED_PROMOTION',
                        $promotion->id,
                        null,
                        [],
                        'FEATURED_EXPIRED:' . $promotion->id
                    );
                    $count++;
                }
            });

        return $count;
    }

    /** Provider-facing status of one placement: running period, queued ones and the day the profile leaves it. */
    public function statusFor(User $provider, string $placement = FeaturedPromotion::PLACEMENT_HOME): array
    {
        $active = FeaturedPromotion::active()->placement($placement)->where('provider_user_id', $provider->id)->orderBy('ends_at')->get();
        $upcoming = FeaturedPromotion::upcoming()->placement($placement)->where('provider_user_id', $provider->id)->orderBy('starts_at')->get();
        $featuredUntil = $active->merge($upcoming)->max('ends_at');

        return [
            'is_featured' => $active->isNotEmpty(),
            'featured_until' => $featuredUntil instanceof CarbonInterface ? $featuredUntil->toIso8601String() : null,
            'active' => $active->map->present()->values(),
            'upcoming' => $upcoming->map->present()->values(),
        ];
    }

    /** User ids with a running period of a placement (used to build the public section). */
    public function activeProviderIds(string $placement = FeaturedPromotion::PLACEMENT_HOME): array
    {
        return FeaturedPromotion::active()->placement($placement)->distinct()->pluck('provider_user_id')->map(fn ($id) => (int) $id)->all();
    }

    private function createPeriod(int $providerId, int $days, string $name, ?FeaturedPackage $package, string $source, mixed $price, ?int $adminId, ?string $note, string $placement = FeaturedPromotion::PLACEMENT_HOME): FeaturedPromotion
    {
        // The queue is per placement: a homepage period never delays a list ad (and vice versa).
        $latestEnd = FeaturedPromotion::query()
            ->placement($placement)
            ->where('provider_user_id', $providerId)
            ->whereNull('cancelled_at')
            ->where('ends_at', '>', now())
            ->orderByDesc('ends_at')
            ->first()?->ends_at;

        $start = $latestEnd && $latestEnd->isFuture() ? $latestEnd->copy() : now();

        return FeaturedPromotion::create([
            'provider_user_id' => $providerId,
            'placement' => $placement,
            'featured_package_id' => $package?->id,
            'package_name' => $name,
            'duration_days' => $days,
            'price_paid' => $price,
            'source' => $source,
            'starts_at' => $start,
            'ends_at' => $start->copy()->addDays($days),
            'created_by' => $adminId,
            'note' => $note,
        ]);
    }

    /** Admin can close a placement for new purchases (running periods keep running). */
    public function assertPlacementOpen(string $placement): void
    {
        if (!FeaturedPlacementSetting::for($placement)->is_enabled) {
            throw ValidationException::withMessages(['package_id' => ['Bu reklam alanı şu anda yeni satışa kapalı.']]);
        }
    }

    public function assertListable(User $provider): void
    {
        $profile = ProviderProfile::query()->where('user_id', $provider->id)->first();
        if (!$profile || !ProviderProfile::query()->publiclyListed()->whereKey($profile->id)->exists()) {
            throw ValidationException::withMessages(['package_id' => ['Profiliniz onaylandıktan sonra öne çıkarma satın alabilirsiniz.']]);
        }
    }

    private function notifyStarted(FeaturedPromotion $promotion): void
    {
        $tz = config('app.timezone');
        $queued = $promotion->starts_at->isFuture();
        $listing = $promotion->placement === FeaturedPromotion::PLACEMENT_LISTING;
        $where = $listing ? 'uzman listelerinin en üstünde önerilen olarak' : 'Öne Çıkan Profesyoneller bölümünde';
        $this->notifications->notifyUser(
            $promotion->provider_user_id,
            UserNotification::TYPE_FEATURED_STARTED,
            $listing
                ? ($queued ? 'Liste reklamı paketiniz sıraya alındı' : 'Liste reklamınız yayında')
                : ($queued ? 'Öne çıkarma paketiniz sıraya alındı' : 'Profiliniz öne çıkarıldı'),
            $queued
                ? sprintf('%s paketi %s tarihinde başlayacak ve %s tarihine kadar sürecek.', $promotion->package_name, $promotion->starts_at->timezone($tz)->format('d.m.Y'), $promotion->ends_at->timezone($tz)->format('d.m.Y'))
                : sprintf('%s paketi aktif. Profiliniz %s tarihine kadar %s yer alacak.', $promotion->package_name, $promotion->ends_at->timezone($tz)->format('d.m.Y'), $where),
            'FEATURED_PROMOTION',
            $promotion->id,
            null,
            [],
            'FEATURED_STARTED:' . $promotion->id
        );
    }
}
