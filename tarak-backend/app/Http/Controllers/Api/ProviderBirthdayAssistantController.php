<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\BirthdayGreetingDelivery;
use App\Models\NotificationAdSetting;
use App\Models\ProviderBirthdaySetting;
use App\Models\ProviderNotificationControl;
use App\Services\BirthdayAssistantService;
use App\Services\MessageContentPolicyService;
use App\Services\NotificationAbuseGuardService;
use App\Services\NotificationReportService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ProviderBirthdayAssistantController extends Controller
{
    public function __construct(
        protected BirthdayAssistantService $birthdayService,
        protected NotificationReportService $reports,
        protected NotificationAbuseGuardService $abuseGuard,
        protected MessageContentPolicyService $policy,
    ) {}

    public function show(Request $request): JsonResponse
    {
        $profile = $request->user()->providerProfile;
        if (!$profile) {
            return response()->json(['success' => false, 'message' => 'Hizmet veren profili bulunamadı.'], 404);
        }

        $setting = $this->birthdayService->getOrDefaultSetting($profile);
        $eligibleCount = $this->birthdayService->eligibleCustomersQuery($profile)->count();
        $sentThisYearCount = BirthdayGreetingDelivery::where('provider_profile_id', $profile->id)
            ->where('birthday_year', (int) now(config('app.timezone', 'Europe/Istanbul'))->year)
            ->count();

        $adSettings = NotificationAdSetting::current();
        $report = $this->reports->providerReport($request->user(), $adSettings);

        // Privacy-safe delivery history: NEVER expose individual customer birth_date or full names.
        $recentDeliveries = BirthdayGreetingDelivery::query()
            ->where('provider_profile_id', $profile->id)
            ->latest('id')
            ->limit(15)
            ->get()
            ->map(fn (BirthdayGreetingDelivery $d) => [
                'id' => $d->id,
                'birthday_year' => (int) $d->birthday_year,
                'unit_price' => (float) ($d->unit_price ?? 0),
                'charged_amount' => (float) ($d->charged_amount ?? 0),
                'balance_source' => $d->balance_source ?: 'NONE',
                'billing_status' => $d->billing_status ?: 'FREE',
                'delivery_status' => $d->delivery_status ?: 'QUEUED',
                'sent_at' => $d->sent_at?->toISOString(),
            ])
            ->values();

        // Strictly aggregated counters + settings only; individual birth dates are NEVER returned.
        return response()->json([
            'success' => true,
            'data' => [
                'is_enabled' => (bool) $setting->is_enabled,
                'send_on_birthday' => (bool) $setting->send_on_birthday,
                'send_one_day_before' => (bool) $setting->send_one_day_before,
                'send_two_days_before' => (bool) $setting->send_two_days_before,
                'send_time' => substr((string) ($setting->send_time ?: '10:00'), 0, 5),
                'template_key' => $setting->template_key ?: 'classic',
                'custom_message' => $setting->custom_message,
                'required_plan_tier' => $setting->required_plan_tier,
                'plan_entitled' => $setting->isEntitled(),
                'eligible_customer_count' => $eligibleCount,
                'sent_this_year_count' => $sentThisYearCount,
                'upcoming_eligible_birthdays_30d' => $report['upcoming_eligible_birthdays_30d'],
                'pricing' => $report['pricing'],
                'wallet' => $report['wallet'],
                'permissions' => $report['permissions'],
                'monthly_summary' => $report['monthly_summary'],
                'recent_deliveries' => $recentDeliveries,
                'templates' => collect(ProviderBirthdaySetting::TEMPLATES)->map(fn ($t, $k) => [
                    'key' => $k,
                    'label' => $t['label'],
                    'body' => $t['body'],
                ])->values(),
            ],
        ]);
    }

    public function update(Request $request): JsonResponse
    {
        $profile = $request->user()->providerProfile;
        if (!$profile) {
            return response()->json(['success' => false, 'message' => 'Hizmet veren profili bulunamadı.'], 404);
        }

        $validTemplates = implode(',', array_merge(array_keys(ProviderBirthdaySetting::TEMPLATES), ['custom']));

        $validated = $request->validate([
            'is_enabled' => ['sometimes', 'boolean'],
            'send_on_birthday' => ['sometimes', 'boolean'],
            'send_one_day_before' => ['sometimes', 'boolean'],
            'send_two_days_before' => ['sometimes', 'boolean'],
            'send_time' => ['sometimes', 'date_format:H:i'],
            'template_key' => ['sometimes', 'string', "in:{$validTemplates}"],
            'custom_message' => ['nullable', 'string', 'max:500'],
        ]);

        if (($validated['is_enabled'] ?? false) === true) {
            $bdayPerm = $this->abuseGuard->checkPermission((int) $request->user()->id, ProviderNotificationControl::CHANNEL_BIRTHDAY);
            if (!$bdayPerm['allowed']) {
                return response()->json(['success' => false, 'message' => $bdayPerm['reason']], 422);
            }
            $autoPerm = $this->abuseGuard->checkPermission((int) $request->user()->id, ProviderNotificationControl::CHANNEL_AUTO_SPECIAL_DAY);
            if (!$autoPerm['allowed']) {
                return response()->json(['success' => false, 'message' => $autoPerm['reason']], 422);
            }
        }

        if (($validated['template_key'] ?? null) === 'custom' && trim((string) ($validated['custom_message'] ?? '')) === '') {
            return response()->json([
                'success' => false,
                'message' => 'Özel mesaj şablonu seçildiğinde tebrik mesajı boş bırakılamaz.',
            ], 422);
        }

        if (!empty($validated['custom_message']) && $this->policy->detectViolation((string) $validated['custom_message']) !== null) {
            return response()->json([
                'success' => false,
                'message' => 'Özel mesajda telefon numarası, bağlantı, e-posta veya sosyal medya bilgisi paylaşılamaz.',
            ], 422);
        }

        $setting = ProviderBirthdaySetting::updateOrCreate(
            ['provider_profile_id' => $profile->id],
            [
                'is_enabled' => $validated['is_enabled'] ?? false,
                'send_on_birthday' => $validated['send_on_birthday'] ?? true,
                'send_one_day_before' => $validated['send_one_day_before'] ?? false,
                'send_two_days_before' => $validated['send_two_days_before'] ?? false,
                'send_time' => $validated['send_time'] ?? '10:00',
                'template_key' => $validated['template_key'] ?? 'classic',
                'custom_message' => array_key_exists('custom_message', $validated)
                    ? ($validated['custom_message'] !== null ? trim((string) $validated['custom_message']) : null)
                    : null,
            ]
        );

        return response()->json([
            'success' => true,
            'message' => 'Özel Gün Asistanı ayarları kaydedildi.',
            'data' => [
                'is_enabled' => (bool) $setting->is_enabled,
                'send_on_birthday' => (bool) $setting->send_on_birthday,
                'send_one_day_before' => (bool) $setting->send_one_day_before,
                'send_two_days_before' => (bool) $setting->send_two_days_before,
                'send_time' => substr((string) ($setting->send_time ?: '10:00'), 0, 5),
                'template_key' => $setting->template_key ?: 'classic',
                'custom_message' => $setting->custom_message,
                'plan_entitled' => $setting->isEntitled(),
            ],
        ]);
    }
}
