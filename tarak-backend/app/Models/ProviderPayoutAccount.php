<?php

namespace App\Models;

use App\Services\IbanValidator;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ProviderPayoutAccount extends Model
{
    use HasFactory;

    protected $table = 'provider_payout_accounts';

    public const STATUS_ACTIVE = 'ACTIVE';
    public const STATUS_SUSPENDED = 'SUSPENDED';

    public const TAX_STATUS_NOT_CONFIGURED = 'NOT_CONFIGURED';
    public const TAX_STATUS_CONFIGURED = 'CONFIGURED';

    protected $fillable = [
        'provider_user_id',
        'account_holder_name',
        'iban_encrypted',
        'iban_last4',
        'status',
        'verified_at',
        'payout_tax_status',
        'tax_type',
        'tax_id_or_tckn',
        'tax_id_or_tckn_encrypted',
        'tax_id_last2',
        'tax_office',
        'withholding_rate',
        'withholding_basis',
    ];

    /**
     * Cast attributes.
     * Crucial: iban_encrypted and tax_id_or_tckn_encrypted are encrypted in database.
     */
    protected function casts(): array
    {
        return [
            'iban_encrypted' => 'encrypted',
            'tax_id_or_tckn_encrypted' => 'encrypted',
            'verified_at' => 'datetime',
            'withholding_rate' => 'decimal:2',
        ];
    }

    protected static function booted(): void
    {
        static::saving(function (ProviderPayoutAccount $account) {
            if ($account->isDirty('tax_id_or_tckn_encrypted')) {
                $raw = $account->tax_id_or_tckn_encrypted;
                $clean = $raw ? preg_replace('/\s+/', '', (string) $raw) : null;
                $account->tax_id_last2 = $clean ? substr($clean, -2) : null;
            }
        });
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class, 'provider_user_id');
    }

    /**
     * Get masked IBAN (e.g. TR••••••••••••••••••••1234).
     * Never exposes full IBAN to API.
     */
    public function getIbanMaskedAttribute(): string
    {
        return 'TR' . str_repeat('•', 20) . $this->iban_last4;
    }

    /**
     * Get masked Tax ID / TCKN (e.g. *********12).
     * Never exposes full TCKN to API.
     */
    public function getTaxIdMaskedAttribute(): ?string
    {
        $last2 = $this->tax_id_last2;
        if (empty($last2) && !empty($this->tax_id_or_tckn_encrypted)) {
            $last2 = substr((string) $this->tax_id_or_tckn_encrypted, -2);
        }

        if (empty($last2)) {
            return null;
        }

        return str_repeat('*', 9) . $last2;
    }

    public function getTaxIdOrTcknAttribute(): ?string
    {
        return $this->tax_id_or_tckn_encrypted;
    }

    public function setTaxIdOrTcknAttribute(?string $value): void
    {
        $clean = $value ? preg_replace('/\s+/', '', (string) $value) : null;
        $this->tax_id_or_tckn_encrypted = $clean;
        $this->tax_id_last2 = $clean ? substr($clean, -2) : null;
    }
}
