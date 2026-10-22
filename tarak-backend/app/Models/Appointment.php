<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Appointment extends Model
{
    use HasFactory;

    public const STATUS_PENDING = 'PENDING';
    public const STATUS_ALTERNATIVE_PROPOSED = 'ALTERNATIVE_PROPOSED';
    public const STATUS_CONFIRMED = 'CONFIRMED';
    public const STATUS_IN_PROGRESS = 'IN_PROGRESS';
    public const STATUS_AWAITING_CUSTOMER_CONFIRMATION = 'AWAITING_CUSTOMER_CONFIRMATION';
    public const STATUS_COMPLETED = 'COMPLETED';
    public const STATUS_DISPUTED = 'DISPUTED';
    public const STATUS_REJECTED = 'REJECTED';
    public const STATUS_CANCELLED = 'CANCELLED';

    protected $fillable = [
        'customer_user_id',
        'provider_user_id',
        'customer_address_id',
        'status',
        'appointment_date',
        'start_time',
        'end_time',
        'payment_method',
        'total_price',
        'total_duration_minutes',
        'provider_package_id',
        'offering_snapshot',
        'approx_province',
        'approx_district',
        'approx_neighborhood',
        'private_latitude',
        'private_longitude',
        'customer_note',
        'requested_at',
        'confirmed_at',
        'rejected_at',
        'cancelled_at',
        'rejection_reason',
        'service_started_at',
        'provider_completed_at',
        'completed_at',
        'disputed_at',
        'dispute_reason',
        'dispute_note',
    ];

    protected $casts = [
        'appointment_date' => 'date:Y-m-d',
        'requested_at' => 'datetime',
        'confirmed_at' => 'datetime',
        'rejected_at' => 'datetime',
        'cancelled_at' => 'datetime',
        'service_started_at' => 'datetime',
        'provider_completed_at' => 'datetime',
        'completed_at' => 'datetime',
        'disputed_at' => 'datetime',
        'total_price' => 'decimal:2',
        'offering_snapshot' => 'array',
        'total_duration_minutes' => 'integer',
        'private_latitude' => 'float',
        'private_longitude' => 'float',
    ];

    public function customer()
    {
        return $this->belongsTo(User::class, 'customer_user_id');
    }

    public function provider()
    {
        return $this->belongsTo(User::class, 'provider_user_id');
    }

    public function address()
    {
        return $this->belongsTo(CustomerAddress::class, 'customer_address_id');
    }

    public function services()
    {
        return $this->belongsToMany(Service::class, 'appointment_services')
            ->withPivot(['id', 'price_snapshot', 'duration_minutes_snapshot'])
            ->withTimestamps();
    }

    public function appointmentServices()
    {
        return $this->hasMany(AppointmentService::class, 'appointment_id');
    }

    public function alternativeSlots()
    {
        return $this->hasMany(AppointmentAlternativeSlot::class, 'appointment_id');
    }

    public function disputeCase(): \Illuminate\Database\Eloquent\Relations\HasOne
    {
        return $this->hasOne(DisputeCase::class, 'resource_id')
            ->where('resource_type', LocationShareGrant::RESOURCE_SCHEDULED_APPOINTMENT);
    }

    public function servicePayment(): \Illuminate\Database\Eloquent\Relations\HasOne
    {
        return $this->hasOne(ServicePayment::class, 'resource_id')
            ->where('resource_type', LocationShareGrant::RESOURCE_SCHEDULED_APPOINTMENT);
    }
}
