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
                'title_max' => NotificationAd::TITLE_MAX,
                'body_max' => NotificationAd::BODY_MAX,
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
        ];
    }
}
