<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PaymentRefund extends Model
{
    use HasFactory;

    protected $table = 'payment_refunds';

    public const STATUS_PENDING = 'PENDING';
    public const STATUS_REQUESTED = 'REQUESTED';
    public const STATUS_COMPLETED = 'COMPLETED';
    public const STATUS_FAILED = 'FAILED';
    public const STATUS_MANUAL_REVIEW = 'MANUAL_REVIEW';

    protected $fillable = [
        'service_payment_id',
        'dispute_case_id',
        'merchant_oid',
        'reference_no',
        'refund_amount_minor',
        'currency',
        'status',
        'failure_reason',
        'paytr_response',
        'requested_at',
        'completed_at',
        'failed_at',
        'created_by_user_id',
        'metadata',
    ];

    protected function casts(): array
    {
        return [
            'refund_amount_minor' => 'integer',
            'paytr_response' => 'array',
            'metadata' => 'array',
            'requested_at' => 'datetime',
            'completed_at' => 'datetime',
            'failed_at' => 'datetime',
        ];
    }

    public function servicePayment(): BelongsTo
    {
        return $this->belongsTo(ServicePayment::class, 'service_payment_id');
    }

    public function disputeCase(): BelongsTo
    {
        return $this->belongsTo(DisputeCase::class, 'dispute_case_id');
    }

    public function createdByUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by_user_id');
    }

    public function isCompleted(): bool
    {
        return $this->status === self::STATUS_COMPLETED;
    }

    public function isFailed(): bool
    {
        return $this->status === self::STATUS_FAILED;
    }

    public function isRequested(): bool
    {
        return $this->status === self::STATUS_REQUESTED;
    }

    public function isManualReview(): bool
    {
        return $this->status === self::STATUS_MANUAL_REVIEW;
    }

    public function getRefundAmountAttribute(): float
    {
        return round(($this->refund_amount_minor ?? 0) / 100, 2);
    }
}
