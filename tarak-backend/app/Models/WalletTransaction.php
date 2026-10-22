<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use LogicException;

class WalletTransaction extends Model
{
    use HasFactory;

    public $timestamps = false;

    protected $table = 'wallet_transactions';

    // Canonical Transaction Types
    public const TYPE_WELCOME_PROMO_CREDIT = 'WELCOME_PROMO_CREDIT';
    public const TYPE_COMMISSION_RESERVE_CASH = 'COMMISSION_RESERVE_CASH';
    public const TYPE_COMMISSION_RESERVE_PROMO = 'COMMISSION_RESERVE_PROMO';
    public const TYPE_COMMISSION_RELEASE_CASH = 'COMMISSION_RELEASE_CASH';
    public const TYPE_COMMISSION_RELEASE_PROMO = 'COMMISSION_RELEASE_PROMO';
    public const TYPE_COMMISSION_CAPTURE_CASH = 'COMMISSION_CAPTURE_CASH';
    public const TYPE_COMMISSION_CAPTURE_PROMO = 'COMMISSION_CAPTURE_PROMO';
    public const TYPE_ONLINE_PROVIDER_EARNING = 'ONLINE_PROVIDER_EARNING';
    public const TYPE_ADMIN_ADJUSTMENT = 'ADMIN_ADJUSTMENT';
    public const TYPE_FEATURED_PURCHASE = 'FEATURED_PURCHASE';
    public const TYPE_NOTIFICATION_AD_PURCHASE = 'NOTIFICATION_AD_PURCHASE';
    /** A bank (IBAN) payment of commission credit, credited only after an admin verified it on the bank statement. */
    public const TYPE_COMMISSION_TOPUP_CREDIT = 'COMMISSION_TOPUP_CREDIT';

    // Directions
    public const DIRECTION_CREDIT = 'CREDIT';
    public const DIRECTION_DEBIT = 'DEBIT';

    // Buckets
    public const BUCKET_CASH = 'CASH';
    public const BUCKET_PROMO = 'PROMO';
    public const BUCKET_RESERVED_CASH = 'RESERVED_CASH';
    public const BUCKET_RESERVED_PROMO = 'RESERVED_PROMO';

    protected $fillable = [
        'wallet_id',
        'user_id',
        'type',
        'direction',
        'bucket',
        'amount',
        'reference_type',
        'reference_id',
        'idempotency_key',
        'description',
        'metadata',
        'created_at',
    ];

    protected function casts(): array
    {
        return [
            'amount' => 'decimal:2',
            'metadata' => 'array',
            'created_at' => 'datetime',
        ];
    }

    /**
     * Enforce strict ledger immutability:
     * Existing records can NEVER be updated or deleted.
     */
    protected static function boot(): void
    {
        parent::boot();

        static::updating(function () {
            throw new LogicException('Wallet ledger transactions are strictly immutable and cannot be updated.');
        });

        static::deleting(function () {
            throw new LogicException('Wallet ledger transactions are strictly immutable and cannot be deleted.');
        });
    }

    public function wallet(): BelongsTo
    {
        return $this->belongsTo(Wallet::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
