<?php

namespace App\Services;

use App\Models\BirthdayGreetingDelivery;
use App\Models\NotificationAbuseAlert;
use App\Models\NotificationAd;
use App\Models\NotificationAdSetting;
use App\Models\NotificationDispatch;
use App\Models\NotificationDispatchRecipient;
use App\Models\ProviderNotificationControl;
use App\Models\ProviderProfile;
use App\Models\User;
use App\Models\Wallet;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

/**
 * Shared read/reporting queries for both the Admin Notification Control Center
 * and each provider's scoped self-service report. Strictly strips customer birth dates,
 * addresses, contact details, and FCM tokens.
 */
class NotificationReportService
{
    public function __construct(
        private BirthdayAssistantService $birthdays,
    ) {}

    public function adminOverview(): array
    {
        $now = now();
        $todayStart = $now->copy()->startOfDay();
        $days7Start = $now->copy()->subDays(7);
        $days30Start = $now->copy()->subDays(30);

        $allDispatches = NotificationDispatch::query();
        $revenueFilter = NotificationDispatch::query()
            ->whereIn('status', [
                NotificationDispatch::STATUS_QUEUED,
                NotificationDispatch::STATUS_PROCESSING,
                NotificationDispatch::STATUS_COMPLETED,
                NotificationDispatch::STATUS_PARTIAL,
            ]);

        $totalPromo = (float) (clone $revenueFilter)->sum('captured_promo_amount');
        $totalCash = (float) (clone $revenueFilter)->where('balance_source', '!=', NotificationDispatch::SOURCE_CARD)->sum('captured_cash_amount');
        $totalCard = (float) (clone $revenueFilter)->where('balance_source', NotificationDispatch::SOURCE_CARD)->sum('total_cost');
        $totalRefunded = (float) NotificationDispatch::query()->sum(DB::raw('COALESCE(refunded_promo_amount, 0) + COALESCE(refunded_cash_amount, 0)'));

        $restrictedCount = ProviderNotificationControl::query()
            ->where(function ($q) use ($now) {
                $q->where(fn ($a) => $a->where('can_send_notification_ads', false)->whereNull('notification_ads_blocked_until'))
                    ->orWhere(fn ($b) => $b->where('can_send_birthday_greetings', false)->whereNull('birthday_blocked_until'))
                    ->orWhere(fn ($c) => $c->where('can_send_auto_special_day', false)->whereNull('auto_special_day_blocked_until'))
                    ->orWhere('notification_ads_blocked_until', '>', $now)
                    ->orWhere('birthday_blocked_until', '>', $now)
                    ->orWhere('auto_special_day_blocked_until', '>', $now)
                    ->orWhereNotNull('daily_paid_notification_limit')
                    ->orWhereNotNull('daily_unique_recipient_limit');
            })->count();

        $openAlertsCount = NotificationAbuseAlert::query()->where('status', NotificationAbuseAlert::STATUS_OPEN)->count();
        $recentAlerts = NotificationAbuseAlert::query()
            ->with('provider.providerProfile')
            ->where('status', NotificationAbuseAlert::STATUS_OPEN)
            ->latest('id')
            ->limit(10)
            ->get()
            ->map->present()
            ->values()
            ->all();

        return [
            'totals' => [
                'total_dispatches' => (clone $allDispatches)->count(),
                'total_targeted_users' => (int) (clone $allDispatches)->sum('targeted_count'),
                'total_eligible_users' => (int) (clone $allDispatches)->sum('eligible_count'),
                'total_attempted' => (int) (clone $allDispatches)->sum('attempted_count'),
                'total_fcm_accepted' => (int) (clone $allDispatches)->sum('fcm_accepted_count'),
                'total_failed' => (int) (clone $allDispatches)->sum('failed_count'),
                'total_skipped' => (int) (clone $allDispatches)->sum('skipped_count'),
                'active_providers_count' => (int) (clone $allDispatches)->distinct('provider_user_id')->count('provider_user_id'),
                'restricted_providers_count' => $restrictedCount,
                'open_alerts_count' => $openAlertsCount,
            ],
            'revenue' => [
                'today' => (float) (clone $revenueFilter)->where('created_at', '>=', $todayStart)->sum('total_cost'),
                'last_7_days' => (float) (clone $revenueFilter)->where('created_at', '>=', $days7Start)->sum('total_cost'),
                'last_30_days' => (float) (clone $revenueFilter)->where('created_at', '>=', $days30Start)->sum('total_cost'),
                'total' => (float) (clone $revenueFilter)->sum('total_cost'),
                'promo_spent_total' => $totalPromo,
                'cash_spent_total' => $totalCash,
                'card_spent_total' => $totalCard,
                'refunded_total' => $totalRefunded,
            ],
            'delivery_disclaimer' => 'FCM tarafından kabul edilen bildirimler Google/Apple push sunucusuna başarıyla iletildiğini gösterir; son kullanıcının cihaz ayarları, pil optimizasyonu veya internet durumuna göre bildirim gösterimi garanti edilmez.',
            'open_alerts' => $recentAlerts,
        ];
    }

    /** Privacy-safe per-provider self-service report. NEVER exposes other providers or customer birth dates. */
    public function providerReport(User $provider, ?NotificationAdSetting $settings = null): array
    {
        $settings ??= NotificationAdSetting::current();
        $profile = ProviderProfile::query()->where('user_id', $provider->id)->first();
        $wallet = Wallet::query()->where('user_id', $provider->id)->first();
        $control = ProviderNotificationControl::forProvider($provider->id);
        $monthStart = now()->startOfMonth();

        $monthDispatches = NotificationDispatch::query()
            ->where('provider_user_id', $provider->id)
            ->where('created_at', '>=', $monthStart);

        $paidCountMonth = (int) NotificationDispatchRecipient::query()
            ->where('provider_user_id', $provider->id)
            ->where('created_at', '>=', $monthStart)
            ->whereIn('billing_status', [
                NotificationDispatchRecipient::BILLING_CAPTURED,
                NotificationDispatchRecipient::BILLING_RESERVED,
                NotificationDispatchRecipient::BILLING_CHARGED_CAMPAIGN,
            ])
            ->count();

        $paidCampaignsMonth = (int) (clone $monthDispatches)
            ->where('notification_type', NotificationDispatch::TYPE_NOTIFICATION_AD)
            ->where('total_cost', '>', 0)
            ->whereIn('status', [
                NotificationDispatch::STATUS_QUEUED,
                NotificationDispatch::STATUS_PROCESSING,
                NotificationDispatch::STATUS_COMPLETED,
                NotificationDispatch::STATUS_PARTIAL,
            ])
            ->count();

        $monthPromoSpent = (float) (clone $monthDispatches)->sum('captured_promo_amount');
        $monthCashSpent = (float) (clone $monthDispatches)->where('balance_source', '!=', NotificationDispatch::SOURCE_CARD)->sum('captured_cash_amount');
        $monthCardSpent = (float) (clone $monthDispatches)->where('balance_source', NotificationDispatch::SOURCE_CARD)->sum('total_cost');

        $fcmAcceptedMonth = (int) (clone $monthDispatches)->sum('fcm_accepted_count');
        $failedMonth = (int) (clone $monthDispatches)->sum('failed_count');
        $skippedMonth = (int) (clone $monthDispatches)->sum('skipped_count');

        $upcomingBirthdays = $profile ? $this->birthdays->upcomingEligibleCount($profile, 30) : 0;

        $birthdayHistory = NotificationDispatch::query()
            ->where('provider_user_id', $provider->id)
            ->where('notification_type', NotificationDispatch::TYPE_BIRTHDAY_GREETING)
            ->latest('id')
            ->limit(15)
            ->get()
            ->map(fn (NotificationDispatch $d) => [
                'id' => $d->id,
                'reference_code' => $d->reference_code,
                'title' => $d->title,
                'unit_price' => (float) $d->unit_price,
                'total_cost' => (float) $d->total_cost,
                'captured_promo_amount' => (float) $d->captured_promo_amount,
                'captured_cash_amount' => (float) $d->captured_cash_amount,
                'balance_source' => $d->balance_source,
                'balance_source_label' => NotificationDispatch::SOURCE_LABELS[$d->balance_source] ?? $d->balance_source,
                'targeted_count' => (int) $d->targeted_count,
                'fcm_accepted_count' => (int) $d->fcm_accepted_count,
                'failed_count' => (int) $d->failed_count,
                'skipped_count' => (int) $d->skipped_count,
                'status' => $d->status,
                'status_label' => NotificationDispatch::STATUS_LABELS[$d->status] ?? $d->status,
                'sent_at' => $d->sent_at?->toISOString(),
                'created_at' => $d->created_at?->toISOString(),
            ])
            ->values()
            ->all();

        $adHistory = NotificationAd::query()
            ->with('dispatch')
            ->where('provider_user_id', $provider->id)
            ->whereIn('status', [
                NotificationAd::STATUS_QUEUED,
                NotificationAd::STATUS_SENT,
                NotificationAd::STATUS_FAILED,
                NotificationAd::STATUS_BLOCKED,
            ])
            ->latest('id')
            ->limit(15)
            ->get()
            ->map(fn (NotificationAd $ad) => $ad->present() + [
                'fcm_accepted_count' => (int) ($ad->dispatch?->fcm_accepted_count ?? 0),
                'failed_count' => (int) ($ad->dispatch?->failed_count ?? 0),
                'skipped_count' => (int) ($ad->dispatch?->skipped_count ?? 0),
            ])
            ->values()
            ->all();

        return [
            'wallet' => [
                'usable_promo_balance' => $wallet ? (float) $wallet->usable_promo_balance : 0.0,
                'usable_cash_balance' => $wallet ? (float) $wallet->usable_cash_balance : 0.0,
                'reserved_promo_balance' => $wallet ? (float) $wallet->reserved_promo_balance : 0.0,
                'reserved_cash_balance' => $wallet ? (float) $wallet->reserved_cash_balance : 0.0,
                'is_frozen' => (bool) ($wallet?->is_frozen),
            ],
            'pricing' => [
                'birthday_unit_price' => (float) ($settings->birthday_unit_price ?? 0),
                'allow_promo_for_birthday' => (bool) ($settings->allow_promo_for_birthday ?? true),
                'allow_promo_for_notification_ads' => (bool) ($settings->allow_promo_for_notification_ads ?? true),
                'fallback_to_cash_when_promo_insufficient' => (bool) ($settings->fallback_to_cash_when_promo_insufficient ?? true),
            ],
            'permissions' => $control->present($settings),
            'monthly_summary' => [
                'month' => Carbon::now()->format('Y-m'),
                'paid_notifications_count' => $paidCountMonth > 0 ? $paidCountMonth : $paidCampaignsMonth,
                'paid_campaigns_count' => $paidCampaignsMonth,
                'promo_spent' => $monthPromoSpent,
                'cash_spent' => $monthCashSpent,
                'card_spent' => $monthCardSpent,
                'total_spent' => round($monthPromoSpent + $monthCashSpent + $monthCardSpent, 2),
                'fcm_accepted_count' => $fcmAcceptedMonth,
                'failed_count' => $failedMonth,
                'skipped_count' => $skippedMonth,
            ],
            'upcoming_eligible_birthdays_30d' => $upcomingBirthdays,
            'birthday_history' => $birthdayHistory,
            'notification_ad_history' => $adHistory,
        ];
    }
}
