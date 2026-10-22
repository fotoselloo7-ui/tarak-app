<?php

namespace App\Services;

use App\Jobs\DeliverNotificationAd;
use App\Models\NotificationAd;
use App\Models\NotificationAdSetting;
use App\Models\ProviderProfile;
use App\Models\User;
use App\Models\UserNotification;
use App\Models\Wallet;
use App\Models\WalletTransaction;
use App\Support\Geo;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\ValidationException;

/**
 * "Bildirim reklamı": a provider pays (wallet or card) to send a discount notification to customers: their service
 * area, a location they pick, or everyone. The discount is real, it is applied to the provider's prices for the
 * chosen number of days (ProviderDiscountService). Prices, discount limits and anti-spam caps are the admin's
 * (NotificationAdSetting). Customers who turned campaign notifications off, and customers who already got their
 * daily share of campaigns, are skipped.
 */
class NotificationAdService
{
    public function __construct(
        private NotificationService $notifications,
        private ProviderDiscountService $discounts,
        private PaytrService $paytr,
        private MessageContentPolicyService $policy,
    ) {
    }

    public function cardEnabled(): bool
    {
        return $this->paytr->isConfigured();
    }

    // ───────────────────────────────────────────────────────────── audience

    /** Customers a campaign of this provider would reach right now. */
    public function recipientQuery(ProviderProfile $profile, string $audience, ?string $province = null, ?string $district = null, ?NotificationAdSetting $settings = null): Builder
    {
        $settings ??= NotificationAdSetting::current();
        $cap = max(1, $settings->max_per_customer_per_day);

        $query = User::query()
            ->where('users.role', User::ROLE_CUSTOMER)
            ->where('users.status', 'active')
            // Customers who switched campaign notifications off.
            ->whereNotExists(fn ($q) => $q->select(DB::raw(1))->from('user_push_preferences as pref')
                ->whereColumn('pref.user_id', 'users.id')->where('pref.campaign_enabled', false))
            // Customers who already received their share of campaigns in the last 24 hours.
            ->whereRaw('(select count(*) from user_notifications un where un.user_id = users.id and un.type = ? and un.created_at >= ?) < ?', [
                UserNotification::TYPE_PROVIDER_CAMPAIGN, now()->subDay(), $cap,
            ]);

        if ($audience === NotificationAd::AUDIENCE_ALL) {
            return $query;
        }

        return $query->whereExists(function ($q) use ($audience, $profile, $province, $district) {
            $q->select(DB::raw(1))->from('customer_addresses as ca')
                ->join('customer_profiles as cp', 'cp.id', '=', 'ca.customer_profile_id')
                ->whereColumn('cp.user_id', 'users.id');

            if ($audience === NotificationAd::AUDIENCE_LOCATION) {
                $q->where('ca.province', $province);
                if ($district) {
                    $q->where('ca.district', $district);
                }

                return;
            }

            // Service area: within the provider's service radius, or the same city + district (addresses without coordinates).
            $q->where(function ($w) use ($profile) {
                $radius = (float) ($profile->service_radius_km ?: 10);
                if ($profile->latitude !== null && $profile->longitude !== null) {
                    [$expr, $bindings] = Geo::sql([(float) $profile->latitude, (float) $profile->longitude], 'ca.latitude', 'ca.longitude');
                    $w->orWhere(fn ($near) => $near->whereNotNull('ca.latitude')->whereNotNull('ca.longitude')->whereRaw($expr . ' <= ?', [...$bindings, $radius]));
                }
                if ($profile->city) {
                    $w->orWhere(fn ($same) => $same->where('ca.province', $profile->city)
                        ->when($profile->district, fn ($x) => $x->where('ca.district', $profile->district)));
                }
                // No coordinates and no city: nobody (an empty service area), never "everyone".
                $w->orWhereRaw('1 = 0');
            });
        });
    }

    /** @return array{recipients: int, price: float} */
    public function estimate(ProviderProfile $profile, string $audience, ?string $province = null, ?string $district = null): array
    {
        $settings = NotificationAdSetting::current();

        return [
            'recipients' => (int) $this->recipientQuery($profile, $audience, $province, $district, $settings)->count(),
            'price' => $settings->priceFor($audience),
        ];
    }

    /** Provinces (with customer counts) to pick a location from. */
    public function provinces(): array
    {
        return DB::table('customer_addresses')->whereNotNull('province')->where('province', '!=', '')
            ->selectRaw('province, count(distinct customer_profile_id) as customers')
            ->groupBy('province')->orderByDesc('customers')->limit(120)->get()
            ->map(fn ($r) => ['province' => $r->province, 'customers' => (int) $r->customers])->values()->all();
    }

    public function districts(string $province): array
    {
        return DB::table('customer_addresses')->where('province', $province)->whereNotNull('district')->where('district', '!=', '')
            ->selectRaw('district, count(distinct customer_profile_id) as customers')
            ->groupBy('district')->orderByDesc('customers')->limit(200)->get()
            ->map(fn ($r) => ['district' => $r->district, 'customers' => (int) $r->customers])->values()->all();
    }

    // ───────────────────────────────────────────────────────────── validation

    /**
     * Everything a send needs to be allowed, in one place (both payment ways call it).
     *
     * @param array{audience: string, province?: ?string, district?: ?string, title: string, body: string, discount_percent: int, discount_days: int} $data
     * @return array{profile: ProviderProfile, settings: NotificationAdSetting, recipients: int, price: float, data: array}
     */
    public function prepare(User $provider, array $data): array
    {
        $settings = NotificationAdSetting::current();
        if (!$settings->is_enabled) {
            throw ValidationException::withMessages(['audience' => ['Bildirim reklamı şu anda yeni satışa kapalı.']]);
        }

        $profile = ProviderProfile::query()->where('user_id', $provider->id)->first();
        if (!$profile || !ProviderProfile::query()->publiclyListed()->whereKey($profile->id)->exists()) {
            throw ValidationException::withMessages(['audience' => ['Profiliniz onaylandıktan sonra bildirim reklamı gönderebilirsiniz.']]);
        }

        $data['title'] = trim((string) $data['title']);
        $data['body'] = trim((string) $data['body']);
        $data['province'] = trim((string) ($data['province'] ?? ''));
        $data['district'] = trim((string) ($data['district'] ?? ''));

        $errors = [];
        if (!in_array($data['audience'], NotificationAd::AUDIENCES, true)) {
            $errors['audience'] = ['Hedef kitle geçersiz.'];
        }
        if (mb_strlen($data['title']) < 3 || mb_strlen($data['title']) > NotificationAd::TITLE_MAX) {
            $errors['title'] = ['Başlık 3 ile ' . NotificationAd::TITLE_MAX . ' karakter arasında olmalı.'];
        }
        if (mb_strlen($data['body']) < 5 || mb_strlen($data['body']) > NotificationAd::BODY_MAX) {
            $errors['body'] = ['Açıklama 5 ile ' . NotificationAd::BODY_MAX . ' karakter arasında olmalı.'];
        }
        if ($data['discount_percent'] < $settings->min_discount_percent || $data['discount_percent'] > $settings->max_discount_percent) {
            $errors['discount_percent'] = ["İndirim oranı %{$settings->min_discount_percent} ile %{$settings->max_discount_percent} arasında olmalı."];
        }
        if ($data['discount_days'] < 1 || $data['discount_days'] > $settings->max_discount_days) {
            $errors['discount_days'] = ["İndirim süresi 1 ile {$settings->max_discount_days} gün arasında olmalı."];
        }
        if (($data['audience'] ?? null) === NotificationAd::AUDIENCE_LOCATION && $data['province'] === '') {
            $errors['province'] = ['Bildirimin gideceği ili seçin.'];
        }
        foreach (['title', 'body'] as $field) {
            if (!isset($errors[$field]) && $this->policy->detectViolation($data[$field]) !== null) {
                $errors[$field] = ['Bildirim metninde telefon, e-posta, bağlantı veya sosyal medya bilgisi paylaşamazsınız.'];
            }
        }
        if ($errors) {
            throw ValidationException::withMessages($errors);
        }

        $sentToday = NotificationAd::query()->where('provider_user_id', $provider->id)
            ->whereIn('status', [NotificationAd::STATUS_QUEUED, NotificationAd::STATUS_SENT])
            ->where('created_at', '>=', now()->subDay())->count();
        if ($sentToday >= $settings->max_sends_per_provider_per_day) {
            throw ValidationException::withMessages(['audience' => ["Son 24 saatte en fazla {$settings->max_sends_per_provider_per_day} bildirim reklamı gönderebilirsiniz."]]);
        }

        $quote = $this->estimate($profile, $data['audience'], $data['province'] ?: null, $data['district'] ?: null);
        if ($quote['recipients'] < 1) {
            throw ValidationException::withMessages(['audience' => ['Bu hedefte şu anda bildirim alabilecek kullanıcı yok. Başka bir hedef seçin.']]);
        }

        return ['profile' => $profile, 'settings' => $settings, 'recipients' => $quote['recipients'], 'price' => $quote['price'], 'data' => $data];
    }

    // ───────────────────────────────────────────────────────────── wallet

    /** Pays from the wallet cash balance, starts the discount and sends. */
    public function purchaseWithWallet(User $provider, array $input): NotificationAd
    {
        $prepared = $this->prepare($provider, $input);
        $priceCents = FinancialService::parseToCents($prepared['price']);

        $ad = DB::transaction(function () use ($provider, $prepared, $priceCents) {
            $wallet = Wallet::firstOrCreate(
                ['user_id' => $provider->id],
                ['balance' => 0.00, 'promo_balance' => 0.00, 'reserved_cash_balance' => 0.00, 'reserved_promo_balance' => 0.00, 'currency' => 'TRY', 'is_frozen' => false]
            );
            $wallet = Wallet::where('id', $wallet->id)->lockForUpdate()->first();

            if ($priceCents > 0) {
                if ($wallet->is_frozen) {
                    throw ValidationException::withMessages(['audience' => ['Cüzdanınız dondurulmuş; satın alma yapılamıyor.']]);
                }
                $usableCents = max(0, FinancialService::parseToCents($wallet->balance) - FinancialService::parseToCents($wallet->reserved_cash_balance));
                if ($usableCents < $priceCents) {
                    throw ValidationException::withMessages(['audience' => [sprintf(
                        'Bakiyeniz yetersiz. Kullanılabilir bakiye: ₺%s, bildirim reklamı tutarı: ₺%s.',
                        number_format($usableCents / 100, 2, ',', '.'),
                        number_format($priceCents / 100, 2, ',', '.')
                    )]]);
                }
            }

            $ad = NotificationAd::create($this->attributes($provider, $prepared) + [
                'status' => NotificationAd::STATUS_QUEUED,
                'payment_source' => NotificationAd::SOURCE_WALLET,
                'paid_at' => now(),
            ]);

            if ($priceCents > 0) {
                WalletTransaction::create([
                    'wallet_id' => $wallet->id,
                    'user_id' => $provider->id,
                    'type' => WalletTransaction::TYPE_NOTIFICATION_AD_PURCHASE,
                    'direction' => WalletTransaction::DIRECTION_DEBIT,
                    'bucket' => WalletTransaction::BUCKET_CASH,
                    'amount' => FinancialService::formatFromCents($priceCents),
                    'reference_type' => 'NOTIFICATION_AD',
                    'reference_id' => $ad->id,
                    'idempotency_key' => 'NOTIFICATION_AD_PURCHASE:' . $ad->id,
                    'description' => 'Bildirim reklamı: ' . (NotificationAd::AUDIENCE_NAMES[$ad->audience] ?? $ad->audience),
                ]);
                $wallet->balance = FinancialService::formatFromCents(FinancialService::parseToCents($wallet->balance) - $priceCents);
                $wallet->save();
            }

            return $ad;
        });

        $this->fulfil($ad);

        return $ad->refresh();
    }

    // ───────────────────────────────────────────────────────────── card (PayTR)

    /**
     * @return array{ad: NotificationAd, token: string, iframe_url: string}
     */
    public function startCardOrder(User $provider, array $input, ?string $ip = null): array
    {
        $prepared = $this->prepare($provider, $input);
        $priceCents = FinancialService::parseToCents($prepared['price']);
        if ($priceCents <= 0) {
            throw ValidationException::withMessages(['audience' => ['Ücretsiz bir bildirim için kart ödemesi gerekmez.']]);
        }
        if (!$this->cardEnabled()) {
            throw ValidationException::withMessages(['audience' => ['Kartla ödeme şu anda kullanılamıyor. Cüzdan bakiyenizle ödeyebilirsiniz.']]);
        }

        $ad = NotificationAd::create($this->attributes($provider, $prepared) + [
            'status' => NotificationAd::STATUS_PENDING_PAYMENT,
            'payment_source' => NotificationAd::SOURCE_CARD,
            'merchant_oid' => $this->paytr->generateMerchantOid(NotificationAd::OID_PREFIX),
            'user_ip' => $ip,
        ]);

        try {
            $token = $this->paytr->requestHostedToken(
                $ad->merchant_oid,
                $priceCents,
                [['Bildirim Reklamı - ' . (NotificationAd::AUDIENCE_NAMES[$ad->audience] ?? $ad->audience), number_format($priceCents / 100, 2, '.', ''), 1]],
                $provider->email ?: 'usta@berberimgelsin.com',
                $provider->name ?: 'Hizmet Veren',
                $provider->phone ?: '05555555555',
                $ip,
            );
        } catch (\Throwable $e) {
            $ad->forceFill(['status' => NotificationAd::STATUS_FAILED, 'failure_message' => mb_substr($e->getMessage(), 0, 250)])->save();
            Log::warning('Notification ad card token failed', ['ad_id' => $ad->id, 'error' => $e->getMessage()]);

            throw ValidationException::withMessages(['audience' => [$e instanceof \LogicException
                ? 'Kartla ödeme şu anda kullanılamıyor.'
                : 'Ödeme oturumu açılamadı. Lütfen tekrar deneyin.']]);
        }

        return ['ad' => $ad, 'token' => $token['token'], 'iframe_url' => $token['iframe_url']];
    }

    /** PayTR server-to-server notification for an NA… merchant_oid. Always acknowledged with OK once the signature is valid. */
    public function handleCallback(array $payload): string
    {
        return DB::transaction(function () use ($payload) {
            $ad = NotificationAd::where('merchant_oid', $payload['merchant_oid'])->lockForUpdate()->first();
            if (!$ad || $ad->status !== NotificationAd::STATUS_PENDING_PAYMENT) {
                return 'OK';
            }

            if (strtolower((string) ($payload['status'] ?? '')) === 'success') {
                $paidMinor = (int) ($payload['payment_amount'] ?? $payload['total_amount'] ?? 0);
                $expectedMinor = FinancialService::parseToCents($ad->amount);
                if ($paidMinor < $expectedMinor) {
                    $ad->forceFill([
                        'status' => NotificationAd::STATUS_FAILED,
                        'failure_message' => "Beklenen tutar ({$expectedMinor}) ile ödenen ({$paidMinor}) eşleşmiyor.",
                        'callback_payload' => $payload,
                    ])->save();

                    return 'OK';
                }
                $this->markPaid($ad, $payload);

                return 'OK';
            }

            $ad->forceFill([
                'status' => NotificationAd::STATUS_FAILED,
                'failure_message' => mb_substr((string) ($payload['failed_reason_msg'] ?? 'Ödeme tamamlanamadı.'), 0, 250),
                'callback_payload' => $payload,
            ])->save();

            return 'OK';
        });
    }

    /** Status for the provider's screen; a pending card payment is checked against PayTR once. */
    public function refresh(NotificationAd $ad): NotificationAd
    {
        if ($ad->status !== NotificationAd::STATUS_PENDING_PAYMENT || !$this->cardEnabled() || $ad->created_at->gt(now()->subSeconds(15))) {
            return $ad;
        }

        $res = $this->paytr->queryPaymentStatus($ad->merchant_oid);
        if (($res['status'] ?? null) !== 'success' || strtolower((string) ($res['payment_status'] ?? '')) !== 'success') {
            return $ad;
        }

        $paidMinor = (int) round(((float) ($res['payment_amount'] ?? $res['payment_total'] ?? 0)) * 100);
        $expectedMinor = FinancialService::parseToCents($ad->amount);
        if ($paidMinor > 0 && $paidMinor < $expectedMinor) {
            return $ad;
        }

        DB::transaction(function () use ($ad, $res) {
            $locked = NotificationAd::where('id', $ad->id)->lockForUpdate()->first();
            if ($locked && $locked->status === NotificationAd::STATUS_PENDING_PAYMENT) {
                $this->markPaid($locked, $res);
            }
        });

        return $ad->refresh();
    }

    private function markPaid(NotificationAd $ad, array $payload): void
    {
        $ad->forceFill([
            'status' => NotificationAd::STATUS_QUEUED,
            'paid_at' => now(),
            'failure_message' => null,
            'callback_payload' => $payload,
        ])->save();

        DB::afterCommit(fn () => $this->fulfil($ad->refresh()));
    }

    // ───────────────────────────────────────────────────────────── sending

    /** Paid: the discount starts now and the notifications go out (queued, in chunks). Idempotent. */
    public function fulfil(NotificationAd $ad): void
    {
        if ($ad->status !== NotificationAd::STATUS_QUEUED) {
            return;
        }
        if (!$ad->discount()->exists()) {
            $this->discounts->start((int) $ad->provider_user_id, (int) $ad->discount_percent, (int) $ad->discount_days, $ad->id);
        }

        DeliverNotificationAd::dispatch($ad->id);
    }

    /** Creates the notification of every recipient (and their push); called by the queued job. */
    public function deliver(NotificationAd $ad): void
    {
        if ($ad->status !== NotificationAd::STATUS_QUEUED) {
            return;
        }

        $profile = ProviderProfile::query()->with(['user', 'documents'])->where('user_id', $ad->provider_user_id)->first();
        if (!$profile) {
            $ad->forceFill(['status' => NotificationAd::STATUS_FAILED, 'failure_message' => 'Hizmet veren bulunamadı.'])->save();

            return;
        }

        $name = $profile->business_name ?: $profile->user?->name ?: 'Hizmet Veren';
        $validUntil = now()->addDays((int) $ad->discount_days);
        $title = sprintf('%%%d indirim · %s', $ad->discount_percent, $name);
        $message = sprintf('%s — %s', $ad->title, $ad->body);
        $metadata = [
            'ad_id' => $ad->id,
            'provider_user_id' => $ad->provider_user_id,
            'provider_name' => $name,
            'is_verified' => $profile->isVerified(),
            'headline' => $ad->title,
            'description' => $ad->body,
            'discount_percent' => (int) $ad->discount_percent,
            'valid_until' => $validUntil->toIso8601String(),
        ];

        $count = 0;
        $this->recipientQuery($profile, $ad->audience, $ad->province, $ad->district)
            ->select('users.id')
            ->chunkById(500, function ($users) use ($ad, $title, $message, $metadata, &$count) {
                foreach ($users as $user) {
                    $notification = $this->notifications->notifyUser(
                        (int) $user->id,
                        UserNotification::TYPE_PROVIDER_CAMPAIGN,
                        $title,
                        $message,
                        UserNotification::RESOURCE_PROVIDER_PROFILE,
                        $ad->provider_user_id,
                        '/p/detail?id=' . $ad->provider_user_id,
                        $metadata,
                        'NOTIFICATION_AD:' . $ad->id . ':' . $user->id
                    );
                    if ($notification?->wasRecentlyCreated) {
                        $count++;
                    }
                }
            }, 'users.id', 'id');

        $ad->forceFill(['status' => NotificationAd::STATUS_SENT, 'recipients_count' => $count, 'sent_at' => now()])->save();
        $this->notifications->notifyUser(
            (int) $ad->provider_user_id,
            UserNotification::TYPE_FEATURED_STARTED,
            'Bildirim reklamınız gönderildi',
            sprintf('"%s" bildirimi %d kullanıcıya gönderildi. %%%d indirim %d gün boyunca fiyatlarınıza uygulanır.', $ad->title, $count, $ad->discount_percent, $ad->discount_days),
            'NOTIFICATION_AD',
            $ad->id,
            null,
            [],
            'NOTIFICATION_AD_SENT:' . $ad->id
        );
    }

    // ───────────────────────────────────────────────────────────── helpers

    private function attributes(User $provider, array $prepared): array
    {
        $d = $prepared['data'];

        return [
            'provider_user_id' => $provider->id,
            'audience' => $d['audience'],
            'province' => $d['audience'] === NotificationAd::AUDIENCE_LOCATION ? $d['province'] : null,
            'district' => $d['audience'] === NotificationAd::AUDIENCE_LOCATION && $d['district'] ? $d['district'] : null,
            'title' => $d['title'],
            'body' => $d['body'],
            'discount_percent' => $d['discount_percent'],
            'discount_days' => $d['discount_days'],
            'amount' => FinancialService::formatFromCents(FinancialService::parseToCents($prepared['price'])),
        ];
    }

    /** What the provider's screen shows next to the form. */
    public function overview(User $provider): array
    {
        $settings = NotificationAdSetting::current();
        $discount = $this->discounts->activeFor($provider->id);
        $sentToday = NotificationAd::query()->where('provider_user_id', $provider->id)
            ->whereIn('status', [NotificationAd::STATUS_QUEUED, NotificationAd::STATUS_SENT])
            ->where('created_at', '>=', now()->subDay())->count();
        $wallet = Wallet::query()->where('user_id', $provider->id)->first();
        $cardEnabled = $this->cardEnabled();

        $profile = ProviderProfile::query()->with('documents')->where('user_id', $provider->id)->first();

        return $settings->present() + [
            // How the notification will name the provider (the preview in the form shows exactly this).
            'provider_name' => $profile?->business_name ?: $provider->name,
            'is_verified' => (bool) $profile?->isVerified(),
            'active_discount' => $discount?->present(),
            'sends_left_today' => max(0, $settings->max_sends_per_provider_per_day - $sentToday),
            'provinces' => $this->provinces(),
            'wallet' => [
                'usable_cash_balance' => $wallet ? (float) $wallet->usable_cash_balance : 0.0,
                'is_frozen' => (bool) ($wallet?->is_frozen),
            ],
            'payment' => [
                'wallet_enabled' => true,
                'card_enabled' => $cardEnabled,
                'card_unavailable_reason' => $cardEnabled ? null : 'Kartla ödeme şu anda kullanılamıyor.',
            ],
            'history' => NotificationAd::query()->where('provider_user_id', $provider->id)
                ->whereIn('status', [NotificationAd::STATUS_QUEUED, NotificationAd::STATUS_SENT])
                ->latest('id')->limit(10)->get()->map->present()->values()->all(),
        ];
    }
}
