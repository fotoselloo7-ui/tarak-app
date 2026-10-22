<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class FinanceSetting extends Model
{
    use HasFactory;

    protected $table = 'finance_settings';

    protected $fillable = [
        'default_commission_rate',
        'welcome_bonus_amount',
        'currency',
        'bank_account_holder',
        'bank_name',
        'bank_iban',
        'bank_instructions',
        'topup_min_amount',
    ];

    protected function casts(): array
    {
        return [
            'default_commission_rate' => 'decimal:2',
            'welcome_bonus_amount' => 'decimal:2',
            'topup_min_amount' => 'decimal:2',
        ];
    }

    /** The commission payment bank account is usable only when holder and a valid IBAN are both set. */
    public function hasBankAccount(): bool
    {
        return trim((string) $this->bank_account_holder) !== ''
            && \App\Services\IbanValidator::validate((string) $this->bank_iban);
    }

    /**
     * Singleton accessor for global finance settings.
     */
    public static function current(): self
    {
        // The one settings row, whatever its id is (id is not mass assignable, so after a delete / rolled-back test
        // transaction the re-created row would not be id 1 and a lookup by id would silently create a second row).
        return self::query()->orderBy('id')->first()
            ?? self::create([
                'default_commission_rate' => 15.00,
                'welcome_bonus_amount' => 500.00,
                'currency' => 'TRY',
            ]);
    }
}
