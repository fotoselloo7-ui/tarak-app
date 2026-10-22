<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * One purchase (or admin grant) of an "öne çıkarma" period for a provider.
 * Active while starts_at <= now < ends_at and not cancelled — no cron needed
 * for a profile to disappear from the section when its time is up.
 */
class FeaturedPromotion extends Model
{
    /** Homepage "Öne Çıkan Profesyoneller" showcase (every row that existed before placements). */
    public const PLACEMENT_HOME = 'home';
    /** Sponsored slots at the top of the provider lists (appointment step, per-service "Uzmanlar", Hizmet Verenler). */
    public const PLACEMENT_LISTING = 'listing';
    public const PLACEMENTS = [self::PLACEMENT_HOME, self::PLACEMENT_LISTING];

    public const SOURCE_WALLET = 'wallet';
    public const SOURCE_ADMIN = 'admin';
    public const SOURCE_CARD = 'card';

    /** Sources that brought money in (everything but gifts). */
    public const PAID_SOURCES = [self::SOURCE_WALLET, self::SOURCE_CARD];

    protected $fillable = [
        'provider_user_id',
        'placement',
        'featured_package_id',
        'package_name',
        'duration_days',
        'price_paid',
        'source',
        'starts_at',
        'ends_at',
        'cancelled_at',
        'expiry_notified_at',
        'created_by',
        'note',
    ];

    protected function casts(): array
    {
        return [
            'duration_days' => 'integer',
            'price_paid' => 'decimal:2',
            'starts_at' => 'datetime',
            'ends_at' => 'datetime',
            'cancelled_at' => 'datetime',
            'expiry_notified_at' => 'datetime',
        ];
    }

    public function provider(): BelongsTo
    {
        return $this->belongsTo(User::class, 'provider_user_id');
    }

    public function package(): BelongsTo
    {
        return $this->belongsTo(FeaturedPackage::class, 'featured_package_id');
    }

    public function scopePlacement(Builder $query, string $placement): Builder
    {
        return $query->where('placement', $placement);
    }

    /** Currently running promotions. */
    public function scopeActive(Builder $query): Builder
    {
        $now = now();

        return $query->whereNull('cancelled_at')->where('starts_at', '<=', $now)->where('ends_at', '>', $now);
    }

    /** Bought but not started yet (queued behind a running one). */
    public function scopeUpcoming(Builder $query): Builder
    {
        return $query->whereNull('cancelled_at')->where('starts_at', '>', now());
    }

    public function status(): string
    {
        if ($this->cancelled_at) {
            return 'cancelled';
        }
        if ($this->starts_at->isFuture()) {
            return 'upcoming';
        }

        return $this->ends_at->isFuture() ? 'active' : 'expired';
    }

    public function present(): array
    {
        return [
            'id' => $this->id,
            'provider_user_id' => $this->provider_user_id,
            'placement' => $this->placement ?: self::PLACEMENT_HOME,
            'package_name' => $this->package_name,
            'duration_days' => $this->duration_days,
            'price_paid' => (float) $this->price_paid,
            'source' => $this->source,
            'status' => $this->status(),
            'starts_at' => $this->starts_at?->toIso8601String(),
            'ends_at' => $this->ends_at?->toIso8601String(),
            'cancelled_at' => $this->cancelled_at?->toIso8601String(),
            'days_left' => $this->status() === 'active' ? max(0, (int) ceil(now()->diffInSeconds($this->ends_at, false) / 86400)) : null,
            'note' => $this->note,
        ];
    }
}
