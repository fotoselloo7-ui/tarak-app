<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ServiceOffer extends Model
{
    use HasFactory;

    public const STATUS_PENDING = 'PENDING';
    public const STATUS_ACCEPTED = 'ACCEPTED';
    public const STATUS_REJECTED = 'REJECTED';

    protected $fillable = [
        'service_request_id',
        'provider_user_id',
        'price',
        'duration_minutes',
        'estimated_arrival_min',
        'payment_preference',
        'message',
        'status',
        'accepted_at',
        'rejected_at',
    ];

    protected function casts(): array
    {
        return [
            'price' => 'decimal:2',
            'duration_minutes' => 'integer',
            'estimated_arrival_min' => 'integer',
            'accepted_at' => 'datetime',
            'rejected_at' => 'datetime',
        ];
    }

    public function serviceRequest(): BelongsTo
    {
        return $this->belongsTo(ServiceRequest::class, 'service_request_id');
    }

    public function provider(): BelongsTo
    {
        return $this->belongsTo(User::class, 'provider_user_id');
    }
}
