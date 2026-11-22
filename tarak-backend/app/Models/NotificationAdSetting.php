<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/** The admin's controls of "bildirim reklamı": on/off, a price per audience, discount limits, anti-spam caps. Single row. */
class NotificationAdSetting extends Model
{
    protected $fillable = [
        'is_enabled', 'title', 'description',
        'price_service_area', 'price_location', 'price_all',
        'min_discount_percent', 'max_discount_percent', 'max_discount_days',
        'max_sends_per_provider_per_day', 'max_per_customer_per_day',
        'birthday_unit_price',
        'allow_promo_for_birthday',
        'allow_promo_for_notification_ads',
        'fallback_to_cash_when_promo_insufficient',
        'default_daily_paid_notification_limit',
        'default_daily_unique_recipient_limit',
        'birthday_max_per_provider_per_day',
        'duplicate_content_window_hours',
        'rapid_campaign_window_minutes',
        'rapid_campaign_threshold',
        'auto_suspend_on_abuse',
    ];

    protected function casts(): array
    {
        return [
            'is_enabled' => 'boolean',
            'price_service_area' => 'decimal:2',
            'price_location' => 'decimal:2',
            'price_all' => 'decimal:2',
            'min_discount_percent' => 'integer',
            'max_discount_percent' => 'integer',
            'max_discount_days' => 'integer',
            'max_sends_per_provider_per_day' => 'integer',
            'max_per_customer_per_day' => 'integer',
            'birthday_unit_price' => 'decimal:2',
            'allow_promo_for_birthday' => 'boolean',
            'allow_promo_for_notification_ads' => 'boolean',
            'fallback_to_cash_when_promo_insufficient' => 'boolean',
            'default_daily_paid_notification_limit' => 'integer',
            'default_daily_unique_recipient_limit' => 'integer',
            'birthday_max_per_provider_per_day' => 'integer',
            'duplicate_content_window_hours' => 'integer',
            'rapid_campaign_window_minutes' => 'integer',
            'rapid_campaign_threshold' => 'integer',
            'auto_suspend_on_abuse' => 'boolean',
        ];
    }

    public static function current(): self
    {
        // fresh(): the column defaults are not on the instance returned by create([])
        return self::query()->first() ?? self::query()->create([])->fresh();
    }

    public function priceFor(string $audience): float
    {
        return match ($audience) {
            NotificationAd::AUDIENCE_LOCATION => (float) $this->price_location,
            NotificationAd::AUDIENCE_ALL => (float) $this->price_all,
            default => (float) $this->price_service_area,
        };
    }

    /** What the provider's screen needs: the audiences with their prices. */
    public function present(): array
    {
        return [
            'is_enabled' => $this->is_enabled,
            'title' => $this->title,
            'description' => $this->description ?: 'Müşterilerin telefonuna indirim bildirimi gönder; indirim hizmetlerine seçtiğin süre boyunca gerçekten uygulanır.',
            'audiences' => collect(NotificationAd::AUDIENCES)->map(fn (string $audience) => [
                'audience' => $audience,
                'name' => NotificationAd::AUDIENCE_NAMES[$audience],
                'description' => NotificationAd::AUDIENCE_HINTS[$audience],
                'price' => $this->priceFor($audience),
            ])->values()->all(),
            'limits' => [
                'min_discount_percent' => $this->min_discount_percent,
                'max_discount_percent' => $this->max_discount_percent,
                'max_discount_days' => $this->max_discount_days,
                'max_sends_per_provider_per_day' => $this->max_sends_per_provider_per_day,
                'default_daily_paid_notification_limit' => (int) ($this->default_daily_paid_notification_limit ?? 100),
                'default_daily_unique_recipient_limit' => (int) ($this->default_daily_unique_recipient_limit ?? 200),
                'birthday_max_per_provider_per_day' => (int) ($this->birthday_max_per_provider_per_day ?? 100),
                'title_max' => NotificationAd::TITLE_MAX,
                'body_max' => NotificationAd::BODY_MAX,
            ],
            'pricing' => [
                'birthday_unit_price' => (float) ($this->birthday_unit_price ?? 0),
                'allow_promo_for_birthday' => (bool) ($this->allow_promo_for_birthday ?? true),
                'allow_promo_for_notification_ads' => (bool) ($this->allow_promo_for_notification_ads ?? true),
                'fallback_to_cash_when_promo_insufficient' => (bool) ($this->fallback_to_cash_when_promo_insufficient ?? true),
            ],
        ];
    }

    /** The admin's full view (every field). */
    public function presentForAdmin(): array
    {
        return $this->present() + [
            'price_service_area' => (float) $this->price_service_area,
            'price_location' => (float) $this->price_location,
            'price_all' => (float) $this->price_all,
            'min_discount_percent' => $this->min_discount_percent,
            'max_discount_percent' => $this->max_discount_percent,
            'max_discount_days' => $this->max_discount_days,
            'max_sends_per_provider_per_day' => $this->max_sends_per_provider_per_day,
            'max_per_customer_per_day' => $this->max_per_customer_per_day,
            'birthday_unit_price' => (float) ($this->birthday_unit_price ?? 0),
            'allow_promo_for_birthday' => (bool) ($this->allow_promo_for_birthday ?? true),
            'allow_promo_for_notification_ads' => (bool) ($this->allow_promo_for_notification_ads ?? true),
            'fallback_to_cash_when_promo_insufficient' => (bool) ($this->fallback_to_cash_when_promo_insufficient ?? true),
            'default_daily_paid_notification_limit' => (int) ($this->default_daily_paid_notification_limit ?? 100),
            'default_daily_unique_recipient_limit' => (int) ($this->default_daily_unique_recipient_limit ?? 200),
            'birthday_max_per_provider_per_day' => (int) ($this->birthday_max_per_provider_per_day ?? 100),
            'duplicate_content_window_hours' => (int) ($this->duplicate_content_window_hours ?? 24),
            'rapid_campaign_window_minutes' => (int) ($this->rapid_campaign_window_minutes ?? 30),
            'rapid_campaign_threshold' => (int) ($this->rapid_campaign_threshold ?? 3),
            'auto_suspend_on_abuse' => (bool) ($this->auto_suspend_on_abuse ?? true),
        ];
    }
}
