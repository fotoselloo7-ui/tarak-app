<?php

namespace App\Services;

use App\Models\NotificationAbuseAlert;
use App\Models\NotificationAd;
use App\Models\NotificationAdSetting;
use App\Models\NotificationDispatch;
use App\Models\NotificationDispatchRecipient;
use App\Models\ProviderNotificationControl;
use App\Models\User;
use Illuminate\Validation\ValidationException;

/**
 * Enforces admin per-provider notification permissions, daily quotas, duplicate/rapid spam guards,
 * promotional copy compliance, and suspicious activity alerting.
 */
class NotificationAbuseGuardService
{
    /**
     * Check whether a provider is allowed to send on a given channel right now.
     * Always queries fresh state from DB so queue workers respect immediate admin blocks.
     *
     * @return array{allowed: bool, reason: ?string, blocked_until: ?string, control: ProviderNotificationControl}
     */
    public function checkPermission(int $providerUserId, string $channel): array
    {
        $control = ProviderNotificationControl::forProvider($providerUserId);
        if ($control->exists) {
            $control->refresh();
        }

        if ($control->isChannelBlocked($channel)) {
            $until = $control->blockedUntilFor($channel);
            $channelLabel = match ($channel) {
                ProviderNotificationControl::CHANNEL_NOTIFICATION_AD => 'Bildirim reklamı gönderme',
                ProviderNotificationControl::CHANNEL_BIRTHDAY => 'Doğum günü kutlaması gönderme',
                ProviderNotificationControl::CHANNEL_AUTO_SPECIAL_DAY => 'Otomatik özel gün mesajı gönderme',
                default => 'Bildirim gönderme',
            };
            $suffix = $control->restriction_reason
                ? " Neden: {$control->restriction_reason}"
                : '';
            $untilNote = $until ? (' Bitiş: ' . $until->format('d.m.Y H:i') . '.') : '';

            return [
                'allowed' => false,
                'reason' => "{$channelLabel} yetkiniz yönetici tarafından kapatılmıştır.{$untilNote}{$suffix}",
                'blocked_until' => $until?->toISOString(),
                'control' => $control,
            ];
        }

        return [
            'allowed' => true,
            'reason' => null,
            'blocked_until' => null,
            'control' => $control,
        ];
    }

    /**
     * Detect commercial, discount, sales, or campaign language inside custom special-day templates.
     * Marketing content MUST respect UserPushPreference::campaign_enabled even in birthday greetings.
     */
    public function containsPromotionalContent(string $text): bool
    {
        $normalized = mb_strtolower(trim($text), 'UTF-8');
        if ($normalized === '') {
            return false;
        }

        return (bool) preg_match(
            '/\b(indirim\w*|kampanya\w*|f[ıi]rsat\w*|kupon\w*|kod\w*|promosyon\w*|hediye\s*(?:\w+\s*)?(?:tl|₺|%)|ücretsiz|bedava|sat[ıi][şs]\w*|avantaj\w*|yüzde\s*\d+)\b|%\s*\d+|\d+\s*%|₺\s*\d+|\d+\s*tl\b/iu',
            $normalized
        );
    }

    /**
     * Compute rolling 24h outbound counts and rapid-burst counts for one provider.
     *
     * @return array{paid_today: int, unique_recipients_today: int, campaigns_in_window: int}
     */
    public function dailyUsage(int $providerUserId, ?NotificationAdSetting $settings = null): array
    {
        $settings ??= NotificationAdSetting::current();
        $since24h = now()->subDay();
        $windowMinutes = max(5, (int) ($settings->rapid_campaign_window_minutes ?? 30));

        $paidToday = NotificationDispatchRecipient::query()
            ->where('provider_user_id', $providerUserId)
            ->whereIn('billing_status', [
                NotificationDispatchRecipient::BILLING_RESERVED,
                NotificationDispatchRecipient::BILLING_CAPTURED,
                NotificationDispatchRecipient::BILLING_CHARGED_CAMPAIGN,
            ])
            ->where('created_at', '>=', $since24h)
            ->count();

        $uniqueRecipientsToday = (int) NotificationDispatchRecipient::query()
            ->where('provider_user_id', $providerUserId)
            ->whereIn('billing_status', [
                NotificationDispatchRecipient::BILLING_FREE,
                NotificationDispatchRecipient::BILLING_RESERVED,
                NotificationDispatchRecipient::BILLING_CAPTURED,
                NotificationDispatchRecipient::BILLING_CHARGED_CAMPAIGN,
            ])
            ->where('created_at', '>=', $since24h)
            ->distinct()
            ->count('recipient_user_id');

        $campaignsInWindow = NotificationAd::query()
            ->where('provider_user_id', $providerUserId)
            ->whereIn('status', [NotificationAd::STATUS_QUEUED, NotificationAd::STATUS_SENT])
            ->where('created_at', '>=', now()->subMinutes($windowMinutes))
            ->count();

        return [
            'paid_today' => $paidToday,
            'unique_recipients_today' => $uniqueRecipientsToday,
            'campaigns_in_window' => $campaignsInWindow,
        ];
    }

    /**
     * Guard a provider notification ad before purchase/dispatch.
     */
    public function guardNotificationAdSend(User $provider, string $title, string $body, NotificationAdSetting $settings): void
    {
        $perm = $this->checkPermission($provider->id, ProviderNotificationControl::CHANNEL_NOTIFICATION_AD);
        if (!$perm['allowed']) {
            throw ValidationException::withMessages(['audience' => [$perm['reason']]]);
        }

        $control = $perm['control'];
        $usage = $this->dailyUsage($provider->id, $settings);

        // 1. Duplicate content within configured hours
        $dupHours = max(1, (int) ($settings->duplicate_content_window_hours ?? 24));
        $normTitle = mb_strtolower(trim($title), 'UTF-8');
        $normBody = mb_strtolower(trim($body), 'UTF-8');
        $recentAds = NotificationAd::query()
            ->where('provider_user_id', $provider->id)
            ->whereIn('status', [NotificationAd::STATUS_QUEUED, NotificationAd::STATUS_SENT])
            ->where('created_at', '>=', now()->subHours($dupHours))
            ->get(['id', 'title', 'body']);
        foreach ($recentAds as $prev) {
            if (mb_strtolower(trim((string) $prev->title), 'UTF-8') === $normTitle
                && mb_strtolower(trim((string) $prev->body), 'UTF-8') === $normBody) {
                $this->recordAlert(
                    $provider->id,
                    NotificationAbuseAlert::TYPE_DUPLICATE_CONTENT,
                    'Son ' . $dupHours . ' saat içinde birebir aynı bildirim reklamı içeriği tekrar gönderilmek istendi.',
                    ['previous_ad_id' => $prev->id, 'title' => mb_substr($title, 0, 80)],
                    severity: 'WARNING',
                    autoAction: 'SEND_BLOCKED',
                );
                throw ValidationException::withMessages(['title' => ['Son saatlerde aynı başlık ve açıklama ile bildirim zaten gönderdiniz. Farklı bir içerik yazın.']]);
            }
        }

        // 2. Rapid campaign burst check
        $burstLimit = max(2, (int) ($settings->rapid_campaign_threshold ?? 3));
        $burstWindow = max(5, (int) ($settings->rapid_campaign_window_minutes ?? 30));
        if ($usage['campaigns_in_window'] >= $burstLimit) {
            $autoAction = 'SEND_BLOCKED';
            if ($settings->auto_suspend_on_abuse) {
                $control->fill([
                    'can_send_notification_ads' => false,
                    'notification_ads_blocked_until' => now()->addMinutes($burstWindow),
                    'restriction_reason' => "Otomatik koruma: {$burstWindow} dakikada {$burstLimit}+ kampanya girişimi.",
                    'restricted_at' => now(),
                    'is_auto_restricted' => true,
                ])->save();
                $autoAction = 'TEMP_AUTO_SUSPENDED';
            }

            $this->recordAlert(
                $provider->id,
                NotificationAbuseAlert::TYPE_RAPID_CAMPAIGNS,
                "{$burstWindow} dakika içinde {$usage['campaigns_in_window']} bildirim reklamı gönderimi tespit edildi.",
                ['campaigns_in_window' => $usage['campaigns_in_window'], 'threshold' => $burstLimit],
                severity: 'HIGH',
                autoAction: $autoAction,
            );

            throw ValidationException::withMessages(['audience' => ["Kısa sürede çok fazla bildirim reklamı girişimi tespit edildi. Lütfen {$burstWindow} dakika sonra tekrar deneyin."]]);
        }

        // 3. Daily unique recipient cap / daily paid limit
        $dailyPaidCap = $control->effectiveDailyPaidLimit($settings);
        $dailyUniqueCap = $control->effectiveDailyUniqueRecipientLimit($settings);
        if ($usage['paid_today'] >= $dailyPaidCap || $usage['unique_recipients_today'] >= $dailyUniqueCap) {
            $this->recordAlert(
                $provider->id,
                NotificationAbuseAlert::TYPE_DAILY_LIMIT_EXCEEDED,
                'İşletme günlük ücretli bildirim veya benzersiz alıcı sınırına ulaştı.',
                $usage + ['daily_paid_cap' => $dailyPaidCap, 'daily_unique_cap' => $dailyUniqueCap],
                severity: 'WARNING',
                autoAction: 'SEND_BLOCKED',
            );
            throw ValidationException::withMessages(['audience' => ['Günlük bildirim gönderim veya benzersiz alıcı limitinize ulaştınız.']]);
        }
    }

    /**
     * Guard a single outbound birthday notification before debit/creation.
     *
     * @return array{allowed: bool, reason: ?string}
     */
    public function checkBirthdayRecipientQuota(int $providerUserId, int $customerUserId, NotificationAdSetting $settings): array
    {
        $bdayPerm = $this->checkPermission($providerUserId, ProviderNotificationControl::CHANNEL_BIRTHDAY);
        if (!$bdayPerm['allowed']) {
            return ['allowed' => false, 'reason' => $bdayPerm['reason']];
        }

        $autoPerm = $this->checkPermission($providerUserId, ProviderNotificationControl::CHANNEL_AUTO_SPECIAL_DAY);
        if (!$autoPerm['allowed']) {
            return ['allowed' => false, 'reason' => $autoPerm['reason']];
        }

        $control = $bdayPerm['control'];
        $usage = $this->dailyUsage($providerUserId, $settings);
        $dailyPaidCap = $control->effectiveDailyPaidLimit($settings);
        $dailyUniqueCap = $control->effectiveDailyUniqueRecipientLimit($settings);
        $bdayDailyCap = max(1, (int) ($settings->birthday_max_per_provider_per_day ?? 100));

        if ($usage['paid_today'] >= min($dailyPaidCap, $bdayDailyCap) || $usage['unique_recipients_today'] >= $dailyUniqueCap) {
            $this->recordAlert(
                $providerUserId,
                NotificationAbuseAlert::TYPE_DAILY_LIMIT_EXCEEDED,
                'Doğum günü gönderimi günlük ücretli/benzersiz alıcı sınırına takıldı.',
                $usage + ['customer_user_id' => $customerUserId],
                severity: 'WARNING',
                autoAction: 'RECIPIENT_SKIPPED',
            );

            return ['allowed' => false, 'reason' => 'Günlük bildirim limiti aşıldı.'];
        }

        $sameRecipientRecent = NotificationDispatchRecipient::query()
            ->where('provider_user_id', $providerUserId)
            ->where('recipient_user_id', $customerUserId)
            ->where('created_at', '>=', now()->subDay())
            ->whereNotIn('delivery_status', [
                NotificationDispatchRecipient::DELIVERY_BLOCKED_BY_ADMIN,
                NotificationDispatchRecipient::DELIVERY_OPTED_OUT,
            ])
            ->count();

        if ($sameRecipientRecent >= 3) {
            $this->recordAlert(
                $providerUserId,
                NotificationAbuseAlert::TYPE_REPEATED_SAME_RECIPIENT,
                "Aynı müşteriye 24 saat içinde {$sameRecipientRecent} pazarlama/özel gün bildirimi girişimi tespit edildi.",
                ['recipient_user_id' => $customerUserId, 'count_24h' => $sameRecipientRecent],
                severity: 'WARNING',
                autoAction: 'RECIPIENT_SKIPPED',
            );

            return ['allowed' => false, 'reason' => 'Aynı müşteriye günlük tekrar sınırı aşıldı.'];
        }

        return ['allowed' => true, 'reason' => null];
    }

    public function recordAlert(
        ?int $providerUserId,
        string $alertType,
        string $summary,
        array $details = [],
        ?int $dispatchId = null,
        string $severity = 'WARNING',
        ?string $autoAction = null
    ): NotificationAbuseAlert {
        return NotificationAbuseAlert::create([
            'provider_user_id' => $providerUserId,
            'dispatch_id' => $dispatchId,
            'alert_type' => $alertType,
            'severity' => $severity,
            'summary' => mb_substr($summary, 0, 255),
            'details' => $details,
            'auto_action_taken' => $autoAction,
            'status' => NotificationAbuseAlert::STATUS_OPEN,
        ]);
    }
}
