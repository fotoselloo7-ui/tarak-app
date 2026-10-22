<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** A provider's card payment (PayTR) for an "öne çıkarma" package. */
class FeaturedOrder extends Model
{
    public const STATUS_PENDING = 'PENDING';
    public const STATUS_PAID = 'PAID';
    public const STATUS_FAILED = 'FAILED';

    /** PayTR merchant_oid prefix; lets the shared callback tell these orders from service payments. */
    public const OID_PREFIX = 'FP';

    protected $fillable = [
        'provider_user_id',
        'placement',
        'featured_package_id',
        'package_name',
        'duration_days',
        'amount',
        'status',
        'merchant_oid',
        'failure_message',
        'user_ip',
        'promotion_id',
        'paid_at',
        'callback_payload',
    ];

    protected function casts(): array
    {
        return [
            'duration_days' => 'integer',
            'amount' => 'decimal:2',
            'paid_at' => 'datetime',
            'callback_payload' => 'array',
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

    public function promotion(): BelongsTo
    {
        return $this->belongsTo(FeaturedPromotion::class, 'promotion_id');
    }

    public function present(): array
    {
        return [
            'id' => $this->id,
            'placement' => $this->placement ?: FeaturedPromotion::PLACEMENT_HOME,
            'status' => $this->status,
            'package_name' => $this->package_name,
            'duration_days' => $this->duration_days,
            'amount' => (float) $this->amount,
            'failure_message' => $this->status === self::STATUS_FAILED ? $this->failure_message : null,
            'paid_at' => $this->paid_at?->toIso8601String(),
            'promotion' => $this->promotion?->present(),
        ];
    }
}
