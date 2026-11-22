<?php

namespace App\Services;

use App\Models\BirthdayGreetingDelivery;
use App\Models\NotificationAd;
use App\Models\NotificationAdSetting;
use App\Models\NotificationDispatch;
use App\Models\NotificationDispatchRecipient;
use App\Models\User;
use App\Models\Wallet;
use App\Models\WalletTransaction;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Unified financial engine for notification charges, reservations, captures, and refunds.
 * Uses Tarak's single Wallet + immutable WalletTransaction ledger with row-level lockForUpdate().
 */
class NotificationBillingService
{
    public function __construct(
        private FinancialService $financial,
    ) {}

    public function getOrCreateWallet(int $userId, bool $lock = false): Wallet
    {
        $wallet = Wallet::firstOrCreate(
            ['user_id' => $userId],
            [
                'balance' => 0.00,
                'promo_balance' => 0.00,
                'reserved_cash_balance' => 0.00,
                'reserved_promo_balance' => 0.00,
                'currency' => 'TRY',
                'is_frozen' => false,
            ]
        );

        if ($lock) {
            return Wallet::where('id', $wallet->id)->lockForUpdate()->firstOrFail();
        }

        return $wallet;
    }

    /**
     * Compute usable balance split without mutating the wallet.
     *
     * @return array{usable_promo_cents: int, usable_cash_cents: int, promo_cents: int, cash_cents: int, balance_source: string, affordable: bool, frozen: bool, error: ?string}
     */
    public function evaluateAffordability(Wallet $wallet, int $amountCents, bool $allowPromo, bool $fallbackToCash): array
    {
        $usablePromoCents = max(
            0,
            FinancialService::parseToCents($wallet->promo_balance) - FinancialService::parseToCents($wallet->reserved_promo_balance)
        );
        $usableCashCents = max(
            0,
            FinancialService::parseToCents($wallet->balance) - FinancialService::parseToCents($wallet->reserved_cash_balance)
        );

        if ($amountCents <= 0) {
            return [
                'usable_promo_cents' => $usablePromoCents,
                'usable_cash_cents' => $usableCashCents,
                'promo_cents' => 0,
                'cash_cents' => 0,
                'balance_source' => NotificationDispatch::SOURCE_NONE,
                'affordable' => true,
                'frozen' => (bool) $wallet->is_frozen,
                'error' => null,
            ];
        }

        if ($wallet->is_frozen) {
            return [
                'usable_promo_cents' => $usablePromoCents,
                'usable_cash_cents' => $usableCashCents,
                'promo_cents' => 0,
                'cash_cents' => 0,
                'balance_source' => NotificationDispatch::SOURCE_NONE,
                'affordable' => false,
                'frozen' => true,
                'error' => 'Cüzdanınız dondurulmuş olduğu için ücretli bildirim gönderilemiyor.',
            ];
        }

        $promoCents = $allowPromo ? min($amountCents, $usablePromoCents) : 0;
        $remainingCents = $amountCents - $promoCents;

        if ($remainingCents > 0) {
            if ($allowPromo && !$fallbackToCash) {
                return [
                    'usable_promo_cents' => $usablePromoCents,
                    'usable_cash_cents' => $usableCashCents,
                    'promo_cents' => $promoCents,
                    'cash_cents' => 0,
                    'balance_source' => NotificationDispatch::SOURCE_NONE,
                    'affordable' => false,
                    'frozen' => false,
                    'error' => 'Kullanılabilir promosyon bakiyeniz yetersiz ve nakit bakiyeye geçiş yönetici tarafından kapatılmış.',
                ];
            }

            if ($remainingCents > $usableCashCents) {
                $available = $allowPromo ? ($usablePromoCents + $usableCashCents) : $usableCashCents;

                return [
                    'usable_promo_cents' => $usablePromoCents,
                    'usable_cash_cents' => $usableCashCents,
                    'promo_cents' => $promoCents,
                    'cash_cents' => 0,
                    'balance_source' => NotificationDispatch::SOURCE_NONE,
                    'affordable' => false,
                    'frozen' => false,
                    'error' => sprintf(
                        'Bakiyeniz yetersiz. Kullanılabilir bakiye: ₺%s, gereken tutar: ₺%s.',
                        number_format($available / 100, 2, ',', '.'),
                        number_format($amountCents / 100, 2, ',', '.')
                    ),
                ];
            }
        }

        $cashCents = $remainingCents;
        $balanceSource = match (true) {
            $promoCents > 0 && $cashCents > 0 => NotificationDispatch::SOURCE_MIXED,
            $promoCents > 0 => NotificationDispatch::SOURCE_PROMO,
            $cashCents > 0 => NotificationDispatch::SOURCE_CASH,
            default => NotificationDispatch::SOURCE_NONE,
        };

        return [
            'usable_promo_cents' => $usablePromoCents,
            'usable_cash_cents' => $usableCashCents,
            'promo_cents' => $promoCents,
            'cash_cents' => $cashCents,
            'balance_source' => $balanceSource,
            'affordable' => true,
            'frozen' => false,
            'error' => null,
        ];
    }

    /**
     * Charge a wallet-funded NotificationAd inside an active DB transaction (locked wallet).
     *
     * @return array{promo_cents: int, cash_cents: int, balance_source: string}
     */
    public function chargeNotificationAdWalletLocked(
        Wallet $wallet,
        User $provider,
        NotificationAd $ad,
        int $priceCents,
        NotificationAdSetting $settings
    ): array {
        $eval = $this->evaluateAffordability(
            $wallet,
            $priceCents,
            (bool) ($settings->allow_promo_for_notification_ads ?? true),
            (bool) ($settings->fallback_to_cash_when_promo_insufficient ?? true)
        );

        if (!$eval['affordable']) {
            throw ValidationException::withMessages(['audience' => [$eval['error'] ?: 'Bakiyeniz yetersiz.']]);
        }

        $promoCents = $eval['promo_cents'];
        $cashCents = $eval['cash_cents'];
        $audienceLabel = NotificationAd::AUDIENCE_NAMES[$ad->audience] ?? $ad->audience;

        if ($promoCents > 0) {
            $promoKey = "NOTIFICATION_AD_PURCHASE_PROMO:{$ad->id}";
            if (!WalletTransaction::where('idempotency_key', $promoKey)->exists()) {
                WalletTransaction::create([
                    'wallet_id' => $wallet->id,
                    'user_id' => $provider->id,
                    'type' => WalletTransaction::TYPE_NOTIFICATION_AD_PURCHASE_PROMO,
                    'direction' => WalletTransaction::DIRECTION_DEBIT,
                    'bucket' => WalletTransaction::BUCKET_PROMO,
                    'amount' => FinancialService::formatFromCents($promoCents),
                    'reference_type' => 'NOTIFICATION_AD',
                    'reference_id' => $ad->id,
                    'idempotency_key' => $promoKey,
                    'description' => "Bildirim reklamı (Promosyon): {$audienceLabel}",
                    'metadata' => ['ad_id' => $ad->id, 'audience' => $ad->audience],
                ]);
                $newPromo = max(0, FinancialService::parseToCents($wallet->promo_balance) - $promoCents);
                $wallet->promo_balance = FinancialService::formatFromCents($newPromo);
            }
        }

        if ($cashCents > 0) {
            $cashKey = "NOTIFICATION_AD_PURCHASE:{$ad->id}";
            if (!WalletTransaction::where('idempotency_key', $cashKey)->exists()) {
                WalletTransaction::create([
                    'wallet_id' => $wallet->id,
                    'user_id' => $provider->id,
                    'type' => WalletTransaction::TYPE_NOTIFICATION_AD_PURCHASE,
                    'direction' => WalletTransaction::DIRECTION_DEBIT,
                    'bucket' => WalletTransaction::BUCKET_CASH,
                    'amount' => FinancialService::formatFromCents($cashCents),
                    'reference_type' => 'NOTIFICATION_AD',
                    'reference_id' => $ad->id,
                    'idempotency_key' => $cashKey,
                    'description' => "Bildirim reklamı: {$audienceLabel}",
                    'metadata' => ['ad_id' => $ad->id, 'audience' => $ad->audience],
                ]);
                $newCash = max(0, FinancialService::parseToCents($wallet->balance) - $cashCents);
                $wallet->balance = FinancialService::formatFromCents($newCash);
            }
        }

        if ($promoCents > 0 || $cashCents > 0) {
            $wallet->save();
            $this->financial->afterPromoCaptured($wallet, $promoCents);
        }

        return [
            'promo_cents' => $promoCents,
            'cash_cents' => $cashCents,
            'balance_source' => $eval['balance_source'],
        ];
    }

    /**
     * Refund a wallet-funded NotificationAd if blocked or permanently failed before delivery.
     */
    public function refundNotificationAdWallet(NotificationAd $ad, string $reason): bool
    {
        return DB::transaction(function () use ($ad, $reason) {
            $lockedAd = NotificationAd::whereKey($ad->id)->lockForUpdate()->first();
            if (!$lockedAd || $lockedAd->payment_source !== NotificationAd::SOURCE_WALLET) {
                if ($lockedAd && $lockedAd->dispatch_id) {
                    NotificationDispatch::whereKey($lockedAd->dispatch_id)->update([
                        'status' => NotificationDispatch::STATUS_BLOCKED,
                        'status_reason' => $reason,
                        'completed_at' => now(),
                    ]);
                }

                return false;
            }

            $promoCents = FinancialService::parseToCents($lockedAd->promo_amount);
            $cashCents = FinancialService::parseToCents($lockedAd->cash_amount);
            // Backward compatibility with legacy rows written before promo_amount/cash_amount existed.
            if ($promoCents === 0 && $cashCents === 0 && FinancialService::parseToCents($lockedAd->amount) > 0) {
                $cashCents = FinancialService::parseToCents($lockedAd->amount);
            }

            if ($promoCents === 0 && $cashCents === 0) {
                return false;
            }

            $wallet = $this->getOrCreateWallet((int) $lockedAd->provider_user_id, true);
            $refundedPromo = 0;
            $refundedCash = 0;

            if ($promoCents > 0) {
                $promoKey = "NOTIFICATION_AD_REFUND_PROMO:{$lockedAd->id}";
                if (!WalletTransaction::where('idempotency_key', $promoKey)->exists()) {
                    WalletTransaction::create([
                        'wallet_id' => $wallet->id,
                        'user_id' => $lockedAd->provider_user_id,
                        'type' => WalletTransaction::TYPE_NOTIFICATION_AD_REFUND,
                        'direction' => WalletTransaction::DIRECTION_CREDIT,
                        'bucket' => WalletTransaction::BUCKET_PROMO,
                        'amount' => FinancialService::formatFromCents($promoCents),
                        'reference_type' => 'NOTIFICATION_AD',
                        'reference_id' => $lockedAd->id,
                        'idempotency_key' => $promoKey,
                        'description' => "Bildirim reklamı iadesi (Promosyon): {$reason}",
                        'metadata' => ['ad_id' => $lockedAd->id, 'reason' => $reason],
                    ]);
                    $wallet->promo_balance = FinancialService::formatFromCents(
                        FinancialService::parseToCents($wallet->promo_balance) + $promoCents
                    );
                    $refundedPromo = $promoCents;
                }
            }

            if ($cashCents > 0) {
                $cashKey = "NOTIFICATION_AD_REFUND_CASH:{$lockedAd->id}";
                if (!WalletTransaction::where('idempotency_key', $cashKey)->exists()) {
                    WalletTransaction::create([
                        'wallet_id' => $wallet->id,
                        'user_id' => $lockedAd->provider_user_id,
                        'type' => WalletTransaction::TYPE_NOTIFICATION_AD_REFUND,
                        'direction' => WalletTransaction::DIRECTION_CREDIT,
                        'bucket' => WalletTransaction::BUCKET_CASH,
                        'amount' => FinancialService::formatFromCents($cashCents),
                        'reference_type' => 'NOTIFICATION_AD',
                        'reference_id' => $lockedAd->id,
                        'idempotency_key' => $cashKey,
                        'description' => "Bildirim reklamı iadesi (Nakit): {$reason}",
                        'metadata' => ['ad_id' => $lockedAd->id, 'reason' => $reason],
                    ]);
                    $wallet->balance = FinancialService::formatFromCents(
                        FinancialService::parseToCents($wallet->balance) + $cashCents
                    );
                    $refundedCash = $cashCents;
                }
            }

            if ($refundedPromo > 0 || $refundedCash > 0) {
                $wallet->save();
            }

            if ($lockedAd->dispatch_id) {
                NotificationDispatch::whereKey($lockedAd->dispatch_id)->update([
                    'refunded_promo_amount' => FinancialService::formatFromCents($refundedPromo),
                    'refunded_cash_amount' => FinancialService::formatFromCents($refundedCash),
                    'status' => NotificationDispatch::STATUS_BLOCKED,
                    'status_reason' => $reason,
                    'completed_at' => now(),
                ]);
            }

            return $refundedPromo > 0 || $refundedCash > 0;
        });
    }

    /**
     * Reserve per-recipient birthday greeting charge safely under lock.
     * Guarantee: at most 1 reservation/billing record per unique billing_reference (provider:customer:year).
     */
    public function reserveBirthdayGreeting(
        int $providerUserId,
        NotificationDispatch $dispatch,
        BirthdayGreetingDelivery $delivery,
        string $billingReference,
        int $unitPriceCents,
        NotificationAdSetting $settings
    ): NotificationDispatchRecipient {
        return DB::transaction(function () use (
            $providerUserId,
            $dispatch,
            $delivery,
            $billingReference,
            $unitPriceCents,
            $settings
        ) {
            $existing = NotificationDispatchRecipient::where('billing_reference', $billingReference)
                ->lockForUpdate()
                ->first();
            if ($existing) {
                return $existing;
            }

            if ($unitPriceCents <= 0) {
                $recipient = NotificationDispatchRecipient::create([
                    'dispatch_id' => $dispatch->id,
                    'provider_user_id' => $providerUserId,
                    'recipient_user_id' => $delivery->customer_user_id,
                    'birthday_delivery_id' => $delivery->id,
                    'billing_reference' => $billingReference,
                    'unit_price' => '0.00',
                    'billing_status' => NotificationDispatchRecipient::BILLING_FREE,
                    'delivery_status' => NotificationDispatchRecipient::DELIVERY_QUEUED,
                ]);
                $delivery->update([
                    'unit_price' => '0.00',
                    'charged_amount' => '0.00',
                    'promo_amount' => '0.00',
                    'cash_amount' => '0.00',
                    'balance_source' => NotificationDispatch::SOURCE_NONE,
                    'billing_status' => NotificationDispatchRecipient::BILLING_FREE,
                    'delivery_status' => NotificationDispatchRecipient::DELIVERY_QUEUED,
                ]);

                return $recipient;
            }

            $wallet = $this->getOrCreateWallet($providerUserId, true);
            $eval = $this->evaluateAffordability(
                $wallet,
                $unitPriceCents,
                (bool) ($settings->allow_promo_for_birthday ?? true),
                (bool) ($settings->fallback_to_cash_when_promo_insufficient ?? true)
            );
            if (!$eval['affordable']) {
                throw ValidationException::withMessages(['wallet' => [$eval['error'] ?: 'Yetersiz bakiye.']]);
            }

            $promoCents = $eval['promo_cents'];
            $cashCents = $eval['cash_cents'];

            if ($promoCents > 0) {
                $promoKey = "BDAY_RESERVE_PROMO:{$billingReference}";
                if (!WalletTransaction::where('idempotency_key', $promoKey)->exists()) {
                    WalletTransaction::create([
                        'wallet_id' => $wallet->id,
                        'user_id' => $providerUserId,
                        'type' => WalletTransaction::TYPE_BIRTHDAY_NOTIFICATION_RESERVE_PROMO,
                        'direction' => WalletTransaction::DIRECTION_DEBIT,
                        'bucket' => WalletTransaction::BUCKET_RESERVED_PROMO,
                        'amount' => FinancialService::formatFromCents($promoCents),
                        'reference_type' => 'BIRTHDAY_GREETING',
                        'reference_id' => $delivery->id,
                        'idempotency_key' => $promoKey,
                        'description' => "Doğum günü bildirimi rezervasyonu (Promosyon) · {$billingReference}",
                        'metadata' => ['dispatch_id' => $dispatch->id, 'billing_reference' => $billingReference],
                    ]);
                    $wallet->reserved_promo_balance = FinancialService::formatFromCents(
                        FinancialService::parseToCents($wallet->reserved_promo_balance) + $promoCents
                    );
                }
            }

            if ($cashCents > 0) {
                $cashKey = "BDAY_RESERVE_CASH:{$billingReference}";
                if (!WalletTransaction::where('idempotency_key', $cashKey)->exists()) {
                    WalletTransaction::create([
                        'wallet_id' => $wallet->id,
                        'user_id' => $providerUserId,
                        'type' => WalletTransaction::TYPE_BIRTHDAY_NOTIFICATION_RESERVE_CASH,
                        'direction' => WalletTransaction::DIRECTION_DEBIT,
                        'bucket' => WalletTransaction::BUCKET_RESERVED_CASH,
                        'amount' => FinancialService::formatFromCents($cashCents),
                        'reference_type' => 'BIRTHDAY_GREETING',
                        'reference_id' => $delivery->id,
                        'idempotency_key' => $cashKey,
                        'description' => "Doğum günü bildirimi rezervasyonu (Nakit) · {$billingReference}",
                        'metadata' => ['dispatch_id' => $dispatch->id, 'billing_reference' => $billingReference],
                    ]);
                    $wallet->reserved_cash_balance = FinancialService::formatFromCents(
                        FinancialService::parseToCents($wallet->reserved_cash_balance) + $cashCents
                    );
                }
            }

            $wallet->save();

            $unitPriceStr = FinancialService::formatFromCents($unitPriceCents);
            $promoStr = FinancialService::formatFromCents($promoCents);
            $cashStr = FinancialService::formatFromCents($cashCents);

            $recipient = NotificationDispatchRecipient::create([
                'dispatch_id' => $dispatch->id,
                'provider_user_id' => $providerUserId,
                'recipient_user_id' => $delivery->customer_user_id,
                'birthday_delivery_id' => $delivery->id,
                'billing_reference' => $billingReference,
                'unit_price' => $unitPriceStr,
                'reserved_promo_amount' => $promoStr,
                'reserved_cash_amount' => $cashStr,
                'billing_status' => NotificationDispatchRecipient::BILLING_RESERVED,
                'delivery_status' => NotificationDispatchRecipient::DELIVERY_QUEUED,
            ]);

            $delivery->update([
                'unit_price' => $unitPriceStr,
                'balance_source' => $eval['balance_source'],
                'billing_status' => NotificationDispatchRecipient::BILLING_RESERVED,
                'delivery_status' => NotificationDispatchRecipient::DELIVERY_QUEUED,
            ]);

            return $recipient;
        });
    }

    /**
     * Capture a RESERVED recipient charge exactly once when FCM accepts at least one device.
     */
    public function captureRecipientReservation(NotificationDispatchRecipient $recipient): bool
    {
        return DB::transaction(function () use ($recipient) {
            $locked = NotificationDispatchRecipient::whereKey($recipient->id)->lockForUpdate()->first();
            if (!$locked || $locked->billing_status !== NotificationDispatchRecipient::BILLING_RESERVED) {
                return false;
            }

            $promoCents = FinancialService::parseToCents($locked->reserved_promo_amount);
            $cashCents = FinancialService::parseToCents($locked->reserved_cash_amount);
            $wallet = $this->getOrCreateWallet((int) $locked->provider_user_id, true);

            if ($promoCents > 0) {
                $key = "BDAY_CAPTURE_PROMO:{$locked->billing_reference}";
                if (!WalletTransaction::where('idempotency_key', $key)->exists()) {
                    WalletTransaction::create([
                        'wallet_id' => $wallet->id,
                        'user_id' => $locked->provider_user_id,
                        'type' => WalletTransaction::TYPE_BIRTHDAY_NOTIFICATION_PURCHASE,
                        'direction' => WalletTransaction::DIRECTION_DEBIT,
                        'bucket' => WalletTransaction::BUCKET_PROMO,
                        'amount' => FinancialService::formatFromCents($promoCents),
                        'reference_type' => 'BIRTHDAY_GREETING',
                        'reference_id' => $locked->birthday_delivery_id ?: $locked->id,
                        'idempotency_key' => $key,
                        'description' => "Doğum günü bildirimi tahsilatı (Promosyon) · {$locked->billing_reference}",
                        'metadata' => ['dispatch_id' => $locked->dispatch_id, 'billing_reference' => $locked->billing_reference],
                    ]);
                    $wallet->reserved_promo_balance = FinancialService::formatFromCents(
                        max(0, FinancialService::parseToCents($wallet->reserved_promo_balance) - $promoCents)
                    );
                    $wallet->promo_balance = FinancialService::formatFromCents(
                        max(0, FinancialService::parseToCents($wallet->promo_balance) - $promoCents)
                    );
                }
            }

            if ($cashCents > 0) {
                $key = "BDAY_CAPTURE_CASH:{$locked->billing_reference}";
                if (!WalletTransaction::where('idempotency_key', $key)->exists()) {
                    WalletTransaction::create([
                        'wallet_id' => $wallet->id,
                        'user_id' => $locked->provider_user_id,
                        'type' => WalletTransaction::TYPE_BIRTHDAY_NOTIFICATION_PURCHASE,
                        'direction' => WalletTransaction::DIRECTION_DEBIT,
                        'bucket' => WalletTransaction::BUCKET_CASH,
                        'amount' => FinancialService::formatFromCents($cashCents),
                        'reference_type' => 'BIRTHDAY_GREETING',
                        'reference_id' => $locked->birthday_delivery_id ?: $locked->id,
                        'idempotency_key' => $key,
                        'description' => "Doğum günü bildirimi tahsilatı (Nakit) · {$locked->billing_reference}",
                        'metadata' => ['dispatch_id' => $locked->dispatch_id, 'billing_reference' => $locked->billing_reference],
                    ]);
                    $wallet->reserved_cash_balance = FinancialService::formatFromCents(
                        max(0, FinancialService::parseToCents($wallet->reserved_cash_balance) - $cashCents)
                    );
                    $wallet->balance = FinancialService::formatFromCents(
                        max(0, FinancialService::parseToCents($wallet->balance) - $cashCents)
                    );
                }
            }

            $wallet->save();
            $this->financial->afterPromoCaptured($wallet, $promoCents);

            $locked->update([
                'billing_status' => NotificationDispatchRecipient::BILLING_CAPTURED,
                'captured_promo_amount' => FinancialService::formatFromCents($promoCents),
                'captured_cash_amount' => FinancialService::formatFromCents($cashCents),
                'settled_at' => now(),
            ]);

            if ($locked->birthday_delivery_id) {
                $balanceSource = match (true) {
                    $promoCents > 0 && $cashCents > 0 => NotificationDispatch::SOURCE_MIXED,
                    $promoCents > 0 => NotificationDispatch::SOURCE_PROMO,
                    $cashCents > 0 => NotificationDispatch::SOURCE_CASH,
                    default => NotificationDispatch::SOURCE_NONE,
                };
                BirthdayGreetingDelivery::whereKey($locked->birthday_delivery_id)->update([
                    'charged_amount' => FinancialService::formatFromCents($promoCents + $cashCents),
                    'promo_amount' => FinancialService::formatFromCents($promoCents),
                    'cash_amount' => FinancialService::formatFromCents($cashCents),
                    'balance_source' => $balanceSource,
                    'billing_status' => NotificationDispatchRecipient::BILLING_CAPTURED,
                    'delivery_status' => NotificationDispatchRecipient::DELIVERY_FCM_ACCEPTED,
                ]);
            }

            $locked->dispatch?->recalculateCounters();

            return true;
        });
    }

    /**
     * Release reserved funds cleanly on permanent push failure, invalid token, opt-out, no device, or admin block.
     */
    public function releaseRecipientReservation(
        NotificationDispatchRecipient $recipient,
        string $deliveryStatus,
        ?string $errorCode = null
    ): bool {
        return DB::transaction(function () use ($recipient, $deliveryStatus, $errorCode) {
            $locked = NotificationDispatchRecipient::whereKey($recipient->id)->lockForUpdate()->first();
            if (!$locked) {
                return false;
            }

            $released = false;
            if ($locked->billing_status === NotificationDispatchRecipient::BILLING_RESERVED) {
                $promoCents = FinancialService::parseToCents($locked->reserved_promo_amount);
                $cashCents = FinancialService::parseToCents($locked->reserved_cash_amount);
                $wallet = $this->getOrCreateWallet((int) $locked->provider_user_id, true);

                if ($promoCents > 0) {
                    $key = "BDAY_RELEASE_PROMO:{$locked->billing_reference}";
                    if (!WalletTransaction::where('idempotency_key', $key)->exists()) {
                        WalletTransaction::create([
                            'wallet_id' => $wallet->id,
                            'user_id' => $locked->provider_user_id,
                            'type' => WalletTransaction::TYPE_BIRTHDAY_NOTIFICATION_REFUND,
                            'direction' => WalletTransaction::DIRECTION_CREDIT,
                            'bucket' => WalletTransaction::BUCKET_RESERVED_PROMO,
                            'amount' => FinancialService::formatFromCents($promoCents),
                            'reference_type' => 'BIRTHDAY_GREETING',
                            'reference_id' => $locked->birthday_delivery_id ?: $locked->id,
                            'idempotency_key' => $key,
                            'description' => "Doğum günü rezervasyon iadesi (Promosyon) · {$locked->billing_reference}",
                            'metadata' => ['delivery_status' => $deliveryStatus, 'error_code' => $errorCode],
                        ]);
                        $wallet->reserved_promo_balance = FinancialService::formatFromCents(
                            max(0, FinancialService::parseToCents($wallet->reserved_promo_balance) - $promoCents)
                        );
                    }
                }

                if ($cashCents > 0) {
                    $key = "BDAY_RELEASE_CASH:{$locked->billing_reference}";
                    if (!WalletTransaction::where('idempotency_key', $key)->exists()) {
                        WalletTransaction::create([
                            'wallet_id' => $wallet->id,
                            'user_id' => $locked->provider_user_id,
                            'type' => WalletTransaction::TYPE_BIRTHDAY_NOTIFICATION_REFUND,
                            'direction' => WalletTransaction::DIRECTION_CREDIT,
                            'bucket' => WalletTransaction::BUCKET_RESERVED_CASH,
                            'amount' => FinancialService::formatFromCents($cashCents),
                            'reference_type' => 'BIRTHDAY_GREETING',
                            'reference_id' => $locked->birthday_delivery_id ?: $locked->id,
                            'idempotency_key' => $key,
                            'description' => "Doğum günü rezervasyon iadesi (Nakit) · {$locked->billing_reference}",
                            'metadata' => ['delivery_status' => $deliveryStatus, 'error_code' => $errorCode],
                        ]);
                        $wallet->reserved_cash_balance = FinancialService::formatFromCents(
                            max(0, FinancialService::parseToCents($wallet->reserved_cash_balance) - $cashCents)
                        );
                    }
                }

                $wallet->save();
                $released = true;
            }

            $newBilling = $locked->billing_status === NotificationDispatchRecipient::BILLING_RESERVED
                ? NotificationDispatchRecipient::BILLING_RELEASED
                : $locked->billing_status;

            $locked->update([
                'billing_status' => $newBilling,
                'delivery_status' => $deliveryStatus,
                'delivery_error_code' => $errorCode ? mb_substr($errorCode, 0, 64) : null,
                'settled_at' => now(),
            ]);

            if ($locked->birthday_delivery_id) {
                BirthdayGreetingDelivery::whereKey($locked->birthday_delivery_id)->update([
                    'charged_amount' => $newBilling === NotificationDispatchRecipient::BILLING_RELEASED ? '0.00' : DB::raw('charged_amount'),
                    'billing_status' => $newBilling,
                    'delivery_status' => $deliveryStatus,
                    'failure_reason' => $errorCode ? mb_substr($errorCode, 0, 250) : null,
                ]);
            }

            $locked->dispatch?->recalculateCounters();

            return $released;
        });
    }

    /**
     * Settle recipient status and billing when SendPushNotification finishes or aborts.
     */
    public function settleByNotificationId(
        int $userNotificationId,
        string $deliveryStatus,
        ?string $errorCode = null,
        bool $fcmAccepted = false,
        int $attemptsCount = 0,
        int $acceptedDevicesCount = 0
    ): void {
        $recipient = NotificationDispatchRecipient::where('user_notification_id', $userNotificationId)->first();
        if (!$recipient) {
            return;
        }

        $recipient->update([
            'device_attempts_count' => max((int) $recipient->device_attempts_count, $attemptsCount),
            'fcm_accepted_devices_count' => max((int) $recipient->fcm_accepted_devices_count, $acceptedDevicesCount),
            'attempted_at' => $recipient->attempted_at ?: now(),
        ]);

        if ($fcmAccepted) {
            $recipient->update([
                'delivery_status' => NotificationDispatchRecipient::DELIVERY_FCM_ACCEPTED,
                'delivery_error_code' => null,
                'settled_at' => now(),
            ]);
            if ($recipient->billing_status === NotificationDispatchRecipient::BILLING_RESERVED) {
                $this->captureRecipientReservation($recipient);
            } else {
                if ($recipient->birthday_delivery_id) {
                    BirthdayGreetingDelivery::whereKey($recipient->birthday_delivery_id)->update([
                        'delivery_status' => NotificationDispatchRecipient::DELIVERY_FCM_ACCEPTED,
                    ]);
                }
                $recipient->dispatch?->recalculateCounters();
            }

            return;
        }

        $this->releaseRecipientReservation($recipient, $deliveryStatus, $errorCode);
    }
}
