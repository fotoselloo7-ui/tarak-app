<?php

namespace App\Services;

use App\Models\CommissionReservation;
use App\Models\FinanceSetting;
use App\Models\ProviderProfile;
use App\Models\ServicePayment;
use App\Models\User;
use App\Models\Wallet;
use App\Models\WalletTransaction;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
use LogicException;

class FinancialService
{
    /** Shown whenever a NEW paid CASH job / appointment cannot be accepted because the commission is not covered. */
    public const MSG_INSUFFICIENT_COMMISSION = 'Platform komisyonu için kullanılabilir cüzdan bakiyeniz yetersiz.';

    /** Machine-readable twin of the message above (clients deep-link to the finance center on it). */
    public const CODE_INSUFFICIENT_COMMISSION = 'COMMISSION_CREDIT_INSUFFICIENT';

    public const HINT_INSUFFICIENT_COMMISSION = 'Tarak.app İşletme Finans Merkezi\'nden komisyon bakiyesi yükleyerek yeni nakit işleri tekrar kabul edebilirsiniz. Mevcut randevularınız ve işleriniz bundan etkilenmez.';

    /**
     * Parse any currency representation (int kurus or decimal string) to integer kurus (cents).
     */
    public static function parseToCents(mixed $amount): int
    {
        $str = trim((string) $amount);
        if ($str === '') {
            return 0;
        }

        $negative = str_starts_with($str, '-');
        if ($negative) {
            $str = substr($str, 1);
        }

        if (str_contains($str, '.')) {
            $parts = explode('.', $str, 2);
            $lira = (int) $parts[0];
            $kurus = (int) substr(str_pad($parts[1], 2, '0'), 0, 2);
            $cents = ($lira * 100) + $kurus;
        } else {
            $cents = ((int) $str) * 100;
        }

        return $negative ? -$cents : $cents;
    }

    /**
     * Format integer kurus (cents) safely into standard decimal string without float conversions.
     */
    public static function formatFromCents(int $cents): string
    {
        $negative = $cents < 0;
        $abs = abs($cents);
        $lira = intdiv($abs, 100);
        $kurus = str_pad((string) ($abs % 100), 2, '0', STR_PAD_LEFT);
        return ($negative ? '-' : '') . "{$lira}.{$kurus}";
    }

    /**
     * Calculate commission using integer cents (kuruş) arithmetic.
     * Respects provider_profiles.commission_rate_override if valid (0-100).
     */
    public function calculateCommission(int|User $provider, mixed $grossAmount): array
    {
        $providerId = $provider instanceof User ? $provider->id : $provider;

        $profile = ProviderProfile::where('user_id', $providerId)->first();
        $setting = FinanceSetting::current();

        $rateBasisPoints = self::parseToCents($setting->default_commission_rate ?? '10.00');

        if ($profile && $profile->commission_rate_override !== null) {
            $overrideBp = self::parseToCents($profile->commission_rate_override);
            if ($overrideBp >= 0 && $overrideBp <= 10000) {
                $rateBasisPoints = $overrideBp;
            }
        }

        $grossCents = self::parseToCents($grossAmount);
        // Integer rounding half up: intdiv((grossCents * rateBp) + 5000, 10000)
        $commissionCents = intdiv(($grossCents * $rateBasisPoints) + 5000, 10000);
        $providerNetCents = $grossCents - $commissionCents;

        return [
            'rate' => self::formatFromCents($rateBasisPoints),
            'gross_amount' => self::formatFromCents($grossCents),
            'commission_amount' => self::formatFromCents($commissionCents),
            'provider_net_amount' => self::formatFromCents($providerNetCents),
        ];
    }

    /**
     * Check if provider's available wallet (cash + promo) can afford commission.
     */
    public function canProviderAffordCommission(int|User $provider, mixed $commissionAmount): bool
    {
        $providerId = $provider instanceof User ? $provider->id : $provider;

        $wallet = Wallet::firstOrCreate(
            ['user_id' => $providerId],
            [
                'balance' => 0.00,
                'promo_balance' => 0.00,
                'reserved_cash_balance' => 0.00,
                'reserved_promo_balance' => 0.00,
                'currency' => 'TRY',
                'is_frozen' => false,
            ]
        );

        if ($wallet->is_frozen) {
            return false;
        }

        $commissionCents = self::parseToCents($commissionAmount);
        $usablePromoCents = max(0, self::parseToCents($wallet->promo_balance) - self::parseToCents($wallet->reserved_promo_balance));
        $usableCashCents = max(0, self::parseToCents($wallet->balance) - self::parseToCents($wallet->reserved_cash_balance));
        $totalUsableCents = $usablePromoCents + $usableCashCents;

        return $totalUsableCents >= $commissionCents;
    }

    /**
     * Credit welcome bonus promo to provider upon first true admin approval.
     * Idempotent per provider: WELCOME_BONUS:{provider_user_id}.
     */
    public function creditWelcomeBonus(User|int $provider): bool
    {
        $providerId = $provider instanceof User ? $provider->id : $provider;

        return DB::transaction(function () use ($providerId) {
            $profile = ProviderProfile::where('user_id', $providerId)->lockForUpdate()->first();
            if (!$profile) {
                return false;
            }

            if ($profile->has_received_welcome_bonus) {
                return false;
            }

            $idempotencyKey = "WELCOME_BONUS:{$providerId}";
            if (WalletTransaction::where('idempotency_key', $idempotencyKey)->exists()) {
                $profile->has_received_welcome_bonus = true;
                $profile->save();
                return false;
            }

            $setting = FinanceSetting::current();
            $bonusCents = self::parseToCents($setting->welcome_bonus_amount);
            if ($bonusCents <= 0) {
                return false;
            }

            $wallet = Wallet::firstOrCreate(
                ['user_id' => $providerId],
                [
                    'balance' => 0.00,
                    'promo_balance' => 0.00,
                    'reserved_cash_balance' => 0.00,
                    'reserved_promo_balance' => 0.00,
                    'currency' => 'TRY',
                    'is_frozen' => false,
                ]
            );

            // Lock wallet for update
            $wallet = Wallet::where('id', $wallet->id)->lockForUpdate()->first();

            WalletTransaction::create([
                'wallet_id' => $wallet->id,
                'user_id' => $providerId,
                'type' => WalletTransaction::TYPE_WELCOME_PROMO_CREDIT,
                'direction' => WalletTransaction::DIRECTION_CREDIT,
                'bucket' => WalletTransaction::BUCKET_PROMO,
                'amount' => self::formatFromCents($bonusCents),
                'reference_type' => 'USER',
                'reference_id' => $providerId,
                'idempotency_key' => $idempotencyKey,
                'description' => 'Hoş geldin promosyon bakiyesi',
            ]);

            $currentPromoCents = self::parseToCents($wallet->promo_balance);
            $wallet->promo_balance = self::formatFromCents($currentPromoCents + $bonusCents);
            $wallet->save();

            $profile->has_received_welcome_bonus = true;
            $profile->save();

            return true;
        });
    }

    /**
     * Reserve cash commission from provider wallet (promo prioritized first).
     */
    public function reserveCashCommission(string $resourceType, int $resourceId, User|int $provider, mixed $grossAmount): CommissionReservation
    {
        $providerId = $provider instanceof User ? $provider->id : $provider;

        return DB::transaction(function () use ($resourceType, $resourceId, $providerId, $grossAmount) {
            $existing = CommissionReservation::where('resource_type', $resourceType)
                ->where('resource_id', $resourceId)
                ->lockForUpdate()
                ->first();

            if ($existing) {
                if ($existing->status === CommissionReservation::STATUS_RESERVED) {
                    return $existing;
                }
                throw new LogicException("Reservation already exists with status: {$existing->status}");
            }

            $wallet = Wallet::where('user_id', $providerId)->lockForUpdate()->first();
            if (!$wallet) {
                $wallet = Wallet::create([
                    'user_id' => $providerId,
                    'balance' => 0.00,
                    'promo_balance' => 0.00,
                    'reserved_cash_balance' => 0.00,
                    'reserved_promo_balance' => 0.00,
                    'currency' => 'TRY',
                    'is_frozen' => false,
                ]);
            }

            if ($wallet->is_frozen) {
                throw ValidationException::withMessages([
                    'wallet' => ['Cüzdanınız dondurulmuş olduğu için işlem yapılamaz.'],
                ]);
            }

            $calc = $this->calculateCommission($providerId, $grossAmount);
            $neededCents = self::parseToCents($calc['commission_amount']);

            // Promo priority
            $usablePromoCents = max(0, self::parseToCents($wallet->promo_balance) - self::parseToCents($wallet->reserved_promo_balance));
            $reservePromoCents = min($neededCents, $usablePromoCents);
            $remainingNeededCents = $neededCents - $reservePromoCents;

            $usableCashCents = max(0, self::parseToCents($wallet->balance) - self::parseToCents($wallet->reserved_cash_balance));
            if ($remainingNeededCents > $usableCashCents) {
                throw ValidationException::withMessages([
                    'wallet' => [self::MSG_INSUFFICIENT_COMMISSION],
                ]);
            }

            $reserveCashCents = $remainingNeededCents;

            if ($reservePromoCents > 0) {
                WalletTransaction::create([
                    'wallet_id' => $wallet->id,
                    'user_id' => $providerId,
                    'type' => WalletTransaction::TYPE_COMMISSION_RESERVE_PROMO,
                    'direction' => WalletTransaction::DIRECTION_DEBIT,
                    'bucket' => WalletTransaction::BUCKET_RESERVED_PROMO,
                    'amount' => self::formatFromCents($reservePromoCents),
                    'reference_type' => $resourceType,
                    'reference_id' => $resourceId,
                    'idempotency_key' => "RESERVE_PROMO:{$resourceType}:{$resourceId}",
                    'description' => 'Komisyon rezervasyonu (Promosyon)',
                ]);
            }

            if ($reserveCashCents > 0) {
                WalletTransaction::create([
                    'wallet_id' => $wallet->id,
                    'user_id' => $providerId,
                    'type' => WalletTransaction::TYPE_COMMISSION_RESERVE_CASH,
                    'direction' => WalletTransaction::DIRECTION_DEBIT,
                    'bucket' => WalletTransaction::BUCKET_RESERVED_CASH,
                    'amount' => self::formatFromCents($reserveCashCents),
                    'reference_type' => $resourceType,
                    'reference_id' => $resourceId,
                    'idempotency_key' => "RESERVE_CASH:{$resourceType}:{$resourceId}",
                    'description' => 'Komisyon rezervasyonu (Nakit bakiye)',
                ]);
            }

            $wallet->reserved_promo_balance = self::formatFromCents(self::parseToCents($wallet->reserved_promo_balance) + $reservePromoCents);
            $wallet->reserved_cash_balance = self::formatFromCents(self::parseToCents($wallet->reserved_cash_balance) + $reserveCashCents);
            $wallet->save();

            return CommissionReservation::create([
                'resource_type' => $resourceType,
                'resource_id' => $resourceId,
                'provider_user_id' => $providerId,
                'payment_method' => 'CASH',
                'gross_amount' => $calc['gross_amount'],
                'commission_rate' => $calc['rate'],
                'commission_amount' => $calc['commission_amount'],
                'reserved_cash_amount' => self::formatFromCents($reserveCashCents),
                'reserved_promo_amount' => self::formatFromCents($reservePromoCents),
                'status' => CommissionReservation::STATUS_RESERVED,
                'reserved_at' => now(),
            ]);
        });
    }

    /**
     * Capture cash commission when service is completed.
     */
    public function captureCashCommission(string $resourceType, int $resourceId): ?CommissionReservation
    {
        return DB::transaction(function () use ($resourceType, $resourceId) {
            $reservation = CommissionReservation::where('resource_type', $resourceType)
                ->where('resource_id', $resourceId)
                ->lockForUpdate()
                ->first();

            if (!$reservation) {
                return null;
            }

            if ($reservation->status === CommissionReservation::STATUS_CAPTURED) {
                return $reservation;
            }

            if ($reservation->status !== CommissionReservation::STATUS_RESERVED) {
                throw new LogicException("Reservation cannot be captured in status: {$reservation->status}");
            }

            $wallet = Wallet::where('user_id', $reservation->provider_user_id)->lockForUpdate()->first();
            if ($wallet) {
                $reservedPromoCents = self::parseToCents($reservation->reserved_promo_amount);
                $reservedCashCents = self::parseToCents($reservation->reserved_cash_amount);

                if ($reservedPromoCents > 0) {
                    WalletTransaction::create([
                        'wallet_id' => $wallet->id,
                        'user_id' => $reservation->provider_user_id,
                        'type' => WalletTransaction::TYPE_COMMISSION_CAPTURE_PROMO,
                        'direction' => WalletTransaction::DIRECTION_DEBIT,
                        'bucket' => WalletTransaction::BUCKET_PROMO,
                        'amount' => self::formatFromCents($reservedPromoCents),
                        'reference_type' => $resourceType,
                        'reference_id' => $resourceId,
                        'idempotency_key' => "CAPTURE_PROMO:{$resourceType}:{$resourceId}",
                        'description' => 'Komisyon tahsilatı (Promosyon)',
                    ]);

                    $curReservedPromo = self::parseToCents($wallet->reserved_promo_balance);
                    $curPromo = self::parseToCents($wallet->promo_balance);
                    $wallet->reserved_promo_balance = self::formatFromCents(max(0, $curReservedPromo - $reservedPromoCents));
                    $wallet->promo_balance = self::formatFromCents(max(0, $curPromo - $reservedPromoCents));
                }

                if ($reservedCashCents > 0) {
                    WalletTransaction::create([
                        'wallet_id' => $wallet->id,
                        'user_id' => $reservation->provider_user_id,
                        'type' => WalletTransaction::TYPE_COMMISSION_CAPTURE_CASH,
                        'direction' => WalletTransaction::DIRECTION_DEBIT,
                        'bucket' => WalletTransaction::BUCKET_CASH,
                        'amount' => self::formatFromCents($reservedCashCents),
                        'reference_type' => $resourceType,
                        'reference_id' => $resourceId,
                        'idempotency_key' => "CAPTURE_CASH:{$resourceType}:{$resourceId}",
                        'description' => 'Komisyon tahsilatı (Nakit)',
                    ]);

                    $curReservedCash = self::parseToCents($wallet->reserved_cash_balance);
                    $curCash = self::parseToCents($wallet->balance);
                    $wallet->reserved_cash_balance = self::formatFromCents(max(0, $curReservedCash - $reservedCashCents));
                    $wallet->balance = self::formatFromCents(max(0, $curCash - $reservedCashCents));
                }

                $wallet->save();
                $this->afterPromoCaptured($wallet, $reservedPromoCents);
            }

            $reservation->status = CommissionReservation::STATUS_CAPTURED;
            $reservation->captured_at = now();
            $reservation->save();

            return $reservation;
        });
    }

    /**
     * Release cash commission back to usable balance upon cancellation.
     */
    public function releaseCashCommission(string $resourceType, int $resourceId, ?string $reason = null): ?CommissionReservation
    {
        return DB::transaction(function () use ($resourceType, $resourceId, $reason) {
            $reservation = CommissionReservation::where('resource_type', $resourceType)
                ->where('resource_id', $resourceId)
                ->lockForUpdate()
                ->first();

            if (!$reservation) {
                return null;
            }

            if ($reservation->status === CommissionReservation::STATUS_RELEASED) {
                return $reservation;
            }

            if ($reservation->status !== CommissionReservation::STATUS_RESERVED) {
                throw new LogicException("Reservation cannot be released in status: {$reservation->status}");
            }

            $wallet = Wallet::where('user_id', $reservation->provider_user_id)->lockForUpdate()->first();
            if ($wallet) {
                $reservedPromoCents = self::parseToCents($reservation->reserved_promo_amount);
                $reservedCashCents = self::parseToCents($reservation->reserved_cash_amount);

                if ($reservedPromoCents > 0) {
                    WalletTransaction::create([
                        'wallet_id' => $wallet->id,
                        'user_id' => $reservation->provider_user_id,
                        'type' => WalletTransaction::TYPE_COMMISSION_RELEASE_PROMO,
                        'direction' => WalletTransaction::DIRECTION_CREDIT,
                        'bucket' => WalletTransaction::BUCKET_RESERVED_PROMO,
                        'amount' => self::formatFromCents($reservedPromoCents),
                        'reference_type' => $resourceType,
                        'reference_id' => $resourceId,
                        'idempotency_key' => "RELEASE_PROMO:{$resourceType}:{$resourceId}",
                        'description' => 'Komisyon rezervasyon serbest bırakma (Promosyon)',
                    ]);

                    $curReservedPromo = self::parseToCents($wallet->reserved_promo_balance);
                    $wallet->reserved_promo_balance = self::formatFromCents(max(0, $curReservedPromo - $reservedPromoCents));
                }

                if ($reservedCashCents > 0) {
                    WalletTransaction::create([
                        'wallet_id' => $wallet->id,
                        'user_id' => $reservation->provider_user_id,
                        'type' => WalletTransaction::TYPE_COMMISSION_RELEASE_CASH,
                        'direction' => WalletTransaction::DIRECTION_CREDIT,
                        'bucket' => WalletTransaction::BUCKET_RESERVED_CASH,
                        'amount' => self::formatFromCents($reservedCashCents),
                        'reference_type' => $resourceType,
                        'reference_id' => $resourceId,
                        'idempotency_key' => "RELEASE_CASH:{$resourceType}:{$resourceId}",
                        'description' => 'Komisyon rezervasyon serbest bırakma (Nakit)',
                    ]);

                    $curReservedCash = self::parseToCents($wallet->reserved_cash_balance);
                    $wallet->reserved_cash_balance = self::formatFromCents(max(0, $curReservedCash - $reservedCashCents));
                }

                $wallet->save();
            }

            $reservation->status = CommissionReservation::STATUS_RELEASED;
            $reservation->released_at = now();
            $reservation->save();

            return $reservation;
        });
    }

    /**
     * Hold cash commission for dispute (funds remain reserved).
     */
    public function holdCashCommissionForDispute(string $resourceType, int $resourceId): ?CommissionReservation
    {
        return DB::transaction(function () use ($resourceType, $resourceId) {
            $reservation = CommissionReservation::where('resource_type', $resourceType)
                ->where('resource_id', $resourceId)
                ->lockForUpdate()
                ->first();

            if (!$reservation) {
                return null;
            }

            if ($reservation->status === CommissionReservation::STATUS_HELD_DISPUTE) {
                return $reservation;
            }

            if ($reservation->status !== CommissionReservation::STATUS_RESERVED) {
                throw new LogicException("Only RESERVED commission can be held for dispute. Current: {$reservation->status}");
            }

            $reservation->status = CommissionReservation::STATUS_HELD_DISPUTE;
            $reservation->held_dispute_at = now();
            $reservation->save();

            return $reservation;
        });
    }

    /**
     * Create pending online payment record.
     */
    public function createPendingOnlinePayment(string $resourceType, int $resourceId, int $customerId, int $providerId, mixed $grossAmount): ServicePayment
    {
        return DB::transaction(function () use ($resourceType, $resourceId, $customerId, $providerId, $grossAmount) {
            $existing = ServicePayment::where('resource_type', $resourceType)
                ->where('resource_id', $resourceId)
                ->first();

            if ($existing) {
                return $existing;
            }

            $calc = $this->calculateCommission($providerId, $grossAmount);

            return ServicePayment::create([
                'resource_type' => $resourceType,
                'resource_id' => $resourceId,
                'customer_user_id' => $customerId,
                'provider_user_id' => $providerId,
                'payment_method' => 'ONLINE',
                'gross_amount' => $calc['gross_amount'],
                'commission_rate' => $calc['rate'],
                'commission_amount' => $calc['commission_amount'],
                'provider_net_amount' => $calc['provider_net_amount'],
                'status' => ServicePayment::STATUS_PENDING,
                'gateway' => 'PAYTR',
            ]);
        });
    }

    /**
     * Complete online payment upon service completion (when payment is HELD).
     * Transitions HELD -> TRANSFER_PENDING.
     * No provider wallet credit in this task (Marketplace transfer to seller IBAN will settle later).
     */
    public function completeOnlinePayment(string $resourceType, int $resourceId): ?ServicePayment
    {
        return DB::transaction(function () use ($resourceType, $resourceId) {
            $payment = ServicePayment::where('resource_type', $resourceType)
                ->where('resource_id', $resourceId)
                ->lockForUpdate()
                ->first();

            if (!$payment) {
                return null;
            }

            if ($payment->status === ServicePayment::STATUS_TRANSFER_PENDING || $payment->status === ServicePayment::STATUS_SETTLED) {
                return $payment;
            }

            if ($payment->status !== ServicePayment::STATUS_HELD) {
                throw new LogicException("Online payment must be HELD before completion. Current status: {$payment->status}");
            }

            $payment->status = ServicePayment::STATUS_TRANSFER_PENDING;
            $payment->transfer_pending_at = now();
            $payment->save();

            return $payment;
        });
    }

    /**
     * Alias for backward compatibility if called as settleOnlinePayment.
     */
    public function settleOnlinePayment(string $resourceType, int $resourceId): ?ServicePayment
    {
        return $this->completeOnlinePayment($resourceType, $resourceId);
    }

    /**
     * Hold online payment for dispute. No provider wallet credit!
     */
    public function holdOnlinePaymentForDispute(string $resourceType, int $resourceId): ?ServicePayment
    {
        return DB::transaction(function () use ($resourceType, $resourceId) {
            $payment = ServicePayment::where('resource_type', $resourceType)
                ->where('resource_id', $resourceId)
                ->lockForUpdate()
                ->first();

            if (!$payment) {
                return null;
            }

            if ($payment->status === ServicePayment::STATUS_DISPUTED) {
                return $payment;
            }

            if ($payment->status !== ServicePayment::STATUS_HELD) {
                throw new LogicException("Only HELD online payment can be held for dispute. Current: {$payment->status}");
            }

            $payment->status = ServicePayment::STATUS_DISPUTED;
            $payment->disputed_at = now();
            $payment->save();

            return $payment;
        });
    }

    /**
     * Cancel online payment upon pre-service cancellation.
     */
    public function cancelOnlinePayment(string $resourceType, int $resourceId): ?ServicePayment
    {
        return DB::transaction(function () use ($resourceType, $resourceId) {
            $payment = ServicePayment::where('resource_type', $resourceType)
                ->where('resource_id', $resourceId)
                ->lockForUpdate()
                ->first();

            if (!$payment) {
                return null;
            }

            if ($payment->status === ServicePayment::STATUS_CANCELLED || $payment->status === ServicePayment::STATUS_REFUND_REQUIRED) {
                return $payment;
            }

            if ($payment->status === ServicePayment::STATUS_PENDING) {
                $payment->status = ServicePayment::STATUS_CANCELLED;
                $payment->cancelled_at = now();
                $payment->save();
            } elseif ($payment->status === ServicePayment::STATUS_HELD) {
                $payment->status = ServicePayment::STATUS_REFUND_REQUIRED;
                $payment->cancelled_at = now();
                $payment->save();
            }

            return $payment;
        });
    }

    /**
     * Check if a resource is financially ready for service start / start code / location grant.
     */
    public function isResourceFinanciallyReady(string $resourceType, int $resourceId, string $paymentMethod): bool
    {
        if (strtoupper($paymentMethod) === 'CASH') {
            return CommissionReservation::where('resource_type', $resourceType)
                ->where('resource_id', $resourceId)
                ->whereIn('status', [CommissionReservation::STATUS_RESERVED, CommissionReservation::STATUS_CAPTURED])
                ->exists();
        }

        if (strtoupper($paymentMethod) === 'ONLINE') {
            return ServicePayment::where('resource_type', $resourceType)
                ->where('resource_id', $resourceId)
                ->whereIn('status', [
                    ServicePayment::STATUS_HELD,
                    ServicePayment::STATUS_TRANSFER_PENDING,
                    ServicePayment::STATUS_SETTLED,
                ])
                ->exists();
        }

        return false;
    }

    /**
     * Gate check for start code and service execution.
     * Throws ValidationException with clean domain message if not ready.
     */
    public function ensureFinanciallyReadyForService(string $resourceType, int $resourceId, string $paymentMethod): void
    {
        if (!$this->isResourceFinanciallyReady($resourceType, $resourceId, $paymentMethod)) {
            if (strtoupper($paymentMethod) === 'ONLINE') {
                throw ValidationException::withMessages([
                    'payment' => ['Online ödeme henüz güvenli şekilde alınmadı.'],
                ]);
            }

            throw ValidationException::withMessages([
                'payment' => ['Platform komisyon rezervasyonu henüz tamamlanmadı.'],
            ]);
        }
    }

    /**
     * Gate check for location grant sharing.
     */
    public function ensureFinanciallyReadyForLocationShare(string $resourceType, int $resourceId, string $paymentMethod): void
    {
        if (!$this->isResourceFinanciallyReady($resourceType, $resourceId, $paymentMethod)) {
            if (strtoupper($paymentMethod) === 'ONLINE') {
                throw ValidationException::withMessages([
                    'payment' => ['Online ödeme henüz güvenli şekilde alınmadı.'],
                ]);
            }

            throw ValidationException::withMessages([
                'payment' => ['Platform komisyon rezervasyonu henüz tamamlanmadı.'],
            ]);
        }
    }

    /**
     * Get safe financial summary for a resource to include in responses.
     */
    public function getResourceFinanceSummary(string $resourceType, int $resourceId, string $paymentMethod): array
    {
        $summary = [
            'payment_method' => strtoupper($paymentMethod),
            'is_financially_ready' => $this->isResourceFinanciallyReady($resourceType, $resourceId, $paymentMethod),
        ];

        if (strtoupper($paymentMethod) === 'CASH') {
            $reservation = CommissionReservation::where('resource_type', $resourceType)
                ->where('resource_id', $resourceId)
                ->first();

            $summary['commission_status'] = $reservation?->status ?? 'NOT_RESERVED';
            $summary['commission_amount'] = $reservation ? (float) $reservation->commission_amount : null;
        } else {
            $payment = ServicePayment::where('resource_type', $resourceType)
                ->where('resource_id', $resourceId)
                ->first();

            $summary['payment_status'] = $payment?->status ?? 'PENDING';
            $summary['gross_amount'] = $payment ? (float) $payment->gross_amount : null;
        }

        return $summary;
    }

    /**
     * The "İlk 500 TL komisyon Tarak.app'ten" gift: a commission-only right (never withdrawable cash).
     * granted / used come from the immutable ledger, the rest from the wallet buckets.
     */
    public function giftSummary(Wallet $wallet): array
    {
        $ledgerGranted = $this->ledgerCents($wallet, WalletTransaction::TYPE_WELCOME_PROMO_CREDIT, WalletTransaction::DIRECTION_CREDIT);
        $usedCents = $this->ledgerCents($wallet, WalletTransaction::TYPE_COMMISSION_CAPTURE_PROMO, WalletTransaction::DIRECTION_DEBIT);
        $remainingCents = self::parseToCents($wallet->promo_balance);
        $reservedCents = min($remainingCents, self::parseToCents($wallet->reserved_promo_balance));
        // Promo that was set without the welcome ledger entry (older / demo data) still counts as granted.
        $grantedCents = max($ledgerGranted, $remainingCents + $usedCents);

        return [
            'granted' => (float) self::formatFromCents($grantedCents),
            'used' => (float) self::formatFromCents($usedCents),
            'remaining' => (float) self::formatFromCents($remainingCents),
            'reserved' => (float) self::formatFromCents($reservedCents),
            'usable' => (float) self::formatFromCents(max(0, $remainingCents - $reservedCents)),
            'has_gift' => $grantedCents > 0,
            'is_depleted' => $grantedCents > 0 && $remainingCents === 0,
            'depleted_at' => $wallet->gift_depleted_at?->toISOString(),
            'campaign_message' => self::campaignMessage(),
        ];
    }

    /**
     * Campaign copy "İlk 500 TL komisyon Tarak.app'ten!". The amount follows the admin-configured welcome bonus
     * (500 by default); the text never calls it cash — it only covers Tarak's own commission.
     */
    public static function campaignMessage(): string
    {
        $cents = self::parseToCents(FinanceSetting::current()->welcome_bonus_amount);
        $amount = $cents % 100 === 0
            ? number_format(intdiv($cents, 100), 0, ',', '.')
            : number_format($cents / 100, 2, ',', '.');

        return "İlk {$amount} TL komisyon Tarak.app'ten!";
    }

    private function ledgerCents(Wallet $wallet, string $type, string $direction): int
    {
        $sum = WalletTransaction::where('wallet_id', $wallet->id)
            ->where('type', $type)
            ->where('direction', $direction)
            ->sum('amount');

        return self::parseToCents(number_format((float) $sum, 2, '.', ''));
    }

    /**
     * Called inside the capture transaction after the wallet was saved. When a captured commission used up the very
     * last of the gift right, remember it and queue the one-time e-mail (idempotent: the job re-checks under lock).
     */
    private function afterPromoCaptured(Wallet $wallet, int $capturedPromoCents): void
    {
        if ($capturedPromoCents <= 0 || self::parseToCents($wallet->promo_balance) > 0) {
            return;
        }

        if ($wallet->gift_depleted_at === null) {
            $wallet->gift_depleted_at = now();
            $wallet->save();
        }

        if ($wallet->gift_email_sent_at === null) {
            $userId = (int) $wallet->user_id;
            DB::afterCommit(fn () => \App\Jobs\SendGiftDepletedEmail::dispatch($userId));
        }
    }

    /**
     * Credit a bank payment (IBAN transfer) to the provider's DEPOSITED cash balance.
     * Only an admin who saw the money on the bank statement reaches this; idempotent per topup id.
     */
    public function creditCommissionTopup(\App\Models\CommissionTopup $topup, string $verifiedAmount): bool
    {
        return DB::transaction(function () use ($topup, $verifiedAmount) {
            $idempotencyKey = "COMMISSION_TOPUP:{$topup->id}";
            if (WalletTransaction::where('idempotency_key', $idempotencyKey)->exists()) {
                return false;
            }

            $cents = self::parseToCents($verifiedAmount);
            if ($cents <= 0) {
                throw ValidationException::withMessages(['amount' => ['Doğrulanan tutar sıfırdan büyük olmalıdır.']]);
            }

            $wallet = Wallet::where('user_id', $topup->provider_user_id)->lockForUpdate()->first()
                ?? Wallet::create([
                    'user_id' => $topup->provider_user_id,
                    'balance' => 0.00,
                    'promo_balance' => 0.00,
                    'reserved_cash_balance' => 0.00,
                    'reserved_promo_balance' => 0.00,
                    'currency' => 'TRY',
                    'is_frozen' => false,
                ]);

            $tx = WalletTransaction::create([
                'wallet_id' => $wallet->id,
                'user_id' => $topup->provider_user_id,
                'type' => WalletTransaction::TYPE_COMMISSION_TOPUP_CREDIT,
                'direction' => WalletTransaction::DIRECTION_CREDIT,
                'bucket' => WalletTransaction::BUCKET_CASH,
                'amount' => self::formatFromCents($cents),
                'reference_type' => 'COMMISSION_TOPUP',
                'reference_id' => $topup->id,
                'idempotency_key' => $idempotencyKey,
                'description' => 'Banka havalesi ile komisyon bakiyesi yüklendi (' . $topup->reference_code . ')',
                'metadata' => ['reference_code' => $topup->reference_code, 'bank_transaction_ref' => $topup->bank_transaction_ref],
            ]);

            $wallet->balance = self::formatFromCents(self::parseToCents($wallet->balance) + $cents);
            $wallet->save();

            $topup->wallet_transaction_id = $tx->id;
            $topup->save();

            return true;
        });
    }

    /**
     * Get provider's wallet breakdown.
     */
    public function getProviderFinancialSummary(int $providerUserId): array
    {
        $wallet = Wallet::firstOrCreate(
            ['user_id' => $providerUserId],
            [
                'balance' => 0.00,
                'promo_balance' => 0.00,
                'reserved_cash_balance' => 0.00,
                'reserved_promo_balance' => 0.00,
                'currency' => 'TRY',
                'is_frozen' => false,
            ]
        );

        return [
            'currency' => $wallet->currency,
            'cash_balance' => (float) $wallet->balance,
            'promo_balance' => (float) $wallet->promo_balance,
            'reserved_cash_balance' => (float) $wallet->reserved_cash_balance,
            'reserved_promo_balance' => (float) $wallet->reserved_promo_balance,
            'usable_cash_balance' => (float) $wallet->usable_cash_balance,
            'usable_promo_balance' => (float) $wallet->usable_promo_balance,
            'available_for_commission' => (float) $wallet->usable_commission_balance,
            'usable_commission_balance' => (float) $wallet->usable_commission_balance,
            'withdrawable_balance' => (float) $wallet->withdrawable_balance,
            'is_frozen' => (bool) $wallet->is_frozen,
            // Gift (commission-only), deposited (bank-paid cash) and reserved amounts are reported separately.
            'gift' => $this->giftSummary($wallet),
            'deposited_balance' => (float) $wallet->balance,
            'reserved_total' => (float) self::formatFromCents(
                self::parseToCents($wallet->reserved_cash_balance) + self::parseToCents($wallet->reserved_promo_balance)
            ),
            'active_reservations' => $this->activeReservations($providerUserId),
        ];
    }

    /**
     * Commission currently held for the business's accepted CASH work (released on cancellation, captured on completion).
     * No customer data: only what the commission figure needs.
     */
    private function activeReservations(int $providerUserId): array
    {
        return CommissionReservation::where('provider_user_id', $providerUserId)
            ->whereIn('status', [CommissionReservation::STATUS_RESERVED, CommissionReservation::STATUS_HELD_DISPUTE])
            ->latest('id')
            ->limit(20)
            ->get()
            ->map(fn (CommissionReservation $r) => [
                'id' => $r->id,
                'resource_type' => $r->resource_type,
                'resource_id' => (int) $r->resource_id,
                'label' => ($r->resource_type === 'SCHEDULED_APPOINTMENT' ? 'Randevu #' : 'Anlık talep #') . $r->resource_id,
                'status' => $r->status,
                'commission_amount' => (float) $r->commission_amount,
                'reserved_promo_amount' => (float) $r->reserved_promo_amount,
                'reserved_cash_amount' => (float) $r->reserved_cash_amount,
                'reserved_at' => $r->reserved_at?->toISOString(),
            ])
            ->values()
            ->all();
    }

    /**
     * Resolve CASH dispute in Customer Favor:
     * - Commission reservation HELD_DISPUTE -> RELEASED.
     * - Reserved promo/cash is unreserved and returned to provider usable balance.
     * - NO customer refund (customer paid provider directly in person).
     */
    public function resolveCashDisputeForCustomer(string $resourceType, int $resourceId): CommissionReservation
    {
        return DB::transaction(function () use ($resourceType, $resourceId) {
            $reservation = CommissionReservation::where('resource_type', $resourceType)
                ->where('resource_id', $resourceId)
                ->lockForUpdate()
                ->first();

            if (!$reservation) {
                throw new LogicException("No commission reservation found for {$resourceType} #{$resourceId}");
            }

            // Idempotent: if already RELEASED, return cleanly
            if ($reservation->status === CommissionReservation::STATUS_RELEASED) {
                return $reservation;
            }

            if ($reservation->status !== CommissionReservation::STATUS_HELD_DISPUTE) {
                throw new LogicException("Reservation must be in HELD_DISPUTE to resolve dispute. Current: {$reservation->status}");
            }

            $wallet = Wallet::where('user_id', $reservation->provider_user_id)->lockForUpdate()->first();
            if ($wallet) {
                $reservedPromoCents = self::parseToCents($reservation->reserved_promo_amount);
                $reservedCashCents = self::parseToCents($reservation->reserved_cash_amount);

                if ($reservedPromoCents > 0) {
                    $promoIdempKey = "DISPUTE_RELEASE_PROMO:{$resourceType}:{$resourceId}";
                    if (!WalletTransaction::where('idempotency_key', $promoIdempKey)->exists()) {
                        WalletTransaction::create([
                            'wallet_id' => $wallet->id,
                            'user_id' => $reservation->provider_user_id,
                            'type' => WalletTransaction::TYPE_COMMISSION_RELEASE_PROMO,
                            'direction' => WalletTransaction::DIRECTION_CREDIT,
                            'bucket' => WalletTransaction::BUCKET_RESERVED_PROMO,
                            'amount' => self::formatFromCents($reservedPromoCents),
                            'reference_type' => $resourceType,
                            'reference_id' => $resourceId,
                            'idempotency_key' => $promoIdempKey,
                            'description' => 'Uyuşmazlık çözümü: Komisyon rezervasyonu serbest bırakıldı (Promosyon)',
                        ]);

                        $curReservedPromo = self::parseToCents($wallet->reserved_promo_balance);
                        $wallet->reserved_promo_balance = self::formatFromCents(max(0, $curReservedPromo - $reservedPromoCents));
                    }
                }

                if ($reservedCashCents > 0) {
                    $cashIdempKey = "DISPUTE_RELEASE_CASH:{$resourceType}:{$resourceId}";
                    if (!WalletTransaction::where('idempotency_key', $cashIdempKey)->exists()) {
                        WalletTransaction::create([
                            'wallet_id' => $wallet->id,
                            'user_id' => $reservation->provider_user_id,
                            'type' => WalletTransaction::TYPE_COMMISSION_RELEASE_CASH,
                            'direction' => WalletTransaction::DIRECTION_CREDIT,
                            'bucket' => WalletTransaction::BUCKET_RESERVED_CASH,
                            'amount' => self::formatFromCents($reservedCashCents),
                            'reference_type' => $resourceType,
                            'reference_id' => $resourceId,
                            'idempotency_key' => $cashIdempKey,
                            'description' => 'Uyuşmazlık çözümü: Komisyon rezervasyonu serbest bırakıldı (Nakit)',
                        ]);

                        $curReservedCash = self::parseToCents($wallet->reserved_cash_balance);
                        $wallet->reserved_cash_balance = self::formatFromCents(max(0, $curReservedCash - $reservedCashCents));
                    }
                }

                $wallet->save();
            }

            $reservation->status = CommissionReservation::STATUS_RELEASED;
            $reservation->released_at = now();
            $reservation->save();

            return $reservation;
        });
    }

    /**
     * Resolve CASH dispute in Provider Favor:
     * - Commission reservation HELD_DISPUTE -> CAPTURED.
     * - Reserved promo/cash is captured (debited) from provider wallet.
     * - NO provider gross wallet credit (provider received cash from customer in person).
     */
    public function resolveCashDisputeForProvider(string $resourceType, int $resourceId): CommissionReservation
    {
        return DB::transaction(function () use ($resourceType, $resourceId) {
            $reservation = CommissionReservation::where('resource_type', $resourceType)
                ->where('resource_id', $resourceId)
                ->lockForUpdate()
                ->first();

            if (!$reservation) {
                throw new LogicException("No commission reservation found for {$resourceType} #{$resourceId}");
            }

            // Idempotent: if already CAPTURED, return cleanly
            if ($reservation->status === CommissionReservation::STATUS_CAPTURED) {
                return $reservation;
            }

            if ($reservation->status !== CommissionReservation::STATUS_HELD_DISPUTE) {
                throw new LogicException("Reservation must be in HELD_DISPUTE to resolve dispute. Current: {$reservation->status}");
            }

            $wallet = Wallet::where('user_id', $reservation->provider_user_id)->lockForUpdate()->first();
            if ($wallet) {
                $reservedPromoCents = self::parseToCents($reservation->reserved_promo_amount);
                $reservedCashCents = self::parseToCents($reservation->reserved_cash_amount);

                if ($reservedPromoCents > 0) {
                    $promoIdempKey = "DISPUTE_CAPTURE_PROMO:{$resourceType}:{$resourceId}";
                    if (!WalletTransaction::where('idempotency_key', $promoIdempKey)->exists()) {
                        WalletTransaction::create([
                            'wallet_id' => $wallet->id,
                            'user_id' => $reservation->provider_user_id,
                            'type' => WalletTransaction::TYPE_COMMISSION_CAPTURE_PROMO,
                            'direction' => WalletTransaction::DIRECTION_DEBIT,
                            'bucket' => WalletTransaction::BUCKET_PROMO,
                            'amount' => self::formatFromCents($reservedPromoCents),
                            'reference_type' => $resourceType,
                            'reference_id' => $resourceId,
                            'idempotency_key' => $promoIdempKey,
                            'description' => 'Uyuşmazlık çözümü: Komisyon tahsilatı (Promosyon)',
                        ]);

                        $curPromo = self::parseToCents($wallet->promo_balance);
                        $curReservedPromo = self::parseToCents($wallet->reserved_promo_balance);
                        $wallet->promo_balance = self::formatFromCents(max(0, $curPromo - $reservedPromoCents));
                        $wallet->reserved_promo_balance = self::formatFromCents(max(0, $curReservedPromo - $reservedPromoCents));
                    }
                }

                if ($reservedCashCents > 0) {
                    $cashIdempKey = "DISPUTE_CAPTURE_CASH:{$resourceType}:{$resourceId}";
                    if (!WalletTransaction::where('idempotency_key', $cashIdempKey)->exists()) {
                        WalletTransaction::create([
                            'wallet_id' => $wallet->id,
                            'user_id' => $reservation->provider_user_id,
                            'type' => WalletTransaction::TYPE_COMMISSION_CAPTURE_CASH,
                            'direction' => WalletTransaction::DIRECTION_DEBIT,
                            'bucket' => WalletTransaction::BUCKET_CASH,
                            'amount' => self::formatFromCents($reservedCashCents),
                            'reference_type' => $resourceType,
                            'reference_id' => $resourceId,
                            'idempotency_key' => $cashIdempKey,
                            'description' => 'Uyuşmazlık çözümü: Komisyon tahsilatı (Nakit)',
                        ]);

                        $curCash = self::parseToCents($wallet->balance);
                        $curReservedCash = self::parseToCents($wallet->reserved_cash_balance);
                        $wallet->balance = self::formatFromCents(max(0, $curCash - $reservedCashCents));
                        $wallet->reserved_cash_balance = self::formatFromCents(max(0, $curReservedCash - $reservedCashCents));
                    }
                }

                $wallet->save();
                $this->afterPromoCaptured($wallet, $reservedPromoCents);
            }

            $reservation->status = CommissionReservation::STATUS_CAPTURED;
            $reservation->captured_at = now();
            $reservation->save();

            return $reservation;
        });
    }

    /**
     * Resolve ONLINE dispute in Customer Favor:
     * - Service payment DISPUTED -> REFUND_REQUIRED.
     * - Provider payout: NO. Provider wallet credit: NO.
     * - Real PayTR refund will be processed later.
     */
    public function resolveOnlineDisputeForCustomer(string $resourceType, int $resourceId): ServicePayment
    {
        return DB::transaction(function () use ($resourceType, $resourceId) {
            $payment = ServicePayment::where('resource_type', $resourceType)
                ->where('resource_id', $resourceId)
                ->lockForUpdate()
                ->first();

            if (!$payment) {
                throw new LogicException("No service payment found for {$resourceType} #{$resourceId}");
            }

            // Idempotent: if already REFUND_REQUIRED, return cleanly
            if ($payment->status === ServicePayment::STATUS_REFUND_REQUIRED) {
                return $payment;
            }

            if ($payment->status !== ServicePayment::STATUS_DISPUTED) {
                throw new LogicException("Payment must be in DISPUTED status to resolve dispute. Current: {$payment->status}");
            }

            $payment->status = ServicePayment::STATUS_REFUND_REQUIRED;
            $payment->cancelled_at = now();
            $payment->save();

            return $payment;
        });
    }

    /**
     * Resolve ONLINE dispute in Provider Favor:
     * - Service payment DISPUTED -> TRANSFER_PENDING.
     * - No provider wallet credit in this task (Marketplace seller transfer handles payout).
     */
    public function resolveOnlineDisputeForProvider(string $resourceType, int $resourceId): ServicePayment
    {
        return DB::transaction(function () use ($resourceType, $resourceId) {
            $payment = ServicePayment::where('resource_type', $resourceType)
                ->where('resource_id', $resourceId)
                ->lockForUpdate()
                ->first();

            if (!$payment) {
                throw new LogicException("No service payment found for {$resourceType} #{$resourceId}");
            }

            // Idempotent: if already TRANSFER_PENDING or SETTLED, return cleanly
            if ($payment->status === ServicePayment::STATUS_TRANSFER_PENDING || $payment->status === ServicePayment::STATUS_SETTLED) {
                return $payment;
            }

            if ($payment->status !== ServicePayment::STATUS_DISPUTED) {
                throw new LogicException("Payment must be in DISPUTED status to resolve dispute. Current: {$payment->status}");
            }

            $payment->status = ServicePayment::STATUS_TRANSFER_PENDING;
            $payment->transfer_pending_at = now();
            $payment->save();

            return $payment;
        });
    }
}

