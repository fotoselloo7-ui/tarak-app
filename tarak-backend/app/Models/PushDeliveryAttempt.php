<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PushDeliveryAttempt extends Model
{
    use HasFactory;

    public const STATUS_PENDING = 'PENDING';
    public const STATUS_SENT = 'SENT';
    public const STATUS_FAILED = 'FAILED';
    public const STATUS_INVALID_TOKEN = 'INVALID_TOKEN';
    public const STATUS_SKIPPED = 'SKIPPED';

    protected $fillable = [
        'user_notification_id',
        'push_device_id',
        'status',
        'provider_message_id',
        'error_code',
        'attempt_count',
        'last_attempt_at',
        'sent_at',
        'failed_at',
    ];

    protected $casts = [
        'attempt_count' => 'integer',
        'last_attempt_at' => 'datetime',
        'sent_at' => 'datetime',
        'failed_at' => 'datetime',
    ];

    public function notification(): BelongsTo
    {
        return $this->belongsTo(UserNotification::class, 'user_notification_id');
    }

    public function device(): BelongsTo
    {
        return $this->belongsTo(PushDevice::class, 'push_device_id');
    }

    public function markSent(string $providerMessageId): void
    {
        $this->update([
            'status' => self::STATUS_SENT,
            'provider_message_id' => $providerMessageId,
            'sent_at' => now(),
            'last_attempt_at' => now(),
        ]);

        $this->device?->markUsed();
    }

    public function markFailed(string $errorCode, bool $isInvalidToken = false): void
    {
        $status = $isInvalidToken ? self::STATUS_INVALID_TOKEN : self::STATUS_FAILED;

        $this->update([
            'status' => $status,
            'error_code' => $errorCode,
            'failed_at' => now(),
            'last_attempt_at' => now(),
        ]);

        if ($isInvalidToken) {
            $this->device?->markInvalid($errorCode);
        }
    }

    public function markSkipped(?string $reason = null): void
    {
        $this->update([
            'status' => self::STATUS_SKIPPED,
            'error_code' => $reason,
            'last_attempt_at' => now(),
        ]);
    }
}
