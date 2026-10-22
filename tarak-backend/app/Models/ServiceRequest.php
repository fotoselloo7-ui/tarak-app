<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;

class ServiceRequest extends Model
{
    use HasFactory;

    public const STATUS_OPEN = 'OPEN';
    public const STATUS_ASSIGNED = 'ASSIGNED';
    public const STATUS_IN_PROGRESS = 'IN_PROGRESS';
    public const STATUS_AWAITING_CUSTOMER_CONFIRMATION = 'AWAITING_CUSTOMER_CONFIRMATION';
    public const STATUS_COMPLETED = 'COMPLETED';
    public const STATUS_DISPUTED = 'DISPUTED';
    public const STATUS_CANCELLED = 'CANCELLED';

    public const MODE_INSTANT = 'INSTANT';

    protected $fillable = [
        'customer_user_id',
        'category_id',
        'mode',
        'status',
        'payment_method',
        'customer_address_id',
        'location_text',
        'approx_province',
        'approx_district',
        'approx_neighborhood',
        'private_latitude',
        'private_longitude',
        'customer_note',
        'duration_preference',
        'urgency',
        'target_provider_user_id',
        'provider_service_id',
        'provider_package_id',
        'snapshot_price',
        'snapshot_duration_minutes',
        'offering_snapshot',
        'assigned_provider_user_id',
        'accepted_offer_id',
        'assigned_at',
        'cancelled_at',
        'service_started_at',
        'provider_completed_at',
        'completed_at',
        'disputed_at',
        'dispute_reason',
        'dispute_note',
    ];

    protected function casts(): array
    {
        return [
            'private_latitude' => 'float',
            'private_longitude' => 'float',
            'snapshot_price' => 'decimal:2',
            'snapshot_duration_minutes' => 'integer',
            'offering_snapshot' => 'array',
            'assigned_at' => 'datetime',
            'cancelled_at' => 'datetime',
            'service_started_at' => 'datetime',
            'provider_completed_at' => 'datetime',
            'completed_at' => 'datetime',
            'disputed_at' => 'datetime',
        ];
    }

    public function customer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'customer_user_id');
    }

    public function assignedProvider(): BelongsTo
    {
        return $this->belongsTo(User::class, 'assigned_provider_user_id');
    }

    public function targetProvider(): BelongsTo
    {
        return $this->belongsTo(User::class, 'target_provider_user_id');
    }

    public function isDirect(): bool
    {
        return $this->target_provider_user_id !== null;
    }

    public function acceptedOffer(): BelongsTo
    {
        return $this->belongsTo(ServiceOffer::class, 'accepted_offer_id');
    }

    public function services(): BelongsToMany
    {
        return $this->belongsToMany(Service::class, 'service_request_services')
            ->withTimestamps();
    }

    public function offers(): HasMany
    {
        return $this->hasMany(ServiceOffer::class, 'service_request_id');
    }

    public function address(): BelongsTo
    {
        return $this->belongsTo(CustomerAddress::class, 'customer_address_id');
    }

    public function category(): BelongsTo
    {
        return $this->belongsTo(ServiceCategory::class, 'category_id');
    }

    public function disputeCase(): \Illuminate\Database\Eloquent\Relations\HasOne
    {
        return $this->hasOne(DisputeCase::class, 'resource_id')
            ->where('resource_type', LocationShareGrant::RESOURCE_INSTANT_REQUEST);
    }

    public function servicePayment(): \Illuminate\Database\Eloquent\Relations\HasOne
    {
        return $this->hasOne(ServicePayment::class, 'resource_id')
            ->where('resource_type', LocationShareGrant::RESOURCE_INSTANT_REQUEST);
    }
}
