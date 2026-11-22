<?php

namespace App\Services;

use App\Models\Appointment;
use App\Models\BirthdayGreetingDelivery;
use App\Models\NotificationAbuseAlert;
use App\Models\NotificationAdSetting;
use App\Models\NotificationDispatch;
use App\Models\ProviderBirthdaySetting;
use App\Models\ProviderNotificationControl;
use App\Models\ProviderProfile;
use App\Models\ServiceRequest;
use App\Models\User;
use App\Models\UserNotification;
use App\Models\UserPushPreference;
use Carbon\Carbon;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class BirthdayAssistantService
{
    public function __construct(
        protected NotificationService $notifications,
        protected NotificationBillingService $billing,
        protected NotificationAbuseGuardService $abuseGuard,
        protected MessageContentPolicyService $policy,
    ) {}

    public function getOrDefaultSetting(ProviderProfile $profile): ProviderBirthdaySetting
    {
        return $profile->birthdaySetting()->first() ?: new ProviderBirthdaySetting([
            'provider_profile_id' => $profile->id,
            'is_enabled' => false,
            'send_on_birthday' => true,
            'send_one_day_before' => false,
            'send_two_days_before' => false,
            'send_time' => '10:00',
            'template_key' => 'classic',
            'custom_message' => null,
            'required_plan_tier' => null,
        ]);
    }

    /**
     * Resolve the celebration calendar date in a given year.
     * For Feb 29 birthdays: celebrates on Feb 29 in leap years, Feb 28 in non-leap years.
     */
    public function celebrationDateForYear(Carbon $birthDate, int $year, string $tz = 'Europe/Istanbul'): Carbon
    {
        $month = (int) $birthDate->month;
        $day = (int) $birthDate->day;

        if ($month === 2 && $day === 29 && !Carbon::createFromDate($year, 1, 1, $tz)->isLeapYear()) {
            $day = 28;
        }

        return Carbon::create($year, $month, $day, 0, 0, 0, $tz);
    }

    /**
     * Match whether $today hits any enabled offset (2 days before, 1 day before, or exact day)
     * across $today->year and $today->year + 1 (handling Dec 30/31 -> Jan 1/2 rollover).
     *
     * @return array{birthday_year: int, days_before: int, celebration_date: Carbon}|null
     */
    public function matchingBirthdayTarget(
        Carbon $birthDate,
        Carbon $today,
        ProviderBirthdaySetting $setting,
        string $tz = 'Europe/Istanbul'
    ): ?array {
        $enabledOffsets = [];
        if ($setting->send_two_days_before) {
            $enabledOffsets[] = 2;
        }
        if ($setting->send_one_day_before) {
            $enabledOffsets[] = 1;
        }
        if ($setting->send_on_birthday) {
            $enabledOffsets[] = 0;
        }

        if (empty($enabledOffsets)) {
            return null;
        }

        $todayStart = $today->copy()->setTimezone($tz)->startOfDay();

        foreach ([$todayStart->year, $todayStart->year + 1] as $targetYear) {
            $celebrationDate = $this->celebrationDateForYear($birthDate, $targetYear, $tz);

            foreach ($enabledOffsets as $offset) {
                $triggerDate = $celebrationDate->copy()->subDays($offset);
                if ($triggerDate->isSameDay($todayStart)) {
                    return [
                        'birthday_year' => $targetYear,
                        'days_before' => $offset,
                        'celebration_date' => $celebrationDate,
                    ];
                }
            }
        }

        return null;
    }

    /**
     * Customers eligible to receive a birthday greeting from THIS provider only:
     * 1. Has birth_date on CustomerProfile
     * 2. Explicitly opted into birthday greetings (birthday_greeting_enabled = true)
     * 3. Has at least one COMPLETED Appointment OR ServiceRequest with this provider
     */
    public function eligibleCustomersQuery(ProviderProfile $profile): Builder
    {
        $providerUserId = (int) $profile->user_id;

        return User::query()
            ->with(['customerProfile'])
            ->where('role', User::ROLE_CUSTOMER)
            ->where('status', 'active')
            ->whereHas('customerProfile', fn (Builder $q) => $q->whereNotNull('birth_date'))
            ->whereExists(function ($q) {
                $q->select(DB::raw(1))
                    ->from('user_push_preferences')
                    ->whereColumn('user_push_preferences.user_id', 'users.id')
                    ->where('user_push_preferences.birthday_greeting_enabled', true);
            })
            ->where(function (Builder $q) use ($providerUserId) {
                $q->whereExists(function ($sub) use ($providerUserId) {
                    $sub->select(DB::raw(1))
                        ->from('appointments')
                        ->whereColumn('appointments.customer_user_id', 'users.id')
                        ->where('appointments.provider_user_id', $providerUserId)
                        ->where('appointments.status', Appointment::STATUS_COMPLETED);
                })->orWhereExists(function ($sub) use ($providerUserId) {
                    $sub->select(DB::raw(1))
                        ->from('service_requests')
                        ->whereColumn('service_requests.customer_user_id', 'users.id')
                        ->where('service_requests.assigned_provider_user_id', $providerUserId)
                        ->where('service_requests.status', ServiceRequest::STATUS_COMPLETED);
                });
            });
    }

    /**
     * Send all birthday greetings whose configured send_time has arrived for today in Europe/Istanbul.
     *
     * @return array{sent: int, skipped: int}
     */
    public function sendDueGreetings(?Carbon $nowOverride = null): array
    {
        $tz = (string) config('app.timezone', 'Europe/Istanbul');
        $now = ($nowOverride ?: Carbon::now($tz))->copy()->setTimezone($tz);
        $currentHm = $now->format('H:i');

        $settings = ProviderBirthdaySetting::query()
            ->with('providerProfile.user')
            ->where('is_enabled', true)
            ->get();

        $sent = 0;
        $skipped = 0;
        $adSettings = NotificationAdSetting::current();
        $unitPriceCents = FinancialService::parseToCents($adSettings->birthday_unit_price ?? 0);

        foreach ($settings as $setting) {
            if (!$setting->isEntitled()) {
                continue;
            }

            $profile = $setting->providerProfile;
            if (!$profile || !$profile->user || $profile->user->status !== 'active') {
                continue;
            }

            $sendTime = substr((string) ($setting->send_time ?: '10:00'), 0, 5);
            if ($currentHm < $sendTime) {
                continue;
            }

            // Admin permission gate for both birthday greeting and auto special day channels.
            $bdayPerm = $this->abuseGuard->checkPermission((int) $profile->user_id, ProviderNotificationControl::CHANNEL_BIRTHDAY);
            $autoPerm = $this->abuseGuard->checkPermission((int) $profile->user_id, ProviderNotificationControl::CHANNEL_AUTO_SPECIAL_DAY);
            if (!$bdayPerm['allowed'] || !$autoPerm['allowed']) {
                continue;
            }

            $businessName = trim((string) ($profile->business_name ?: $profile->user->name ?: 'İşletmemiz'));
            $sampleMessage = $setting->renderMessage('Müşteri', $businessName);
            if ($this->policy->detectViolation($sampleMessage) !== null) {
                $this->abuseGuard->recordAlert(
                    (int) $profile->user_id,
                    NotificationAbuseAlert::TYPE_UNAUTHORIZED_MARKETING,
                    'Doğum günü şablonunda iletişim/bağlantı politikası ihlali nedeniyle otomatik gönderim atlandı.',
                    ['template_key' => $setting->template_key],
                );
                continue;
            }

            $isPromotional = $this->abuseGuard->containsPromotionalContent($sampleMessage);
            $customers = $this->eligibleCustomersQuery($profile)->get();

            $dueTargets = [];
            foreach ($customers as $customer) {
                $birthDate = $customer->customerProfile?->birth_date;
                if (!$birthDate) {
                    continue;
                }

                $target = $this->matchingBirthdayTarget(Carbon::parse($birthDate, $tz), $now, $setting, $tz);
                if (!$target) {
                    continue;
                }

                $birthdayYear = (int) $target['birthday_year'];
                if (BirthdayGreetingDelivery::where('provider_profile_id', $profile->id)
                    ->where('customer_user_id', $customer->id)
                    ->where('birthday_year', $birthdayYear)
                    ->exists()) {
                    $skipped++;
                    continue;
                }

                // Commercial/discount special-day copy NEVER bypasses marketing opt-in!
                if ($isPromotional && !UserPushPreference::isCampaignEnabledForUser($customer->id)) {
                    $this->abuseGuard->recordAlert(
                        (int) $profile->user_id,
                        NotificationAbuseAlert::TYPE_UNAUTHORIZED_MARKETING,
                        'İndirim/kampanya içerikli doğum günü şablonu, kampanya izni kapalı müşteriye gönderilmedi.',
                        ['customer_user_id' => $customer->id],
                        severity: 'INFO',
                        autoAction: 'RECIPIENT_SKIPPED',
                    );
                    $skipped++;
                    continue;
                }

                $dueTargets[] = ['customer' => $customer, 'target' => $target];
            }

            if ($dueTargets === []) {
                continue;
            }

            $dispatch = NotificationDispatch::create([
                'reference_code' => 'BDAY-' . $profile->id . '-' . $now->format('YmdHis') . '-' . substr(md5((string) mt_rand()), 0, 6),
                'provider_user_id' => $profile->user_id,
                'provider_profile_id' => $profile->id,
                'notification_type' => NotificationDispatch::TYPE_BIRTHDAY_GREETING,
                'source_type' => 'BIRTHDAY_ASSISTANT',
                'source_id' => $setting->id,
                'title' => 'Doğum Günü Kutlaması',
                'body' => $sampleMessage,
                'pricing_mode' => $unitPriceCents > 0 ? NotificationDispatch::PRICING_PER_RECIPIENT : NotificationDispatch::PRICING_FREE,
                'unit_price' => FinancialService::formatFromCents($unitPriceCents),
                'total_cost' => '0.00',
                'balance_source' => NotificationDispatch::SOURCE_NONE,
                'targeted_count' => count($dueTargets),
                'status' => NotificationDispatch::STATUS_PROCESSING,
                'sent_at' => $now,
            ]);

            foreach ($dueTargets as $entry) {
                /** @var User $customer */
                $customer = $entry['customer'];
                $target = $entry['target'];

                $quota = $this->abuseGuard->checkBirthdayRecipientQuota((int) $profile->user_id, (int) $customer->id, $adSettings);
                if (!$quota['allowed']) {
                    $skipped++;
                    continue;
                }

                $outcome = $this->deliverOnce(
                    $profile,
                    $setting,
                    $customer,
                    $businessName,
                    $target,
                    $now,
                    $dispatch,
                    $unitPriceCents,
                    $adSettings,
                    $isPromotional
                );

                if ($outcome === 'sent') {
                    $sent++;
                } else {
                    $skipped++;
                }
            }

            $dispatch->recalculateCounters();
            if ($dispatch->eligible_count === 0) {
                $dispatch->update([
                    'status' => $skipped > 0 ? NotificationDispatch::STATUS_BLOCKED : NotificationDispatch::STATUS_COMPLETED,
                    'status_reason' => $skipped > 0 ? 'Uygun gönderim yapılamadı (bakiye, izin veya limit engeli).' : null,
                    'completed_at' => now(),
                ]);
            }
        }

        return ['sent' => $sent, 'skipped' => $skipped];
    }

    /**
     * Aggregate count of eligible customers celebrating within the next $daysAhead days.
     * Strictly NEVER returns individual names or birth dates.
     */
    public function upcomingEligibleCount(ProviderProfile $profile, int $daysAhead = 30): int
    {
        $tz = (string) config('app.timezone', 'Europe/Istanbul');
        $today = Carbon::now($tz)->startOfDay();
        $end = $today->copy()->addDays($daysAhead);
        $count = 0;

        $customers = $this->eligibleCustomersQuery($profile)->get();
        foreach ($customers as $customer) {
            $birthDate = $customer->customerProfile?->birth_date;
            if (!$birthDate) {
                continue;
            }
            $parsed = Carbon::parse($birthDate, $tz);
            foreach ([$today->year, $today->year + 1] as $yr) {
                $celeb = $this->celebrationDateForYear($parsed, $yr, $tz);
                if ($celeb->betweenIncluded($today, $end)) {
                    $count++;
                    break;
                }
            }
        }

        return $count;
    }

    /**
     * Guarantee at most 1 greeting and 1 charge/reservation per provider + customer + birthday year
     * using wallet lockForUpdate() + DB unique constraint + NotificationService key.
     */
    private function deliverOnce(
        ProviderProfile $profile,
        ProviderBirthdaySetting $setting,
        User $customer,
        string $businessName,
        array $target,
        Carbon $now,
        NotificationDispatch $dispatch,
        int $unitPriceCents,
        NotificationAdSetting $adSettings,
        bool $isPromotional
    ): string {
        $birthdayYear = (int) $target['birthday_year'];
        $daysBefore = (int) $target['days_before'];
        /** @var Carbon $celebrationDate */
        $celebrationDate = $target['celebration_date'];

        $firstName = trim((string) ($customer->first_name ?: explode(' ', trim((string) $customer->name))[0] ?: 'Değerli Müşterimiz'));
        $title = "🎂 Doğum Günün Kutlu Olsun, {$firstName}!";
        $message = $setting->renderMessage($firstName, $businessName);
        $idempotencyKey = "BIRTHDAY_GREETING:{$profile->id}:{$customer->id}:{$birthdayYear}";
        $billingReference = "BDAY:{$profile->id}:{$customer->id}:{$birthdayYear}";

        try {
            $ok = DB::transaction(function () use (
                $profile,
                $customer,
                $birthdayYear,
                $daysBefore,
                $celebrationDate,
                $now,
                $businessName,
                $title,
                $message,
                $idempotencyKey,
                $billingReference,
                $dispatch,
                $unitPriceCents,
                $adSettings,
                $isPromotional
            ) {
                // Serialize concurrent sends on the same provider wallet BEFORE creating delivery/reservation.
                $this->billing->getOrCreateWallet((int) $profile->user_id, true);

                if (BirthdayGreetingDelivery::where('provider_profile_id', $profile->id)
                    ->where('customer_user_id', $customer->id)
                    ->where('birthday_year', $birthdayYear)
                    ->exists()) {
                    return false;
                }

                try {
                    $delivery = BirthdayGreetingDelivery::create([
                        'provider_profile_id' => $profile->id,
                        'customer_user_id' => $customer->id,
                        'birthday_year' => $birthdayYear,
                        'days_before' => $daysBefore,
                        'celebration_date' => $celebrationDate->format('Y-m-d'),
                        'sent_at' => $now,
                        'dispatch_id' => $dispatch->id,
                        'unit_price' => FinancialService::formatFromCents($unitPriceCents),
                        'title_snapshot' => mb_substr($title, 0, 200),
                        'message_snapshot' => $message,
                    ]);
                } catch (QueryException) {
                    return false;
                }

                $recipient = $this->billing->reserveBirthdayGreeting(
                    (int) $profile->user_id,
                    $dispatch,
                    $delivery,
                    $billingReference,
                    $unitPriceCents,
                    $adSettings
                );

                $notification = $this->notifications->notifyUser(
                    $customer->id,
                    UserNotification::TYPE_BIRTHDAY_GREETING,
                    $title,
                    $message,
                    UserNotification::RESOURCE_PROVIDER_PROFILE,
                    $profile->user_id,
                    '/customer',
                    [
                        'provider_user_id' => $profile->user_id,
                        'provider_profile_id' => $profile->id,
                        'provider_name' => $businessName,
                        'birthday_year' => $birthdayYear,
                        'days_before' => $daysBefore,
                        'dispatch_id' => $dispatch->id,
                        'billing_reference' => $billingReference,
                        'birthday_delivery_id' => $delivery->id,
                        'is_promotional_copy' => $isPromotional,
                    ],
                    $idempotencyKey
                );

                if ($notification) {
                    $delivery->update(['user_notification_id' => $notification->id]);
                    $recipient->update(['user_notification_id' => $notification->id]);
                }

                return true;
            });

            return $ok ? 'sent' : 'skipped';
        } catch (ValidationException $e) {
            $this->abuseGuard->recordAlert(
                (int) $profile->user_id,
                NotificationAbuseAlert::TYPE_INSUFFICIENT_BALANCE_ATTEMPT,
                $e->getMessage() ?: 'Doğum günü bildirimi için bakiye yetersiz veya cüzdan dondurulmuş.',
                ['customer_user_id' => $customer->id, 'unit_price' => FinancialService::formatFromCents($unitPriceCents)],
                dispatchId: $dispatch->id,
                severity: 'WARNING',
                autoAction: 'RECIPIENT_SKIPPED',
            );

            return 'blocked';
        }
    }
}
