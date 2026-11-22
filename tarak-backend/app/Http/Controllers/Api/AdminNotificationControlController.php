<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AdminLog;
use App\Models\BirthdayGreetingDelivery;
use App\Models\NotificationAbuseAlert;
use App\Models\NotificationAd;
use App\Models\NotificationAdSetting;
use App\Models\NotificationDispatch;
use App\Models\NotificationDispatchRecipient;
use App\Models\ProviderNotificationControl;
use App\Models\ProviderProfile;
use App\Models\User;
use App\Services\FinancialService;
use App\Services\NotificationBillingService;
use App\Services\NotificationReportService;
use App\Services\ProviderDiscountService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

/**
 * Admin Notification Control Center API:
 * - Overview metrics, revenue (today/7d/30d/total), promo vs cash vs card, open abuse alerts
 * - Paginated dispatch history & per-dispatch privacy-safe recipient delivery audit
 * - Per-provider permissions (notification ads / birthday / auto special day), blocks & daily limits
 * - Birthday per-recipient pricing, promo balance toggles, and abuse thresholds
 */
class AdminNotificationControlController extends Controller
{
    public function __construct(
        private NotificationReportService $reports,
        private NotificationBillingService $billing,
        private ProviderDiscountService $discounts,
    ) {}

    public function overview(): JsonResponse
    {
        return response()->json([
            'success' => true,
            'data' => $this->reports->adminOverview() + [
                'settings' => NotificationAdSetting::current()->presentForAdmin(),
            ],
        ]);
    }

    public function dispatches(Request $request): JsonResponse
    {
        $perPage = max(1, min(100, (int) $request->query('per_page', 20)));
        $q = trim((string) $request->query('q', ''));
        $type = strtoupper(trim((string) $request->query('type', '')));
        $status = strtoupper(trim((string) $request->query('status', '')));
        $balanceSource = strtoupper(trim((string) $request->query('balance_source', '')));
        $providerId = $request->filled('provider_id') ? (int) $request->query('provider_id') : null;
        $dateFrom = trim((string) $request->query('date_from', ''));
        $dateTo = trim((string) $request->query('date_to', ''));

        $query = NotificationDispatch::query()
            ->with(['provider:id,name,email', 'providerProfile:id,user_id,business_name,city'])
            ->latest('id');

        if ($type !== '') {
            $query->where('notification_type', $type);
        }
        if ($status !== '') {
            $query->where('status', $status);
        }
        if ($balanceSource !== '') {
            $query->where('balance_source', $balanceSource);
        }
        if ($providerId) {
            $query->where('provider_user_id', $providerId);
        }
        if ($dateFrom !== '') {
            $query->where('created_at', '>=', Carbon::parse($dateFrom)->startOfDay());
        }
        if ($dateTo !== '') {
            $query->where('created_at', '<=', Carbon::parse($dateTo)->endOfDay());
        }
        if ($q !== '') {
            $like = '%' . str_replace(['%', '_'], ['\\%', '\\_'], $q) . '%';
            $query->where(function ($w) use ($like, $q) {
                $w->where('title', 'like', $like)
                    ->orWhere('body', 'like', $like)
                    ->orWhere('reference_code', 'like', $like)
                    ->orWhereHas('provider', fn ($u) => $u->where('name', 'like', $like))
                    ->orWhereHas('providerProfile', fn ($p) => $p->where('business_name', 'like', $like))
                    ->when(ctype_digit($q), fn ($num) => $num->orWhere('provider_user_id', (int) $q)->orWhere('id', (int) $q));
            });
        }

        $page = $query->paginate($perPage);

        return response()->json([
            'success' => true,
            'data' => collect($page->items())->map->present()->values(),
            'meta' => [
                'total' => $page->total(),
                'page' => $page->currentPage(),
                'last_page' => $page->lastPage(),
                'per_page' => $page->perPage(),
            ],
        ]);
    }

    public function showDispatch(int $id): JsonResponse
    {
        $dispatch = NotificationDispatch::query()
            ->with(['provider:id,name', 'providerProfile:id,user_id,business_name,city'])
            ->findOrFail($id);

        return response()->json([
            'success' => true,
            'data' => $dispatch->present() + [
                'delivery_disclaimer' => 'FCM tarafından kabul edildi durumu, push sunucusunun isteği aldığını ifade eder; son kullanıcı cihazında gösterim garantisi anlamına gelmez.',
            ],
        ]);
    }

    /**
     * Paginated recipient audit for a dispatch.
     * Strictly exposes display_name + user_id + delivery attempt state; NEVER birth_date, address, email, phone, or FCM token.
     */
    public function dispatchRecipients(Request $request, int $id): JsonResponse
    {
        $dispatch = NotificationDispatch::query()->findOrFail($id);
        $perPage = max(1, min(100, (int) $request->query('per_page', 25)));
        $q = trim((string) $request->query('q', ''));
        $deliveryStatus = strtoupper(trim((string) $request->query('delivery_status', '')));

        $query = NotificationDispatchRecipient::query()
            ->where('dispatch_id', $dispatch->id)
            ->with(['recipient:id,name'])
            ->orderBy('id');

        if ($deliveryStatus !== '') {
            $query->where('delivery_status', $deliveryStatus);
        }
        if ($q !== '') {
            $like = '%' . str_replace(['%', '_'], ['\\%', '\\_'], $q) . '%';
            $query->where(function ($w) use ($like, $q) {
                $w->whereHas('recipient', fn ($u) => $u->where('name', 'like', $like))
                    ->when(ctype_digit($q), fn ($num) => $num->orWhere('recipient_user_id', (int) $q));
            });
        }

        $page = $query->paginate($perPage);

        return response()->json([
            'success' => true,
            'dispatch' => $dispatch->present(),
            'data' => collect($page->items())->map->presentForAdmin()->values(),
            'meta' => [
                'total' => $page->total(),
                'page' => $page->currentPage(),
                'last_page' => $page->lastPage(),
                'per_page' => $page->perPage(),
            ],
        ]);
    }

    public function providers(Request $request): JsonResponse
    {
        $perPage = max(1, min(100, (int) $request->query('per_page', 25)));
        $q = trim((string) $request->query('q', ''));
        $restrictedOnly = $request->query('restricted') === '1' || $request->query('restricted') === 'true';

        $settings = NotificationAdSetting::current();
        $since30d = now()->subDays(30);

        $query = User::query()
            ->where('role', User::ROLE_PROVIDER)
            ->with(['providerProfile:id,user_id,business_name,city,district,is_approved,identity_status', 'wallet', 'notificationControl'])
            ->latest('id');

        if ($q !== '') {
            $like = '%' . str_replace(['%', '_'], ['\\%', '\\_'], $q) . '%';
            $query->where(function ($w) use ($like, $q) {
                $w->where('name', 'like', $like)
                    ->orWhereHas('providerProfile', fn ($p) => $p->where('business_name', 'like', $like)->orWhere('city', 'like', $like))
                    ->when(ctype_digit($q), fn ($num) => $num->orWhere('id', (int) $q));
            });
        }

        if ($restrictedOnly) {
            $now = now();
            $query->whereHas('notificationControl', function ($c) use ($now) {
                $c->where(fn ($a) => $a->where('can_send_notification_ads', false)->whereNull('notification_ads_blocked_until'))
                    ->orWhere(fn ($b) => $b->where('can_send_birthday_greetings', false)->whereNull('birthday_blocked_until'))
                    ->orWhere(fn ($d) => $d->where('can_send_auto_special_day', false)->whereNull('auto_special_day_blocked_until'))
                    ->orWhere('notification_ads_blocked_until', '>', $now)
                    ->orWhere('birthday_blocked_until', '>', $now)
                    ->orWhere('auto_special_day_blocked_until', '>', $now)
                    ->orWhereNotNull('daily_paid_notification_limit')
                    ->orWhereNotNull('daily_unique_recipient_limit');
            });
        }

        $page = $query->paginate($perPage);
        $providerIds = collect($page->items())->pluck('id')->all();

        $stats30d = NotificationDispatch::query()
            ->whereIn('provider_user_id', $providerIds)
            ->where('created_at', '>=', $since30d)
            ->selectRaw('provider_user_id, count(*) as dispatch_count, sum(eligible_count) as recipients_total, sum(fcm_accepted_count) as accepted_total, sum(total_cost) as spent_total, sum(captured_promo_amount) as promo_total, sum(captured_cash_amount) as cash_total')
            ->groupBy('provider_user_id')
            ->get()
            ->keyBy('provider_user_id');

        $openAlertsByProvider = NotificationAbuseAlert::query()
            ->whereIn('provider_user_id', $providerIds)
            ->where('status', NotificationAbuseAlert::STATUS_OPEN)
            ->selectRaw('provider_user_id, count(*) as alert_count')
            ->groupBy('provider_user_id')
            ->pluck('alert_count', 'provider_user_id');

        $rows = collect($page->items())->map(function (User $u) use ($stats30d, $openAlertsByProvider, $settings) {
            $s = $stats30d->get($u->id);
            $control = $u->notificationControl ?: ProviderNotificationControl::forProvider($u->id);

            return [
                'provider_user_id' => (int) $u->id,
                'name' => $u->name,
                'business_name' => $u->providerProfile?->business_name ?: $u->name,
                'city' => $u->providerProfile?->city,
                'district' => $u->providerProfile?->district,
                'wallet' => [
                    'usable_promo_balance' => $u->wallet ? (float) $u->wallet->usable_promo_balance : 0.0,
                    'usable_cash_balance' => $u->wallet ? (float) $u->wallet->usable_cash_balance : 0.0,
                    'is_frozen' => (bool) ($u->wallet?->is_frozen),
                ],
                'stats_30d' => [
                    'dispatches' => (int) ($s->dispatch_count ?? 0),
                    'recipients' => (int) ($s->recipients_total ?? 0),
                    'fcm_accepted' => (int) ($s->accepted_total ?? 0),
                    'spent_total' => (float) ($s->spent_total ?? 0),
                    'promo_spent' => (float) ($s->promo_total ?? 0),
                    'cash_spent' => (float) ($s->cash_total ?? 0),
                ],
                'open_alerts_count' => (int) ($openAlertsByProvider[$u->id] ?? 0),
                'controls' => $control->present($settings),
            ];
        })->values();

        return response()->json([
            'success' => true,
            'data' => $rows,
            'meta' => [
                'total' => $page->total(),
                'page' => $page->currentPage(),
                'last_page' => $page->lastPage(),
                'per_page' => $page->perPage(),
            ],
        ]);
    }

    public function updateProviderControls(Request $request, int $providerUserId): JsonResponse
    {
        $provider = User::where('role', User::ROLE_PROVIDER)->findOrFail($providerUserId);
        $settings = NotificationAdSetting::current();

        $validated = $request->validate([
            'block_mode' => ['nullable', 'string', 'in:enable,indefinite,until'],
            'can_send_notification_ads' => ['sometimes', 'boolean'],
            'can_send_birthday_greetings' => ['sometimes', 'boolean'],
            'can_send_auto_special_day' => ['sometimes', 'boolean'],
            'blocked_until' => ['nullable', 'date'],
            'notification_ads_blocked_until' => ['nullable', 'date'],
            'birthday_blocked_until' => ['nullable', 'date'],
            'auto_special_day_blocked_until' => ['nullable', 'date'],
            'daily_paid_notification_limit' => ['nullable', 'integer', 'min:0', 'max:100000'],
            'daily_unique_recipient_limit' => ['nullable', 'integer', 'min:0', 'max:100000'],
            'reason' => ['nullable', 'string', 'max:500'],
        ]);

        $control = ProviderNotificationControl::firstOrNew(
            ['provider_user_id' => $provider->id],
            [
                'can_send_notification_ads' => true,
                'can_send_birthday_greetings' => true,
                'can_send_auto_special_day' => true,
            ]
        );
        $before = $control->present($settings);

        $mode = $validated['block_mode'] ?? null;
        if ($mode === 'enable') {
            $control->can_send_notification_ads = true;
            $control->notification_ads_blocked_until = null;
            $control->can_send_birthday_greetings = true;
            $control->birthday_blocked_until = null;
            $control->can_send_auto_special_day = true;
            $control->auto_special_day_blocked_until = null;
            $control->is_auto_restricted = false;
        } elseif ($mode === 'indefinite' || $mode === 'until') {
            $until = ($mode === 'until' && !empty($validated['blocked_until']))
                ? Carbon::parse($validated['blocked_until'])
                : null;
            if (array_key_exists('can_send_notification_ads', $validated)) {
                $control->can_send_notification_ads = (bool) $validated['can_send_notification_ads'];
                $control->notification_ads_blocked_until = !$control->can_send_notification_ads ? $until : null;
            }
            if (array_key_exists('can_send_birthday_greetings', $validated)) {
                $control->can_send_birthday_greetings = (bool) $validated['can_send_birthday_greetings'];
                $control->birthday_blocked_until = !$control->can_send_birthday_greetings ? $until : null;
            }
            if (array_key_exists('can_send_auto_special_day', $validated)) {
                $control->can_send_auto_special_day = (bool) $validated['can_send_auto_special_day'];
                $control->auto_special_day_blocked_until = !$control->can_send_auto_special_day ? $until : null;
            }
            // If caller specified block_mode without per-channel flags, apply to all three outbound channels.
            if (!array_key_exists('can_send_notification_ads', $validated)
                && !array_key_exists('can_send_birthday_greetings', $validated)
                && !array_key_exists('can_send_auto_special_day', $validated)) {
                $control->can_send_notification_ads = false;
                $control->notification_ads_blocked_until = $until;
                $control->can_send_birthday_greetings = false;
                $control->birthday_blocked_until = $until;
                $control->can_send_auto_special_day = false;
                $control->auto_special_day_blocked_until = $until;
            }
            $control->is_auto_restricted = false;
        } else {
            if (array_key_exists('can_send_notification_ads', $validated)) {
                $control->can_send_notification_ads = (bool) $validated['can_send_notification_ads'];
                $control->notification_ads_blocked_until = $control->can_send_notification_ads
                    ? null
                    : (!empty($validated['notification_ads_blocked_until']) ? Carbon::parse($validated['notification_ads_blocked_until']) : null);
            }
            if (array_key_exists('can_send_birthday_greetings', $validated)) {
                $control->can_send_birthday_greetings = (bool) $validated['can_send_birthday_greetings'];
                $control->birthday_blocked_until = $control->can_send_birthday_greetings
                    ? null
                    : (!empty($validated['birthday_blocked_until']) ? Carbon::parse($validated['birthday_blocked_until']) : null);
            }
            if (array_key_exists('can_send_auto_special_day', $validated)) {
                $control->can_send_auto_special_day = (bool) $validated['can_send_auto_special_day'];
                $control->auto_special_day_blocked_until = $control->can_send_auto_special_day
                    ? null
                    : (!empty($validated['auto_special_day_blocked_until']) ? Carbon::parse($validated['auto_special_day_blocked_until']) : null);
            }
        }

        if (array_key_exists('daily_paid_notification_limit', $validated)) {
            $control->daily_paid_notification_limit = $validated['daily_paid_notification_limit'];
        }
        if (array_key_exists('daily_unique_recipient_limit', $validated)) {
            $control->daily_unique_recipient_limit = $validated['daily_unique_recipient_limit'];
        }

        $reason = trim((string) ($validated['reason'] ?? ''));
        $isBlockingNow = $control->isNotificationAdsBlocked() || $control->isBirthdayBlocked() || $control->isAutoSpecialDayBlocked();
        if ($isBlockingNow && $reason === '' && trim((string) $control->restriction_reason) === '') {
            return response()->json([
                'success' => false,
                'message' => 'Gönderim yetkisi kapatılırken engelleme gerekçesi yazılmalıdır.',
                'errors' => ['reason' => ['Gönderim yetkisi kapatılırken engelleme gerekçesi zorunludur.']],
            ], 422);
        }

        if ($reason !== '') {
            $control->restriction_reason = $reason;
        } elseif (!$isBlockingNow && $mode === 'enable') {
            $control->restriction_reason = null;
        }

        $control->restricted_by_admin_id = $request->user()->id;
        $control->restricted_at = now();
        $control->save();

        // Immediately halt & refund queued NotificationAds if notification_ads channel is now blocked.
        $stoppedAds = 0;
        if ($control->isNotificationAdsBlocked()) {
            $queuedAds = NotificationAd::query()
                ->where('provider_user_id', $provider->id)
                ->where('status', NotificationAd::STATUS_QUEUED)
                ->get();
            foreach ($queuedAds as $ad) {
                $ad->forceFill([
                    'status' => NotificationAd::STATUS_BLOCKED,
                    'failure_message' => $control->restriction_reason ?: 'Yönetici tarafından bildirim yetkisi kapatıldı.',
                ])->save();
                $this->discounts->end($provider->id);
                $this->billing->refundNotificationAdWallet($ad, $control->restriction_reason ?: 'Yönetici engeli');
                $stoppedAds++;
            }
        }

        $after = $control->present($settings);
        AdminLog::logAction(
            (int) $request->user()->id,
            AdminLog::ACTION_PROVIDER_NOTIFICATION_PERMISSION_UPDATED,
            AdminLog::TARGET_NOTIFICATION_CONTROL,
            $provider->id,
            [
                'provider_user_id' => $provider->id,
                'before' => $before,
                'after' => $after,
                'reason' => $control->restriction_reason,
                'stopped_queued_ads' => $stoppedAds,
            ]
        );

        return response()->json([
            'success' => true,
            'message' => 'Hizmet veren bildirim yetkileri güncellendi.',
            'data' => $after,
        ]);
    }

    public function birthdayDeliveries(Request $request): JsonResponse
    {
        $perPage = max(1, min(100, (int) $request->query('per_page', 25)));
        $q = trim((string) $request->query('q', ''));
        $providerId = $request->filled('provider_id') ? (int) $request->query('provider_id') : null;
        $billingStatus = strtoupper(trim((string) $request->query('billing_status', '')));
        $deliveryStatus = strtoupper(trim((string) $request->query('delivery_status', '')));

        $query = BirthdayGreetingDelivery::query()
            ->with([
                'providerProfile:id,user_id,business_name,city',
                'customer:id,name',
            ])
            ->latest('id');

        if ($providerId) {
            $query->whereHas('providerProfile', fn ($p) => $p->where('user_id', $providerId));
        }
        if ($billingStatus !== '') {
            $query->where('billing_status', $billingStatus);
        }
        if ($deliveryStatus !== '') {
            $query->where('delivery_status', $deliveryStatus);
        }
        if ($q !== '') {
            $like = '%' . str_replace(['%', '_'], ['\\%', '\\_'], $q) . '%';
            $query->where(function ($w) use ($like, $q) {
                $w->whereHas('providerProfile', fn ($p) => $p->where('business_name', 'like', $like))
                    ->orWhereHas('customer', fn ($c) => $c->where('name', 'like', $like))
                    ->when(ctype_digit($q), fn ($num) => $num->orWhere('customer_user_id', (int) $q));
            });
        }

        $page = $query->paginate($perPage);

        return response()->json([
            'success' => true,
            'data' => collect($page->items())->map(fn (BirthdayGreetingDelivery $d) => [
                'id' => $d->id,
                'dispatch_id' => $d->dispatch_id,
                'provider' => [
                    'user_id' => $d->providerProfile?->user_id,
                    'business_name' => $d->providerProfile?->business_name,
                    'city' => $d->providerProfile?->city,
                ],
                'recipient' => [
                    'user_id' => (int) $d->customer_user_id,
                    'display_name' => $d->customer?->name ?: ('Kullanıcı #' . $d->customer_user_id),
                ],
                'birthday_year' => (int) $d->birthday_year,
                'days_before' => (int) $d->days_before,
                'unit_price' => (float) ($d->unit_price ?? 0),
                'charged_amount' => (float) ($d->charged_amount ?? 0),
                'promo_amount' => (float) ($d->promo_amount ?? 0),
                'cash_amount' => (float) ($d->cash_amount ?? 0),
                'balance_source' => $d->balance_source ?: NotificationDispatch::SOURCE_NONE,
                'billing_status' => $d->billing_status ?: NotificationDispatchRecipient::BILLING_FREE,
                'delivery_status' => $d->delivery_status ?: NotificationDispatchRecipient::DELIVERY_QUEUED,
                'delivery_status_label' => NotificationDispatchRecipient::DELIVERY_LABELS[$d->delivery_status ?: 'QUEUED'] ?? ($d->delivery_status ?: 'QUEUED'),
                'failure_reason' => $d->failure_reason,
                'sent_at' => $d->sent_at?->toISOString(),
            ])->values(),
            'meta' => [
                'total' => $page->total(),
                'page' => $page->currentPage(),
                'last_page' => $page->lastPage(),
                'per_page' => $page->perPage(),
            ],
        ]);
    }

    public function settings(): JsonResponse
    {
        return response()->json([
            'success' => true,
            'data' => NotificationAdSetting::current()->presentForAdmin(),
        ]);
    }

    public function updateSettings(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'is_enabled' => ['sometimes', 'boolean'],
            'title' => ['sometimes', 'string', 'min:2', 'max:120'],
            'description' => ['sometimes', 'nullable', 'string', 'max:1000'],
            'price_service_area' => ['sometimes', 'numeric', 'min:0', 'max:1000000'],
            'price_location' => ['sometimes', 'numeric', 'min:0', 'max:1000000'],
            'price_all' => ['sometimes', 'numeric', 'min:0', 'max:1000000'],
            'min_discount_percent' => ['sometimes', 'integer', 'min:1', 'max:99'],
            'max_discount_percent' => ['sometimes', 'integer', 'min:1', 'max:99'],
            'max_discount_days' => ['sometimes', 'integer', 'min:1', 'max:365'],
            'max_sends_per_provider_per_day' => ['sometimes', 'integer', 'min:1', 'max:50'],
            'max_per_customer_per_day' => ['sometimes', 'integer', 'min:1', 'max:20'],
            'birthday_unit_price' => ['sometimes', 'numeric', 'min:0', 'max:100000'],
            'allow_promo_for_birthday' => ['sometimes', 'boolean'],
            'allow_promo_for_notification_ads' => ['sometimes', 'boolean'],
            'fallback_to_cash_when_promo_insufficient' => ['sometimes', 'boolean'],
            'default_daily_paid_notification_limit' => ['sometimes', 'integer', 'min:1', 'max:100000'],
            'default_daily_unique_recipient_limit' => ['sometimes', 'integer', 'min:1', 'max:100000'],
            'birthday_max_per_provider_per_day' => ['sometimes', 'integer', 'min:1', 'max:100000'],
            'duplicate_content_window_hours' => ['sometimes', 'integer', 'min:1', 'max:168'],
            'rapid_campaign_window_minutes' => ['sometimes', 'integer', 'min:5', 'max:1440'],
            'rapid_campaign_threshold' => ['sometimes', 'integer', 'min:2', 'max:50'],
            'auto_suspend_on_abuse' => ['sometimes', 'boolean'],
        ]);

        $settings = NotificationAdSetting::current();
        $min = $validated['min_discount_percent'] ?? $settings->min_discount_percent;
        $max = $validated['max_discount_percent'] ?? $settings->max_discount_percent;
        if ($min > $max) {
            return response()->json([
                'success' => false,
                'message' => 'En düşük indirim oranı en yüksekten büyük olamaz.',
                'errors' => ['min_discount_percent' => ['En düşük indirim oranı en yüksekten büyük olamaz.']],
            ], 422);
        }

        $before = $settings->presentForAdmin();
        $settings->update($validated);
        $after = $settings->fresh()->presentForAdmin();

        AdminLog::logAction(
            (int) $request->user()->id,
            AdminLog::ACTION_NOTIFICATION_CONTROL_SETTINGS_SAVED,
            AdminLog::TARGET_NOTIFICATION_CONTROL,
            (int) $settings->id,
            ['before' => $before, 'after' => $after]
        );

        return response()->json([
            'success' => true,
            'message' => 'Bildirim ücretlendirme ve limit ayarları kaydedildi.',
            'data' => $after,
        ]);
    }

    public function alerts(Request $request): JsonResponse
    {
        $perPage = max(1, min(100, (int) $request->query('per_page', 25)));
        $status = strtoupper(trim((string) $request->query('status', '')));

        $query = NotificationAbuseAlert::query()
            ->with('provider.providerProfile')
            ->latest('id');

        if ($status !== '') {
            $query->where('status', $status);
        }

        $page = $query->paginate($perPage);

        return response()->json([
            'success' => true,
            'data' => collect($page->items())->map->present()->values(),
            'meta' => [
                'total' => $page->total(),
                'page' => $page->currentPage(),
                'last_page' => $page->lastPage(),
            ],
        ]);
    }

    public function resolveAlert(Request $request, int $id): JsonResponse
    {
        $alert = NotificationAbuseAlert::findOrFail($id);
        $alert->update([
            'status' => NotificationAbuseAlert::STATUS_RESOLVED,
            'resolved_by_admin_id' => $request->user()->id,
            'resolved_at' => now(),
        ]);

        AdminLog::logAction(
            (int) $request->user()->id,
            AdminLog::ACTION_NOTIFICATION_ABUSE_ALERT_RESOLVED,
            AdminLog::TARGET_NOTIFICATION_ABUSE_ALERT,
            $alert->id,
            ['alert_type' => $alert->alert_type, 'provider_user_id' => $alert->provider_user_id]
        );

        return response()->json([
            'success' => true,
            'message' => 'Şüpheli gönderim uyarısı çözüldü olarak işaretlendi.',
            'data' => $alert->fresh()->present(),
        ]);
    }

    public function auditLogs(Request $request): JsonResponse
    {
        $perPage = max(1, min(100, (int) $request->query('per_page', 30)));
        $page = AdminLog::query()
            ->whereIn('action', [
                AdminLog::ACTION_NOTIFICATION_AD_SETTINGS_SAVED,
                AdminLog::ACTION_NOTIFICATION_CONTROL_SETTINGS_SAVED,
                AdminLog::ACTION_PROVIDER_NOTIFICATION_PERMISSION_UPDATED,
                AdminLog::ACTION_NOTIFICATION_ABUSE_ALERT_RESOLVED,
            ])
            ->with('adminUser:id,name')
            ->latest('id')
            ->paginate($perPage);

        return response()->json([
            'success' => true,
            'data' => collect($page->items())->map(fn (AdminLog $log) => [
                'id' => $log->id,
                'action' => $log->action,
                'target_type' => $log->target_type,
                'target_id' => $log->target_id,
                'admin' => $log->adminUser?->name,
                'metadata' => $log->metadata,
                'created_at' => $log->created_at?->toISOString(),
            ])->values(),
            'meta' => [
                'total' => $page->total(),
                'page' => $page->currentPage(),
                'last_page' => $page->lastPage(),
            ],
        ]);
    }
}
