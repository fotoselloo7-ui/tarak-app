<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PayoutTransfer extends Model
{
    use HasFactory;

    protected $table = 'payout_transfers';

    public const STATUS_WAITING_ELIGIBILITY = 'WAITING_ELIGIBILITY';
    public const STATUS_READY = 'READY';
    public const STATUS_REQUESTED = 'REQUESTED';
    public const STATUS_COMPLETED = 'COMPLETED';
    public const STATUS_FAILED = 'FAILED';

    protected $fillable = [
        'service_payment_id',
        'provider_user_id',
        'merchant_oid',
        'trans_id',
        'submerchant_amount',
        'total_amount',
        'gross_amount',
        'platform_commission',
        'withholding_amount',
        'final_submerchant_amount',
        'account_holder_name_snapshot',
        'iban_encrypted_snapshot',
        'iban_last4_snapshot',
        'status',
        'eligible_at',
        'requested_at',
        'accepted_by_paytr_at',
        'completed_at',
        'failed_at',
        'paytr_reference',
        'failure_code',
        'failure_message',
    ];

    protected function casts(): array
    {
        return [
            'submerchant_amount' => 'integer',
            'total_amount' => 'integer',
            'gross_amount' => 'decimal:2',
            'platform_commission' => 'decimal:2',
            'withholding_amount' => 'decimal:2',
            'final_submerchant_amount' => 'decimal:2',
            'iban_encrypted_snapshot' => 'encrypted',
            'eligible_at' => 'datetime',
            'requested_at' => 'datetime',
            'accepted_by_paytr_at' => 'datetime',
            'completed_at' => 'datetime',
            'failed_at' => 'datetime',
        ];
    }

    public function servicePayment(): BelongsTo
    {
        return $this->belongsTo(ServicePayment::class, 'service_payment_id');
    }

    public function provider(): BelongsTo
    {
        return $this->belongsTo(User::class, 'provider_user_id');
    }

    public function getIbanMaskedAttribute(): string
    {
        return 'TR' . str_repeat('•', 20) . $this->iban_last4_snapshot;
    }

    /**
     * Provider-friendly status label.
     */
    public function getStatusLabelAttribute(): string
    {
        return match ($this->status) {
            self::STATUS_WAITING_ELIGIBILITY => 'Transfer için bekleniyor',
            self::STATUS_READY => 'Transfer için hazır',
            self::STATUS_REQUESTED => 'Banka transfer talimatı gönderildi',
            self::STATUS_COMPLETED => 'Hakediş transferi tamamlandı',
            self::STATUS_FAILED => 'Transfer işlemi kontrol ediliyor / başarısız',
            default => $this->status,
        };
    }
}
