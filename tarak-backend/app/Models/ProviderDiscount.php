<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * A percentage off all of a provider's services and packages between two dates (set by a "bildirim reklamı" campaign).
 * It is real: offerings, price snapshots and appointment totals use the discounted price while it runs.
 */
class ProviderDiscount extends Model
{
    protected $fillable = ['provider_user_id', 'percent', 'starts_at', 'ends_at', 'cancelled_at', 'notification_ad_id'];

    protected function casts(): array
    {
        return [
            'percent' => 'integer',
            'starts_at' => 'datetime',
            'ends_at' => 'datetime',
            'cancelled_at' => 'datetime',
        ];
    }

    public function provider(): BelongsTo
    {
        return $this->belongsTo(User::class, 'provider_user_id');
    }

    public function scopeActive(Builder $query): Builder
    {
        return $query->whereNull('cancelled_at')->where('starts_at', '<=', now())->where('ends_at', '>', now());
    }

    public function present(): array
    {
        return [
            'id' => $this->id,
            'percent' => $this->percent,
            'starts_at' => $this->starts_at?->toISOString(),
            'ends_at' => $this->ends_at?->toISOString(),
            'days_left' => max(0, (int) ceil(now()->diffInHours($this->ends_at, false) / 24)),
        ];
    }
}
