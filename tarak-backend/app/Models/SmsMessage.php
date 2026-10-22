<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * SMS delivery log. Recipients are stored MASKED (0555***4567); the full
 * number is never persisted here. Message bodies are deliberately NOT stored
 * so OTP codes can never leak through the log.
 */
class SmsMessage extends Model
{
    protected $table = 'sms_messages';

    public const STATUS_QUEUED = 'queued';
    public const STATUS_SENT = 'sent';
    public const STATUS_FAILED = 'failed';

    protected $fillable = [
        'provider',
        'recipient_masked',
        'recipient_hash',
        'template_key',
        'status',
        'provider_message_id',
        'error_code',
        'error_message',
        'user_id',
        'sent_at',
    ];

    protected function casts(): array
    {
        return [
            'sent_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
