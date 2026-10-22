<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * A bank (IBAN/havale/EFT) payment of commission credit.
 *
 * A PENDING row is only the business's notice ("I sent X TL"); it never changes a balance.
 * Credit happens exclusively when an admin verifies the money on the bank statement (status PAID).
 */
class CommissionTopup extends Model
{
    use HasFactory;

    public const STATUS_PENDING = 'PENDING';
    public const STATUS_PAID = 'PAID';
    public const STATUS_REJECTED = 'REJECTED';

    public const SOURCE_PROVIDER_NOTICE = 'PROVIDER_NOTICE';
    public const SOURCE_ADMIN_ENTRY = 'ADMIN_ENTRY';

    protected $fillable = [
        'provider_user_id',
        'reference_code',
        'source',
        'status',
        'claimed_amount',
        'verified_amount',
        'transfer_date',
        'sender_name',
        'bank_transaction_ref',
        'provider_note',
        'admin_note',
        'reviewed_by_user_id',
        'reviewed_at',
        'wallet_transaction_id',
    ];

    protected function casts(): array
    {
        return [
            'claimed_amount' => 'decimal:2',
            'verified_amount' => 'decimal:2',
            'transfer_date' => 'date',
            'reviewed_at' => 'datetime',
        ];
    }

    public function provider(): BelongsTo
    {
        return $this->belongsTo(User::class, 'provider_user_id');
    }

    public function reviewer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'reviewed_by_user_id');
    }

    public static function statusLabel(string $status): string
    {
        return match ($status) {
            self::STATUS_PENDING => 'Doğrulama bekliyor',
            self::STATUS_PAID => 'Ödendi',
            self::STATUS_REJECTED => 'Reddedildi',
            default => $status,
        };
    }
}
