<?php

namespace App\Models;

use Carbon\CarbonInterface;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ProviderNotificationControl extends Model
{
    use HasFactory;

    public const CHANNEL_NOTIFICATION_AD = 'notification_ad';
    public const CHANNEL_BIRTHDAY = 'birthday';
    public const CHANNEL_AUTO_SPECIAL_DAY = 'auto_special_day';

    protected $fillable = [
        'provider_user_id',
        'can_send_notification_ads',
        'notification_ads_blocked_until',
        'can_send_birthday_greetings',
        'birthday_blocked_until',
        'can_send_auto_special_day',
        'auto_special_day_blocked_until',
        'daily_paid_notification_limit',
        'daily_unique_recipient_limit',
        'restriction_reason',
        'restricted_by_admin_id',
        'restricted_at',
        'is_auto_restricted',
    ];

    protected function casts(): array
    {
        return [
            'can_send_notification_ads' => 'boolean',
            'notification_ads_blocked_until' => 'datetime',
            'can_send_birthday_greetings' => 'boolean',
            'birthday_blocked_until' => 'datetime',
            'can_send_auto_special_day' => 'boolean',
            'auto_special_day_blocked_until' => 'datetime',
            'daily_paid_notification_limit' => 'integer',
            'daily_unique_recipient_limit' => 'integer',
            'restricted_at' => 'datetime',
            'is_auto_restricted' => 'boolean',
        ];
    }

    public function provider(): BelongsTo
    {
        return $this->belongsTo(User::class, 'provider_user_id');
    }

    public function restrictedByAdmin(): BelongsTo
    {
        return $this->belongsTo(User::class, 'restricted_by_admin_id');
    }

    public static function forProvider(int $providerUserId): self
    {
        return self::query()->firstOrNew(
            ['provider_user_id' => $providerUserId],
            [
                'can_send_notification_ads' => true,
                'can_send_birthday_greetings' => true,
                'can_send_auto_special_day' => true,
                'is_auto_restricted' => false,
            ]
        );
    }

    public function isChannelBlocked(string $channel, ?CarbonInterface $now = null): bool
    {
        $now ??= now();

        [$flag, $until] = match ($channel) {
            self::CHANNEL_NOTIFICATION_AD => [$this->can_send_notification_ads, $this->notification_ads_blocked_until],
            self::CHANNEL_BIRTHDAY => [$this->can_send_birthday_greetings, $this->birthday_blocked_until],
            self::CHANNEL_AUTO_SPECIAL_DAY => [$this->can_send_auto_special_day, $this->auto_special_day_blocked_until],
            default => [true, null],
        };

        if ($until !== null) {
            return $until->greaterThan($now);
        }

        return $flag === false;
    }

    public function blockedUntilFor(string $channel): ?CarbonInterface
    {
        return match ($channel) {
            self::CHANNEL_NOTIFICATION_AD => $this->notification_ads_blocked_until,
            self::CHANNEL_BIRTHDAY => $this->birthday_blocked_until,
            self::CHANNEL_AUTO_SPECIAL_DAY => $this->auto_special_day_blocked_until,
            default => null,
        };
    }

    public function isNotificationAdsBlocked(?CarbonInterface $now = null): bool
    {
        return $this->isChannelBlocked(self::CHANNEL_NOTIFICATION_AD, $now);
    }

    public function isBirthdayBlocked(?CarbonInterface $now = null): bool
    {
        return $this->isChannelBlocked(self::CHANNEL_BIRTHDAY, $now);
    }

    public function isAutoSpecialDayBlocked(?CarbonInterface $now = null): bool
    {
        return $this->isChannelBlocked(self::CHANNEL_AUTO_SPECIAL_DAY, $now);
    }

    public function isAnyRestricted(?CarbonInterface $now = null): bool
    {
        return $this->isNotificationAdsBlocked($now)
            || $this->isBirthdayBlocked($now)
            || $this->isAutoSpecialDayBlocked($now)
            || $this->daily_paid_notification_limit !== null
            || $this->daily_unique_recipient_limit !== null;
    }

    public function effectiveDailyPaidLimit(NotificationAdSetting $settings): int
    {
        $global = max(1, (int) ($settings->default_daily_paid_notification_limit ?? 100));
        if ($this->daily_paid_notification_limit !== null) {
            return min($global, max(0, (int) $this->daily_paid_notification_limit));
        }

        return $global;
    }

    public function effectiveDailyUniqueRecipientLimit(NotificationAdSetting $settings): int
    {
        $global = max(1, (int) ($settings->default_daily_unique_recipient_limit ?? 200));
        if ($this->daily_unique_recipient_limit !== null) {
            return min($global, max(0, (int) $this->daily_unique_recipient_limit));
        }

        return $global;
    }

    public function present(?NotificationAdSetting $settings = null): array
    {
        $settings ??= NotificationAdSetting::current();
        $now = now();

        return [
            'can_send_notification_ads' => !$this->isNotificationAdsBlocked($now),
            'notification_ads_blocked' => $this->isNotificationAdsBlocked($now),
            'notification_ads_blocked_until' => $this->notification_ads_blocked_until?->toISOString(),
            'can_send_birthday_greetings' => !$this->isBirthdayBlocked($now),
            'birthday_blocked' => $this->isBirthdayBlocked($now),
            'birthday_blocked_until' => $this->birthday_blocked_until?->toISOString(),
            'can_send_auto_special_day' => !$this->isAutoSpecialDayBlocked($now),
            'auto_special_day_blocked' => $this->isAutoSpecialDayBlocked($now),
            'auto_special_day_blocked_until' => $this->auto_special_day_blocked_until?->toISOString(),
            'daily_paid_notification_limit' => $this->daily_paid_notification_limit,
            'daily_unique_recipient_limit' => $this->daily_unique_recipient_limit,
            'effective_daily_paid_limit' => $this->effectiveDailyPaidLimit($settings),
            'effective_daily_unique_recipient_limit' => $this->effectiveDailyUniqueRecipientLimit($settings),
            'restriction_reason' => $this->restriction_reason,
            'restricted_at' => $this->restricted_at?->toISOString(),
            'is_auto_restricted' => (bool) $this->is_auto_restricted,
            'is_restricted' => $this->isAnyRestricted($now),
        ];
    }
}
