<?php

namespace App\Models;

use Carbon\Carbon;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ServiceStartVerification extends Model
{
    use HasFactory;

    public const RESOURCE_INSTANT_REQUEST = 'INSTANT_REQUEST';
    public const RESOURCE_SCHEDULED_APPOINTMENT = 'SCHEDULED_APPOINTMENT';

    public const STATUS_ACTIVE = 'ACTIVE';
    public const STATUS_VERIFIED = 'VERIFIED';
    public const STATUS_EXPIRED = 'EXPIRED';

    protected $fillable = [
        'resource_type',
        'resource_id',
        'customer_user_id',
        'provider_user_id',
        'code_hash',
        'encrypted_code',
        'status',
        'failed_attempts',
        'locked_until',
        'generated_at',
        'verified_at',
        'expires_at',
    ];

    /**
     * Critical Security:
     * Never serialize or expose code_hash or encrypted_code in default model outputs.
     */
    protected $hidden = [
        'code_hash',
        'encrypted_code',
    ];

    protected function casts(): array
    {
        return [
            'encrypted_code' => 'encrypted',
            'failed_attempts' => 'integer',
            'locked_until' => 'datetime',
            'generated_at' => 'datetime',
            'verified_at' => 'datetime',
            'expires_at' => 'datetime',
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

    /**
     * Check if verification is currently locked due to brute force protection.
     */
    public function isLocked(): bool
    {
        if ($this->locked_until === null) {
            return false;
        }

        return $this->locked_until->isFuture();
    }

    /**
     * Remaining lock seconds.
     */
    public function getRemainingLockSeconds(): int
    {
        if (!$this->isLocked() || $this->locked_until === null) {
            return 0;
        }

        return max(0, Carbon::now()->diffInSeconds($this->locked_until, false));
    }

    /**
     * Check if verification code has expired based on TTL.
     */
    public function isExpired(): bool
    {
        if ($this->status === self::STATUS_EXPIRED) {
            return true;
        }

        if ($this->expires_at !== null && $this->expires_at->isPast()) {
            return true;
        }

        return false;
    }
}
