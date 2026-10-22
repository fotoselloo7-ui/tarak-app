<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Str;

/**
 * Safe observability trail for external integrations.
 *
 * NEVER store secrets, tokens, hashes, card data or raw provider payloads here.
 * `record()` sanitises the error message before persisting.
 */
class IntegrationEvent extends Model
{
    protected $table = 'integration_events';

    public const STATUS_SUCCESS = 'success';
    public const STATUS_FAILED = 'failed';
    public const STATUS_WARNING = 'warning';

    protected $fillable = [
        'integration',
        'event_type',
        'direction',
        'reference',
        'status',
        'http_status',
        'error_code',
        'error_message',
        'occurred_at',
    ];

    protected function casts(): array
    {
        return [
            'occurred_at' => 'datetime',
            'http_status' => 'integer',
        ];
    }

    /**
     * Patterns that must never be persisted, even inside an error string.
     * Matches "key=value" / "key: value" / json "key":"value" forms.
     */
    private const SENSITIVE_KEYS = [
        'merchant_key', 'merchant_salt', 'merchant_id', 'paytr_token', 'token',
        'secret', 'password', 'passwd', 'api_key', 'apikey', 'authorization',
        'bearer', 'private_key', 'client_secret', 'hash', 'signature', 'salt',
        'card', 'cc_owner', 'card_number', 'cvv', 'credentials',
    ];

    /**
     * Records an event with a sanitised, length-capped error summary.
     */
    public static function record(
        string $integration,
        string $eventType,
        string $direction,
        string $status,
        ?string $reference = null,
        ?int $httpStatus = null,
        ?string $errorCode = null,
        ?string $errorMessage = null,
    ): self {
        return self::create([
            'integration' => $integration,
            'event_type' => $eventType,
            'direction' => $direction,
            'reference' => $reference ? Str::limit($reference, 110, '') : null,
            'status' => $status,
            'http_status' => $httpStatus,
            'error_code' => $errorCode ? Str::limit($errorCode, 70, '') : null,
            'error_message' => self::sanitise($errorMessage),
            'occurred_at' => now(),
        ]);
    }

    /**
     * Strips anything that looks like a credential out of a free-form message.
     */
    public static function sanitise(?string $message): ?string
    {
        if ($message === null || $message === '') {
            return null;
        }

        $clean = $message;
        foreach (self::SENSITIVE_KEYS as $key) {
            // "key": "value" / key=value / key: value  ->  key=[REDACTED]
            $clean = preg_replace(
                '/(["\']?' . preg_quote($key, '/') . '["\']?\s*[:=]\s*)(["\']?)[^"\',;&\s}]+\2/i',
                '$1[REDACTED]',
                $clean
            ) ?? $clean;
        }

        // Long opaque blobs (base64/hex) are almost always tokens — drop them.
        $clean = preg_replace('/\b[A-Za-z0-9+\/=]{40,}\b/', '[REDACTED]', $clean) ?? $clean;

        return Str::limit(trim($clean), 500);
    }
}
