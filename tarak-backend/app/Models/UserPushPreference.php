<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Facades\Schema;

class UserPushPreference extends Model
{
    use HasFactory;

    public const DEFAULT_REMINDER_MINUTES = 30;
    public const MIN_REMINDER_MINUTES = 5;
    public const MAX_REMINDER_MINUTES = 1440;

    protected $fillable = [
        'user_id',
        'push_enabled',
        'campaign_enabled',
        'appointment_reminder_enabled',
        'appointment_reminder_minutes',
        'appointment_start_alert_enabled',
        'birthday_greeting_enabled',
    ];

    protected $casts = [
        'push_enabled' => 'boolean',
        'campaign_enabled' => 'boolean',
        'appointment_reminder_enabled' => 'boolean',
        'appointment_reminder_minutes' => 'integer',
        'appointment_start_alert_enabled' => 'boolean',
        'birthday_greeting_enabled' => 'boolean',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public static function hasReminderColumns(): bool
    {
        return Schema::hasColumns('user_push_preferences', [
            'appointment_reminder_enabled',
            'appointment_reminder_minutes',
            'appointment_start_alert_enabled',
        ]);
    }

    public static function hasBirthdayColumn(): bool
    {
        return Schema::hasColumn('user_push_preferences', 'birthday_greeting_enabled');
    }

    /**
     * Normalized notification preferences for the given user, defaulting cleanly
     * even before a row exists or before optional columns are migrated.
     *
     * @return array{
     *   push_enabled: bool,
     *   campaign_enabled: bool,
     *   appointment_reminder_enabled: bool,
     *   appointment_reminder_minutes: int,
     *   appointment_start_alert_enabled: bool,
     *   birthday_greeting_enabled: bool
     * }
     */
    public static function forUser(int $userId): array
    {
        $pref = static::where('user_id', $userId)->first();
        $hasReminder = static::hasReminderColumns();
        $hasBirthday = static::hasBirthdayColumn();

        $minutes = self::DEFAULT_REMINDER_MINUTES;
        if ($pref && $hasReminder && $pref->appointment_reminder_minutes !== null) {
            $minutes = max(
                self::MIN_REMINDER_MINUTES,
                min(self::MAX_REMINDER_MINUTES, (int) $pref->appointment_reminder_minutes)
            );
        }

        return [
            'push_enabled' => $pref ? (bool) $pref->push_enabled : true,
            'campaign_enabled' => $pref ? (bool) $pref->campaign_enabled : true,
            'appointment_reminder_enabled' => ($pref && $hasReminder && $pref->appointment_reminder_enabled !== null)
                ? (bool) $pref->appointment_reminder_enabled
                : true,
            'appointment_reminder_minutes' => $minutes,
            'appointment_start_alert_enabled' => ($pref && $hasReminder && $pref->appointment_start_alert_enabled !== null)
                ? (bool) $pref->appointment_start_alert_enabled
                : true,
            'birthday_greeting_enabled' => ($pref && $hasBirthday && $pref->birthday_greeting_enabled !== null)
                ? (bool) $pref->birthday_greeting_enabled
                : false,
        ];
    }

    /**
     * Birthday greeting opt-in: defaults to false (never inferred from push or campaign consent).
     */
    public static function isBirthdayGreetingEnabledForUser(int $userId): bool
    {
        if (!static::hasBirthdayColumn()) {
            return false;
        }
        $pref = static::where('user_id', $userId)->first();

        return ($pref && $pref->birthday_greeting_enabled !== null)
            ? (bool) $pref->birthday_greeting_enabled
            : false;
    }

    /**
     * Determine if push notifications are enabled for the specified user.
     * Defaults to true if no preference record exists.
     */
    public static function isPushEnabledForUser(int $userId): bool
    {
        $pref = static::where('user_id', $userId)->first();
        return $pref ? (bool) $pref->push_enabled : true;
    }

    /** Provider discount campaigns ("bildirim reklamı"); defaults to true. */
    public static function isCampaignEnabledForUser(int $userId): bool
    {
        $pref = static::where('user_id', $userId)->first();

        return $pref ? (bool) $pref->campaign_enabled : true;
    }
}
