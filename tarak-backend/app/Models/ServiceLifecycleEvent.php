<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ServiceLifecycleEvent extends Model
{
    use HasFactory;

    public $timestamps = false;

    public const EVENT_START_CODE_GENERATED = 'START_CODE_GENERATED';
    public const EVENT_START_CODE_FAILED = 'START_CODE_FAILED';
    public const EVENT_START_CODE_LOCKED = 'START_CODE_LOCKED';
    public const EVENT_SERVICE_STARTED = 'SERVICE_STARTED';
    public const EVENT_PROVIDER_MARKED_FINISHED = 'PROVIDER_MARKED_FINISHED';
    public const EVENT_CUSTOMER_CONFIRMED_COMPLETION = 'CUSTOMER_CONFIRMED_COMPLETION';
    public const EVENT_CUSTOMER_REPORTED_PROBLEM = 'CUSTOMER_REPORTED_PROBLEM';
    public const EVENT_PAYTR_TOKEN_CREATED = 'PAYTR_TOKEN_CREATED';
    public const EVENT_PAYTR_PAYMENT_SUCCESS = 'PAYTR_PAYMENT_SUCCESS';
    public const EVENT_PAYTR_PAYMENT_FAILED = 'PAYTR_PAYMENT_FAILED';
    public const EVENT_PAYTR_CALLBACK_REJECTED = 'PAYTR_CALLBACK_REJECTED';
    public const EVENT_PAYTR_AMOUNT_MISMATCH = 'PAYTR_AMOUNT_MISMATCH';
    public const EVENT_PAYOUT_TRANSFER_CREATED = 'PAYOUT_TRANSFER_CREATED';
    public const EVENT_PAYOUT_TRANSFER_REQUESTED = 'PAYOUT_TRANSFER_REQUESTED';
    public const EVENT_PAYOUT_TRANSFER_REQUEST_FAILED = 'PAYOUT_TRANSFER_REQUEST_FAILED';
    public const EVENT_PAYOUT_TRANSFER_COMPLETED = 'PAYOUT_TRANSFER_COMPLETED';
    public const EVENT_PAYOUT_TRANSFER_CALLBACK_REJECTED = 'PAYOUT_TRANSFER_CALLBACK_REJECTED';
    public const EVENT_PAYTR_REFUND_INITIATED = 'PAYTR_REFUND_INITIATED';
    public const EVENT_PAYTR_REFUND_REQUESTED = 'PAYTR_REFUND_REQUESTED';
    public const EVENT_PAYTR_REFUND_COMPLETED = 'PAYTR_REFUND_COMPLETED';
    public const EVENT_PAYTR_REFUND_FAILED = 'PAYTR_REFUND_FAILED';
    public const EVENT_PAYTR_REFUND_MANUAL_REVIEW = 'PAYTR_REFUND_MANUAL_REVIEW';

    protected $fillable = [
        'resource_type',
        'resource_id',
        'event_type',
        'actor_user_id',
        'metadata',
        'created_at',
    ];

    protected function casts(): array
    {
        return [
            'metadata' => 'array',
            'created_at' => 'datetime',
        ];
    }

    public function actor(): BelongsTo
    {
        return $this->belongsTo(User::class, 'actor_user_id');
    }
}
