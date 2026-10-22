<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class DisputeCase extends Model
{
    use HasFactory;

    protected $table = 'dispute_cases';

    // Canonical Statuses
    public const STATUS_OPEN = 'OPEN';
    public const STATUS_UNDER_REVIEW = 'UNDER_REVIEW';
    public const STATUS_RESOLVED_CUSTOMER = 'RESOLVED_CUSTOMER';
    public const STATUS_RESOLVED_PROVIDER = 'RESOLVED_PROVIDER';

    // Canonical Resolutions
    public const RESOLUTION_CUSTOMER_FAVOR = 'CUSTOMER_FAVOR';
    public const RESOLUTION_PROVIDER_FAVOR = 'PROVIDER_FAVOR';

    // Resource Types
    public const RESOURCE_INSTANT_REQUEST = LocationShareGrant::RESOURCE_INSTANT_REQUEST;
    public const RESOURCE_SCHEDULED_APPOINTMENT = LocationShareGrant::RESOURCE_SCHEDULED_APPOINTMENT;

    protected $fillable = [
        'resource_type',
        'resource_id',
        'customer_user_id',
        'provider_user_id',
        'payment_method',
        'status',
        'customer_reason',
        'customer_note',
        'admin_resolution',
        'admin_note',
        'opened_at',
        'review_started_at',
        'resolved_at',
        'reviewed_by_admin_user_id',
    ];

    protected function casts(): array
    {
        return [
            'opened_at' => 'datetime',
            'review_started_at' => 'datetime',
            'resolved_at' => 'datetime',
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

    public function reviewedByAdmin(): BelongsTo
    {
        return $this->belongsTo(User::class, 'reviewed_by_admin_user_id');
    }

    public function refunds(): \Illuminate\Database\Eloquent\Relations\HasMany
    {
        return $this->hasMany(PaymentRefund::class, 'dispute_case_id');
    }

    public function isResolved(): bool
    {
        return in_array($this->status, [self::STATUS_RESOLVED_CUSTOMER, self::STATUS_RESOLVED_PROVIDER], true);
    }

    public function canBeReviewed(): bool
    {
        return $this->status === self::STATUS_OPEN;
    }

    public function canBeResolved(): bool
    {
        return in_array($this->status, [self::STATUS_OPEN, self::STATUS_UNDER_REVIEW], true);
    }

    /**
     * Get underlying domain resource.
     */
    public function getResource(): ServiceRequest|Appointment|null
    {
        if ($this->resource_type === self::RESOURCE_INSTANT_REQUEST) {
            return ServiceRequest::find($this->resource_id);
        }

        if ($this->resource_type === self::RESOURCE_SCHEDULED_APPOINTMENT) {
            return Appointment::find($this->resource_id);
        }

        return null;
    }
}
