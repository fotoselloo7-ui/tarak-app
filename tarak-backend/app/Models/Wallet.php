<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Wallet extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'balance',
        'promo_balance',
        'reserved_cash_balance',
        'reserved_promo_balance',
        'currency',
        'is_frozen',
        'gift_depleted_at',
        'gift_email_sent_at',
    ];

    protected function casts(): array
    {
        return [
            'balance' => 'decimal:2',
            'promo_balance' => 'decimal:2',
            'reserved_cash_balance' => 'decimal:2',
            'reserved_promo_balance' => 'decimal:2',
            'is_frozen' => 'boolean',
            'gift_depleted_at' => 'datetime',
            'gift_email_sent_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function transactions(): HasMany
    {
        return $this->hasMany(WalletTransaction::class, 'wallet_id');
    }

    public function getUsableCashBalanceAttribute(): string
    {
        $cashCents = \App\Services\FinancialService::parseToCents($this->balance ?? 0);
        $reservedCashCents = \App\Services\FinancialService::parseToCents($this->reserved_cash_balance ?? 0);
        return \App\Services\FinancialService::formatFromCents(max(0, $cashCents - $reservedCashCents));
    }

    public function getUsablePromoBalanceAttribute(): string
    {
        $promoCents = \App\Services\FinancialService::parseToCents($this->promo_balance ?? 0);
        $reservedPromoCents = \App\Services\FinancialService::parseToCents($this->reserved_promo_balance ?? 0);
        return \App\Services\FinancialService::formatFromCents(max(0, $promoCents - $reservedPromoCents));
    }

    public function getUsableCommissionBalanceAttribute(): string
    {
        $cashCents = max(0, \App\Services\FinancialService::parseToCents($this->balance ?? 0) - \App\Services\FinancialService::parseToCents($this->reserved_cash_balance ?? 0));
        $promoCents = max(0, \App\Services\FinancialService::parseToCents($this->promo_balance ?? 0) - \App\Services\FinancialService::parseToCents($this->reserved_promo_balance ?? 0));
        return \App\Services\FinancialService::formatFromCents($cashCents + $promoCents);
    }

    public function getWithdrawableBalanceAttribute(): string
    {
        return $this->usable_cash_balance;
    }
}
