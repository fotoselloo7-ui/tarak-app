<?php

namespace App\Models;

use Carbon\Carbon;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class LocationShareGrant extends Model
{
    use HasFactory;

    public const RESOURCE_INSTANT_REQUEST = 'INSTANT_REQUEST';
    public const RESOURCE_SCHEDULED_APPOINTMENT = 'SCHEDULED_APPOINTMENT';

    public const SOURCE_SAVED_ADDRESS = 'SAVED_ADDRESS';
    public const SOURCE_CURRENT_LOCATION = 'CURRENT_LOCATION';

    public const STATUS_ACTIVE = 'ACTIVE';
    public const STATUS_REVOKED = 'REVOKED';
    public const STATUS_EXPIRED = 'EXPIRED';

    protected $fillable = [
        'customer_user_id',
        'provider_user_id',
        'resource_type',
        'resource_id',
        'source',
        'status',
        'customer_address_id',
        'exact_location_payload',
        'shared_at',
        'expires_at',
        'revoked_at',
        'expired_at',
    ];

    /**
     * The attributes that should be hidden for serialization.
     * Raw encrypted payload and internal DB fields must never leak directly.
     */
    protected $hidden = [
        'exact_location_payload',
    ];

    protected function casts(): array
    {
        return [
            'exact_location_payload' => 'encrypted:array',
            'shared_at' => 'datetime',
            'expires_at' => 'datetime',
            'revoked_at' => 'datetime',
            'expired_at' => 'datetime',
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

    public function address(): BelongsTo
    {
        return $this->belongsTo(CustomerAddress::class, 'customer_address_id');
    }

    public function events(): HasMany
    {
        return $this->hasMany(LocationShareEvent::class, 'location_share_grant_id');
    }

    public function isExpired(): bool
    {
        return $this->expires_at !== null && $this->expires_at->isPast();
    }

    public function isActive(): bool
    {
        return $this->status === self::STATUS_ACTIVE && ! $this->isExpired();
    }
}
