<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ServicePayment extends Model
{
    use HasFactory;

    protected $table = 'service_payments';

    public const STATUS_PENDING = 'PENDING';
    public const STATUS_HELD = 'HELD';
    public const STATUS_TRANSFER_PENDING = 'TRANSFER_PENDING';
    public const STATUS_SETTLED = 'SETTLED';
    public const STATUS_DISPUTED = 'DISPUTED';
    public const STATUS_REFUND_REQUIRED = 'REFUND_REQUIRED';
    public const STATUS_REFUNDING = 'REFUNDING';
    public const STATUS_REFUNDED = 'REFUNDED';
    public const STATUS_PARTIALLY_REFUNDED = 'PARTIALLY_REFUNDED';
    public const STATUS_CANCELLED = 'CANCELLED';

    public const RESOURCE_INSTANT_REQUEST = 'INSTANT_REQUEST';
    public const RESOURCE_SCHEDULED_APPOINTMENT = 'SCHEDULED_APPOINTMENT';

    protected $fillable = [
        'resource_type',
        'resource_id',
        'customer_user_id',
        'provider_user_id',
        'payment_method',
        'gross_amount',
        'commission_rate',
        'commission_amount',
        'provider_net_amount',
        'status',
        'gateway',
        'gateway_reference',
        'held_at',
        'transfer_pending_at',
        'settled_at',
        'cancelled_at',
        'disputed_at',
    ];

    protected function casts(): array
    {
        return [
            'gross_amount' => 'decimal:2',
            'commission_rate' => 'decimal:2',
            'commission_amount' => 'decimal:2',
            'provider_net_amount' => 'decimal:2',
            'held_at' => 'datetime',
            'transfer_pending_at' => 'datetime',
            'settled_at' => 'datetime',
            'cancelled_at' => 'datetime',
            'disputed_at' => 'datetime',
        ];
    }

    public function customer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'customer_user_id');
    }

    public function provider(): BelongsTo
    {
        return $this->belongsTo(User::class, 'provider_user_id');
    }

    public function gatewayAttempts(): \Illuminate\Database\Eloquent\Relations\HasMany
    {
        return $this->hasMany(PaymentGatewayAttempt::class, 'service_payment_id');
    }

    public function latestGatewayAttempt(): \Illuminate\Database\Eloquent\Relations\HasOne
    {
        return $this->hasOne(PaymentGatewayAttempt::class, 'service_payment_id')->latestOfMany();
    }

    public function payoutTransfer(): \Illuminate\Database\Eloquent\Relations\HasOne
    {
        return $this->hasOne(PayoutTransfer::class, 'service_payment_id');
    }

    public function refunds(): \Illuminate\Database\Eloquent\Relations\HasMany
    {
        return $this->hasMany(PaymentRefund::class, 'service_payment_id');
    }

    public function completedRefunds(): \Illuminate\Database\Eloquent\Relations\HasMany
    {
        return $this->hasMany(PaymentRefund::class, 'service_payment_id')
            ->where('status', PaymentRefund::STATUS_COMPLETED);
    }

    public function getGrossAmountMinor(): int
    {
        return \App\Services\FinancialService::parseToCents($this->gross_amount);
    }

    public function getTotalRefundedMinor(): int
    {
        return (int) $this->refunds()
            ->where('status', PaymentRefund::STATUS_COMPLETED)
            ->sum('refund_amount_minor');
    }

    public function getInFlightRefundMinor(): int
    {
        return (int) $this->refunds()
            ->whereIn('status', [PaymentRefund::STATUS_PENDING, PaymentRefund::STATUS_REQUESTED])
            ->sum('refund_amount_minor');
    }

    public function getRemainingRefundableMinor(): int
    {
        return max(0, $this->getGrossAmountMinor() - ($this->getTotalRefundedMinor() + $this->getInFlightRefundMinor()));
    }
}
