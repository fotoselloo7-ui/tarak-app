<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AdminLog extends Model
{
    use HasFactory;

    public $timestamps = false;

    public const ACTION_PROVIDER_DOCUMENT_APPROVED = 'PROVIDER_DOCUMENT_APPROVED';
    public const ACTION_PROVIDER_DOCUMENT_REJECTED = 'PROVIDER_DOCUMENT_REJECTED';
    public const ACTION_PROVIDER_DOCUMENT_REUPLOAD_REQUIRED = 'PROVIDER_DOCUMENT_REUPLOAD_REQUIRED';
    public const ACTION_PROVIDER_APPROVED = 'PROVIDER_APPROVED';
    public const ACTION_PROVIDER_REJECTED = 'PROVIDER_REJECTED';
    public const ACTION_PROVIDER_REUPLOAD_REQUIRED = 'PROVIDER_REUPLOAD_REQUIRED';
    public const ACTION_DISPUTE_REVIEW_STARTED = 'DISPUTE_REVIEW_STARTED';
    public const ACTION_DISPUTE_RESOLVED_CUSTOMER = 'DISPUTE_RESOLVED_CUSTOMER';
    public const ACTION_DISPUTE_RESOLVED_PROVIDER = 'DISPUTE_RESOLVED_PROVIDER';
    public const ACTION_CONTENT_REPORT_HANDLED = 'CONTENT_REPORT_HANDLED';
    public const ACTION_DEMO_DATA_GENERATED = 'DEMO_DATA_GENERATED';
    public const ACTION_DEMO_DATA_PURGED = 'DEMO_DATA_PURGED';
    public const ACTION_USER_UPDATED = 'USER_UPDATED';
    public const ACTION_USER_PASSWORD_RESET = 'USER_PASSWORD_RESET';
    public const ACTION_USER_AVATAR_REMOVED = 'USER_AVATAR_REMOVED';
    public const ACTION_USER_DELETED = 'USER_DELETED';
    public const ACTION_REVIEW_DELETED = 'REVIEW_DELETED';
    public const ACTION_FEATURED_PACKAGE_SAVED = 'FEATURED_PACKAGE_SAVED';
    public const ACTION_FEATURED_PACKAGE_DELETED = 'FEATURED_PACKAGE_DELETED';
    public const ACTION_FEATURED_GRANTED = 'FEATURED_GRANTED';
    public const ACTION_FEATURED_CANCELLED = 'FEATURED_CANCELLED';
    public const ACTION_NOTIFICATION_AD_SETTINGS_SAVED = 'NOTIFICATION_AD_SETTINGS_SAVED';
    public const ACTION_BANK_SETTINGS_SAVED = 'BANK_SETTINGS_SAVED';
    public const ACTION_COMMISSION_TOPUP_VERIFIED = 'COMMISSION_TOPUP_VERIFIED';
    public const ACTION_COMMISSION_TOPUP_REJECTED = 'COMMISSION_TOPUP_REJECTED';
    public const ACTION_COMMISSION_TOPUP_RECORDED = 'COMMISSION_TOPUP_RECORDED';

    /** Every action of the commission / bank collection flow (the admin "Denetim günlüğü" lists exactly these). */
    public const FINANCE_ACTIONS = [
        'BANK_SETTINGS_SAVED',
        'COMMISSION_TOPUP_VERIFIED',
        'COMMISSION_TOPUP_REJECTED',
        'COMMISSION_TOPUP_RECORDED',
    ];

    public const TARGET_PROVIDER = 'PROVIDER';
    public const TARGET_PROVIDER_DOCUMENT = 'PROVIDER_DOCUMENT';
    public const TARGET_DISPUTE_CASE = 'DISPUTE_CASE';
    public const TARGET_CONTENT_REPORT = 'CONTENT_REPORT';
    public const TARGET_SYSTEM = 'SYSTEM';
    public const TARGET_USER = 'USER';
    public const TARGET_REVIEW = 'REVIEW';
    public const TARGET_FEATURED = 'FEATURED';
    public const TARGET_COMMISSION_TOPUP = 'COMMISSION_TOPUP';

    protected $fillable = [
        'admin_user_id',
        'action',
        'target_type',
        'target_id',
        'metadata',
        'created_at',
    ];

    protected function casts(): array
    {
        return [
            'metadata' => 'array',
            'created_at' => 'datetime',
        ];
    }

    public function adminUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'admin_user_id');
    }

    /**
     * Record an audit log entry safely.
     * Guarantees no sensitive storage_path or filesystem details are logged.
     */
    public static function logAction(
        int $adminUserId,
        string $action,
        string $targetType,
        int $targetId,
        ?array $metadata = null
    ): self {
        // Strip sensitive paths or large binaries if any accidentally passed
        if ($metadata !== null) {
            unset($metadata['storage_path'], $metadata['file_path'], $metadata['path']);
        }

        return self::create([
            'admin_user_id' => $adminUserId,
            'action' => $action,
            'target_type' => $targetType,
            'target_id' => $targetId,
            'metadata' => $metadata,
            'created_at' => now(),
        ]);
    }
}
