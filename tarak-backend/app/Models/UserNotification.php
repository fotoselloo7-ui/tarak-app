<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class UserNotification extends Model
{
    use HasFactory;

    protected $table = 'user_notifications';

    // Canonical Notification Types
    public const TYPE_OFFER_RECEIVED = 'OFFER_RECEIVED';
    public const TYPE_OFFER_ACCEPTED = 'OFFER_ACCEPTED';
    public const TYPE_INSTANT_ASSIGNED = 'INSTANT_ASSIGNED';
    public const TYPE_DIRECT_REQUEST_RECEIVED = 'DIRECT_REQUEST_RECEIVED';
    public const TYPE_DIRECT_REQUEST_DECLINED = 'DIRECT_REQUEST_DECLINED';

    public const TYPE_APPOINTMENT_REQUESTED = 'APPOINTMENT_REQUESTED';
    public const TYPE_APPOINTMENT_CONFIRMED = 'APPOINTMENT_CONFIRMED';
    public const TYPE_APPOINTMENT_REJECTED = 'APPOINTMENT_REJECTED';
    public const TYPE_APPOINTMENT_ALTERNATIVE_PROPOSED = 'APPOINTMENT_ALTERNATIVE_PROPOSED';
    public const TYPE_APPOINTMENT_ALTERNATIVE_ACCEPTED = 'APPOINTMENT_ALTERNATIVE_ACCEPTED';

    public const TYPE_LOCATION_SHARED = 'LOCATION_SHARED';

    public const TYPE_SERVICE_STARTED = 'SERVICE_STARTED';
    public const TYPE_PROVIDER_MARKED_FINISHED = 'PROVIDER_MARKED_FINISHED';
    public const TYPE_SERVICE_COMPLETED = 'SERVICE_COMPLETED';

    public const TYPE_DISPUTE_OPENED = 'DISPUTE_OPENED';
    public const TYPE_DISPUTE_RESOLVED_CUSTOMER = 'DISPUTE_RESOLVED_CUSTOMER';
    public const TYPE_DISPUTE_RESOLVED_PROVIDER = 'DISPUTE_RESOLVED_PROVIDER';

    public const TYPE_PAYMENT_RECEIVED = 'PAYMENT_RECEIVED';
    public const TYPE_PAYMENT_REFUNDED = 'PAYMENT_REFUNDED';

    public const TYPE_PAYOUT_TRANSFER_COMPLETED = 'PAYOUT_TRANSFER_COMPLETED';
    public const TYPE_PAYOUT_TRANSFER_FAILED = 'PAYOUT_TRANSFER_FAILED';

    public const TYPE_GIFT_COMMISSION_DEPLETED = 'GIFT_COMMISSION_DEPLETED';
    public const TYPE_COMMISSION_TOPUP_VERIFIED = 'COMMISSION_TOPUP_VERIFIED';
    public const TYPE_COMMISSION_TOPUP_REJECTED = 'COMMISSION_TOPUP_REJECTED';

    public const TYPE_FEATURED_STARTED = 'FEATURED_STARTED';
    public const TYPE_FEATURED_EXPIRED = 'FEATURED_EXPIRED';

    /** A provider's paid discount campaign ("bildirim reklamı"). */
    public const TYPE_PROVIDER_CAMPAIGN = 'PROVIDER_CAMPAIGN';

    // Canonical Resource Types
    public const RESOURCE_INSTANT_REQUEST = 'INSTANT_REQUEST';
    public const RESOURCE_SCHEDULED_APPOINTMENT = 'SCHEDULED_APPOINTMENT';
    public const RESOURCE_DISPUTE_CASE = 'DISPUTE_CASE';
    public const RESOURCE_SERVICE_PAYMENT = 'SERVICE_PAYMENT';
    public const RESOURCE_PAYOUT_TRANSFER = 'PAYOUT_TRANSFER';
    public const RESOURCE_PAYMENT_REFUND = 'PAYMENT_REFUND';
    public const RESOURCE_PROVIDER_PROFILE = 'PROVIDER_PROFILE';
    public const RESOURCE_COMMISSION_TOPUP = 'COMMISSION_TOPUP';

    protected $fillable = [
        'user_id',
        'type',
        'title',
        'message',
        'resource_type',
        'resource_id',
        'action_url',
        'metadata',
        'idempotency_key',
        'read_at',
    ];

    protected function casts(): array
    {
        return [
            'metadata' => 'array',
            'read_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function scopeUnread(Builder $query): Builder
    {
        return $query->whereNull('read_at');
    }

    public function isRead(): bool
    {
        return $this->read_at !== null;
    }

    public function markAsRead(): bool
    {
        if ($this->isRead()) {
            return true;
        }

        $this->read_at = now();
        return $this->save();
    }
}
