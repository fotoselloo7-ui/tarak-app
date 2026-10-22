<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class PushDevice extends Model
{
    use HasFactory;

    public const PLATFORM_ANDROID = 'ANDROID';
    public const PLATFORM_IOS = 'IOS';

    public const STATUS_ACTIVE = 'ACTIVE';
    public const STATUS_INACTIVE = 'INACTIVE';
    public const STATUS_INVALID = 'INVALID';

    protected $fillable = [
        'user_id',
        'platform',
        'token_hash',
        'token_encrypted',
        'installation_id_hash',
        'status',
        'last_registered_at',
        'last_used_at',
        'invalidated_at',
        'app_version',
        'device_model',
    ];

    protected $casts = [
        'token_encrypted' => 'encrypted',
        'last_registered_at' => 'datetime',
        'last_used_at' => 'datetime',
        'invalidated_at' => 'datetime',
    ];

    /**
     * Never expose raw/encrypted tokens or hashes in JSON serializations.
     */
    protected $hidden = [
        'token_encrypted',
        'token_hash',
        'installation_id_hash',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function deliveryAttempts(): HasMany
    {
        return $this->hasMany(PushDeliveryAttempt::class);
    }

    public function scopeActive($query)
    {
        return $query->where('status', self::STATUS_ACTIVE);
    }

    public function isActive(): bool
    {
        return $this->status === self::STATUS_ACTIVE;
    }

    public function markInvalid(?string $errorCode = null): void
    {
        $this->update([
            'status' => self::STATUS_INVALID,
            'invalidated_at' => now(),
        ]);
    }

    public function markUsed(): void
    {
        $this->update(['last_used_at' => now()]);
    }

    /**
     * Helper to compute SHA-256 hash for token lookup.
     */
    public static function hashToken(string $rawToken): string
    {
        return hash('sha256', trim($rawToken));
    }

    /**
     * Helper to compute SHA-256 hash for installation ID lookup.
     */
    public static function hashInstallationId(?string $installationId): ?string
    {
        return $installationId ? hash('sha256', trim($installationId)) : null;
    }
}
