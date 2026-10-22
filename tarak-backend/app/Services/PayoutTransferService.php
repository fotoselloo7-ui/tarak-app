<?php

namespace App\Services;

use App\Models\PaymentGatewayAttempt;
use App\Models\PayoutTransfer;
use App\Models\ProviderPayoutAccount;
use App\Models\ServiceLifecycleEvent;
use App\Models\ServicePayment;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Symfony\Component\HttpKernel\Exception\UnprocessableEntityHttpException;

class PayoutTransferService
{
    public function __construct(
        protected PaytrService $paytrService
    ) {}

    /**
     * Central Transfer Eligibility Evaluator.
     * Enforces:
     * - service_payment.status === TRANSFER_PENDING
     * - gateway === PAYTR
     * - PayTR payment attempt SUCCESS history exists
     * - payment HELD / paid timestamp exists
     * - Same-day transfer prohibition (next calendar day in Europe/Istanbul)
     * - Provider payout account exists, active, valid TR IBAN checksum
     * - Tax / payout configuration valid (payout_tax_status === CONFIGURED)
     * - Dispute not open (status !== DISPUTED)
     * - REFUND_REQUIRED not set
     * - Payout transfer not already COMPLETED
     */
    public function evaluateEligibility(ServicePayment $payment): array
    {
        $reasons = [];

        // 1. Service Payment Status must be TRANSFER_PENDING
        if ($payment->status === ServicePayment::STATUS_DISPUTED) {
            $reasons[] = 'Ödeme uyuşmazlık (DISPUTED) incelemesinde olduğu için transfer edilemez.';
        } elseif (in_array($payment->status, [
            ServicePayment::STATUS_REFUND_REQUIRED,
            ServicePayment::STATUS_REFUNDING,
            ServicePayment::STATUS_REFUNDED,
            ServicePayment::STATUS_PARTIALLY_REFUNDED,
        ], true)) {
            $reasons[] = "İade sürecindeki veya iade edilmiş ({$payment->status}) ödemeler için hakediş transferi yapılamaz.";
        } elseif ($payment->status === ServicePayment::STATUS_HELD) {
            $reasons[] = 'Hizmet henüz tamamlanmadığı için (HELD) transfer başlatılamaz. Önce hizmet tamamlanmalı ve TRANSFER_PENDING olmalıdır.';
        } elseif ($payment->status !== ServicePayment::STATUS_TRANSFER_PENDING && $payment->status !== ServicePayment::STATUS_SETTLED) {
            $reasons[] = "Ödeme transfer edilebilir durumda değil (Mevcut durum: {$payment->status}).";
        }

        // Check if there are active/completed refunds on this payment
        $hasActiveRefund = \App\Models\PaymentRefund::where('service_payment_id', $payment->id)
            ->whereIn('status', [
                \App\Models\PaymentRefund::STATUS_PENDING,
                \App\Models\PaymentRefund::STATUS_REQUESTED,
                \App\Models\PaymentRefund::STATUS_COMPLETED,
            ])
            ->exists();
        if ($hasActiveRefund) {
            $reasons[] = 'Ödemeye ait aktif veya tamamlanmış iade kaydı bulunduğu için hakediş transferi yapılamaz.';
        }

        // 2. Gateway must be PAYTR (CASH payments NEVER enter payout transfers)
        if (strtoupper((string) $payment->gateway) !== 'PAYTR' || strtoupper((string) $payment->payment_method) === 'CASH') {
            $reasons[] = 'CASH veya PAYTR dışı ödemeler için banka transferi başlatılamaz.';
        }

        // 3. Successful PayTR payment attempt
        $attempt = $payment->gatewayAttempts()
            ->where('gateway', 'PAYTR')
            ->where('status', PaymentGatewayAttempt::STATUS_SUCCESS)
            ->latest()
            ->first();

        if (!$attempt || empty($attempt->merchant_oid)) {
            $reasons[] = 'Ödemeye ait başarılı bir PayTR işlem kaydı (merchant_oid) bulunamadı.';
        }

        // 4. Same-day transfer rule (En erken ödeme gününü takip eden gün Europe/Istanbul)
        $paymentTimestamp = $payment->held_at ?: ($attempt?->callback_received_at ?: $payment->created_at);
        $heldAtIstanbul = Carbon::parse($paymentTimestamp)->setTimezone('Europe/Istanbul');
        $eligibleAt = $heldAtIstanbul->copy()->addDay()->startOfDay();

        $nowIstanbul = now('Europe/Istanbul');
        $isSameDay = $nowIstanbul->lt($eligibleAt);
        if ($isSameDay) {
            $reasons[] = "Aynı gün transfer yasağı: Bu ödeme en erken {$eligibleAt->format('d.m.Y H:i')} tarihinde transfer edilebilir.";
        }

        // 5. Provider payout account validation
        $payoutAccount = ProviderPayoutAccount::where('provider_user_id', $payment->provider_user_id)->first();
        if (!$payoutAccount) {
            $reasons[] = 'Hizmet verenin banka/hakediş hesabı (IBAN) tanımlanmamış.';
        } elseif ($payoutAccount->status !== ProviderPayoutAccount::STATUS_ACTIVE) {
            $reasons[] = 'Hizmet verenin banka hesabı aktif değil.';
        } elseif (!IbanValidator::validate($payoutAccount->iban_encrypted)) {
            $reasons[] = 'Hizmet verenin kayıtlı IBAN numarası veya checksum doğrulaması geçersiz.';
        }

        // 6. Tax / payout configuration validation
        if ($payoutAccount && $payoutAccount->payout_tax_status !== ProviderPayoutAccount::TAX_STATUS_CONFIGURED) {
            $reasons[] = 'Hakediş vergi/ödeme ayarları tamamlanmadan transfer başlatılamaz.';
        }

        // 7. Check existing payout transfer record
        $payoutTransfer = PayoutTransfer::where('service_payment_id', $payment->id)->first();
        if ($payoutTransfer) {
            if ($payoutTransfer->status === PayoutTransfer::STATUS_COMPLETED) {
                $reasons[] = 'Bu hakediş transferi zaten tamamlanmıştır (COMPLETED).';
            } elseif ($payoutTransfer->status === PayoutTransfer::STATUS_REQUESTED) {
                $reasons[] = 'Bu hakediş için PayTR transfer talimatı zaten verilmiş, callback sonucu bekleniyor.';
            }
        }

        $isEligible = empty($reasons);

        // Determine effective internal status
        $status = PayoutTransfer::STATUS_READY;
        if ($payoutTransfer) {
            $status = $payoutTransfer->status;
        } elseif ($isSameDay) {
            $status = PayoutTransfer::STATUS_WAITING_ELIGIBILITY;
        } elseif (!$isEligible) {
            $status = 'NOT_ELIGIBLE';
        }

        return [
            'eligible' => $isEligible,
            'status' => $status,
            'eligible_at' => $eligibleAt,
            'reasons' => $reasons,
            'attempt' => $attempt,
            'payout_account' => $payoutAccount,
            'payout_transfer' => $payoutTransfer,
        ];
    }

    /**
     * Send platform transfer instruction to PayTR (Admin initiated).
     * Strictly atomic with DB transaction and row-level locking.
     */
    public function sendTransfer(ServicePayment $payment, ?User $actor = null): PayoutTransfer
    {
        return DB::transaction(function () use ($payment, $actor) {
            // Lock payment record
            $lockedPayment = ServicePayment::where('id', $payment->id)->lockForUpdate()->first();
            if (!$lockedPayment) {
                throw new UnprocessableEntityHttpException('Ödeme kaydı bulunamadı.');
            }

            // Lock existing transfer if present
            $existingTransfer = PayoutTransfer::where('service_payment_id', $lockedPayment->id)->lockForUpdate()->first();

            if ($existingTransfer && $existingTransfer->status === PayoutTransfer::STATUS_COMPLETED) {
                return $existingTransfer;
            }

            if ($existingTransfer && $existingTransfer->status === PayoutTransfer::STATUS_REQUESTED) {
                return $existingTransfer;
            }

            // Evaluate eligibility
            $eval = $this->evaluateEligibility($lockedPayment);
            if (!$eval['eligible']) {
                $msg = !empty($eval['reasons']) ? implode(' ', $eval['reasons']) : 'Ödeme hakediş transferi için uygun değil.';
                throw new UnprocessableEntityHttpException($msg);
            }

            /** @var PaymentGatewayAttempt $attempt */
            $attempt = $eval['attempt'];
            /** @var ProviderPayoutAccount $payoutAccount */
            $payoutAccount = $eval['payout_account'];

            // Financial Calculations in minor units (kuruş) - No Floats
            $grossCents = FinancialService::parseToCents($lockedPayment->gross_amount);
            $commissionCents = FinancialService::parseToCents($lockedPayment->commission_amount);
            $providerNetCents = $grossCents - $commissionCents;

            // Withholding calculation if configured
            $withholdingCents = 0;
            if ($payoutAccount->withholding_rate !== null && (float) $payoutAccount->withholding_rate > 0) {
                $rateBp = FinancialService::parseToCents($payoutAccount->withholding_rate);
                $withholdingCents = intdiv(($grossCents * $rateBp) + 5000, 10000);
            }

            $finalSubmerchantCents = $providerNetCents - $withholdingCents;
            if ($finalSubmerchantCents <= 0) {
                throw new UnprocessableEntityHttpException('Hesaplanan hakediş tutarı sıfır veya negatif olamaz.');
            }

            // Reuse existing trans_id on safe retry to prevent double payout, or generate new
            $transId = $existingTransfer?->trans_id ?: $this->paytrService->generateTransId();

            // Prepare/Update PayoutTransfer snapshot record
            if ($existingTransfer) {
                $payoutTransfer = $existingTransfer;
                $payoutTransfer->submerchant_amount = $finalSubmerchantCents;
                $payoutTransfer->total_amount = $grossCents;
                $payoutTransfer->gross_amount = FinancialService::formatFromCents($grossCents);
                $payoutTransfer->platform_commission = FinancialService::formatFromCents($commissionCents);
                $payoutTransfer->withholding_amount = FinancialService::formatFromCents($withholdingCents);
                $payoutTransfer->final_submerchant_amount = FinancialService::formatFromCents($finalSubmerchantCents);
                $payoutTransfer->account_holder_name_snapshot = $payoutAccount->account_holder_name;
                $payoutTransfer->iban_encrypted_snapshot = $payoutAccount->iban_encrypted; // Model encrypted cast
                $payoutTransfer->iban_last4_snapshot = $payoutAccount->iban_last4;
                $payoutTransfer->eligible_at = $eval['eligible_at'];
                $payoutTransfer->save();
            } else {
                $payoutTransfer = PayoutTransfer::create([
                    'service_payment_id' => $lockedPayment->id,
                    'provider_user_id' => $lockedPayment->provider_user_id,
                    'merchant_oid' => $attempt->merchant_oid,
                    'trans_id' => $transId,
                    'submerchant_amount' => $finalSubmerchantCents,
                    'total_amount' => $grossCents,
                    'gross_amount' => FinancialService::formatFromCents($grossCents),
                    'platform_commission' => FinancialService::formatFromCents($commissionCents),
                    'withholding_amount' => FinancialService::formatFromCents($withholdingCents),
                    'final_submerchant_amount' => FinancialService::formatFromCents($finalSubmerchantCents),
                    'account_holder_name_snapshot' => $payoutAccount->account_holder_name,
                    'iban_encrypted_snapshot' => $payoutAccount->iban_encrypted,
                    'iban_last4_snapshot' => $payoutAccount->iban_last4,
                    'status' => PayoutTransfer::STATUS_READY,
                    'eligible_at' => $eval['eligible_at'],
                ]);

                ServiceLifecycleEvent::create([
                    'resource_type' => $lockedPayment->resource_type,
                    'resource_id' => $lockedPayment->resource_id,
                    'event_type' => ServiceLifecycleEvent::EVENT_PAYOUT_TRANSFER_CREATED,
                    'actor_user_id' => $actor?->id ?: $lockedPayment->provider_user_id,
                    'metadata' => [
                        'payout_transfer_id' => $payoutTransfer->id,
                        'trans_id' => $transId,
                        'service_payment_id' => $lockedPayment->id,
                        'merchant_oid' => $attempt->merchant_oid,
                        'submerchant_amount' => $finalSubmerchantCents,
                    ],
                    'created_at' => now(),
                ]);
            }

            // Call PayTR platform transfer API
            $response = $this->paytrService->requestPlatformTransfer([
                'merchant_oid' => $attempt->merchant_oid,
                'trans_id' => $transId,
                'submerchant_amount' => $finalSubmerchantCents,
                'total_amount' => $grossCents,
                'transfer_name' => $payoutTransfer->account_holder_name_snapshot,
                'transfer_iban' => $payoutTransfer->iban_encrypted_snapshot,
            ]);

            if ($response['success']) {
                $payoutTransfer->status = PayoutTransfer::STATUS_REQUESTED;
                $payoutTransfer->requested_at = now();
                $payoutTransfer->accepted_by_paytr_at = now();
                $payoutTransfer->paytr_reference = $response['paytr_reference'] ?? $transId;
                $payoutTransfer->failure_code = null;
                $payoutTransfer->failure_message = null;
                $payoutTransfer->save();

                // CRITICAL: Service payment status remains TRANSFER_PENDING until callback confirmation!
                // DO NOT transition service_payment to SETTLED here!

                ServiceLifecycleEvent::create([
                    'resource_type' => $lockedPayment->resource_type,
                    'resource_id' => $lockedPayment->resource_id,
                    'event_type' => ServiceLifecycleEvent::EVENT_PAYOUT_TRANSFER_REQUESTED,
                    'actor_user_id' => $actor?->id ?: $lockedPayment->provider_user_id,
                    'metadata' => [
                        'payout_transfer_id' => $payoutTransfer->id,
                        'trans_id' => $transId,
                        'service_payment_id' => $lockedPayment->id,
                        'merchant_oid' => $attempt->merchant_oid,
                        'paytr_reference' => $payoutTransfer->paytr_reference,
                    ],
                    'created_at' => now(),
                ]);

                return $payoutTransfer;
            }

            // Transfer Request Failed at PayTR API
            $payoutTransfer->status = PayoutTransfer::STATUS_FAILED;
            $payoutTransfer->failed_at = now();
            $payoutTransfer->failure_code = (string) ($response['err_no'] ?? 'API_ERROR');
            $payoutTransfer->failure_message = (string) ($response['err_msg'] ?? 'PayTR transfer isteği kabul edilmedi');
            $payoutTransfer->save();

            // Service payment remains TRANSFER_PENDING
            ServiceLifecycleEvent::create([
                'resource_type' => $lockedPayment->resource_type,
                'resource_id' => $lockedPayment->resource_id,
                'event_type' => ServiceLifecycleEvent::EVENT_PAYOUT_TRANSFER_REQUEST_FAILED,
                'actor_user_id' => $actor?->id ?: $lockedPayment->provider_user_id,
                'metadata' => [
                    'payout_transfer_id' => $payoutTransfer->id,
                    'trans_id' => $transId,
                    'service_payment_id' => $lockedPayment->id,
                    'failure_code' => $payoutTransfer->failure_code,
                    'failure_message' => $payoutTransfer->failure_message,
                ],
                'created_at' => now(),
            ]);

            app(\App\Services\NotificationService::class)->notifyUser(
                $lockedPayment->provider_user_id,
                \App\Models\UserNotification::TYPE_PAYOUT_TRANSFER_FAILED,
                'Hakediş Transferi Durumu',
                'Hakediş transferiniz henüz tamamlanamadı. İşlem kontrol ediliyor.',
                \App\Models\UserNotification::RESOURCE_PAYOUT_TRANSFER,
                $payoutTransfer->id,
                '/barber',
                ['trans_id' => $transId],
                "PAYOUT_TRANSFER_FAILED:{$payoutTransfer->id}:{$lockedPayment->provider_user_id}"
            );

            return $payoutTransfer;
        });
    }

    /**
     * Process PayTR Platform Transfer Result Callback.
     * Public server-to-server webhook.
     * Guaranteed idempotent and atomic.
     * Plain text "OK" on success.
     */
    public function handleTransferResultCallback(array $payload): string
    {
        // 1. Signature Verification
        if (!$this->paytrService->validateTransferCallbackHash($payload)) {
            Log::warning('PayTR platform transfer callback hash validation failed', [
                'trans_ids_present' => !empty($payload['trans_ids']),
            ]);

            ServiceLifecycleEvent::create([
                'resource_type' => 'PLATFORM_TRANSFER',
                'resource_id' => 0,
                'event_type' => ServiceLifecycleEvent::EVENT_PAYOUT_TRANSFER_CALLBACK_REJECTED,
                'actor_user_id' => null,
                'metadata' => [
                    'reason' => 'BAD_HASH',
                ],
                'created_at' => now(),
            ]);

            return 'PAYTR notification failed: bad hash';
        }

        // 2. Parse trans_ids array
        $transIdsRaw = str_replace('\\', '', (string) ($payload['trans_ids'] ?? '[]'));
        $transIds = json_decode($transIdsRaw, true);

        if (!is_array($transIds)) {
            Log::warning('PayTR platform transfer callback: invalid trans_ids JSON');
            return 'OK';
        }

        // 3. Process each trans_id idempotently
        foreach ($transIds as $item) {
            $transId = is_array($item) ? ($item['trans_id'] ?? null) : $item;
            if (!$transId) {
                continue;
            }

            DB::transaction(function () use ($transId) {
                $transfer = PayoutTransfer::where('trans_id', $transId)->lockForUpdate()->first();
                if (!$transfer) {
                    Log::warning("PayTR transfer callback: unknown trans_id {$transId}");
                    return;
                }

                // Idempotent: already COMPLETED
                if ($transfer->status === PayoutTransfer::STATUS_COMPLETED) {
                    return;
                }

                if ($transfer->status === PayoutTransfer::STATUS_REQUESTED) {
                    $transfer->status = PayoutTransfer::STATUS_COMPLETED;
                    $transfer->completed_at = now();
                    $transfer->save();

                    // Transition service_payment from TRANSFER_PENDING -> SETTLED
                    $payment = ServicePayment::where('id', $transfer->service_payment_id)->lockForUpdate()->first();
                    if ($payment && $payment->status === ServicePayment::STATUS_TRANSFER_PENDING) {
                        $payment->status = ServicePayment::STATUS_SETTLED;
                        $payment->settled_at = now();
                        $payment->save();
                    }

                    // CRITICAL: NO PROVIDER WALLET CREDIT!
                    // Marketplace bank transfer sent funds directly to the provider's IBAN.

                    ServiceLifecycleEvent::create([
                        'resource_type' => $payment?->resource_type ?: 'PLATFORM_TRANSFER',
                        'resource_id' => $payment?->resource_id ?: $transfer->id,
                        'event_type' => ServiceLifecycleEvent::EVENT_PAYOUT_TRANSFER_COMPLETED,
                        'actor_user_id' => $transfer->provider_user_id,
                        'metadata' => [
                            'payout_transfer_id' => $transfer->id,
                            'trans_id' => $transfer->trans_id,
                            'service_payment_id' => $transfer->service_payment_id,
                            'merchant_oid' => $transfer->merchant_oid,
                            'final_submerchant_amount' => $transfer->final_submerchant_amount,
                        ],
                        'created_at' => now(),
                    ]);

                    app(\App\Services\NotificationService::class)->notifyUser(
                        $transfer->provider_user_id,
                        \App\Models\UserNotification::TYPE_PAYOUT_TRANSFER_COMPLETED,
                        'Hakediş Transferi Tamamlandı',
                        'Hakediş transferiniz tamamlandı.',
                        \App\Models\UserNotification::RESOURCE_PAYOUT_TRANSFER,
                        $transfer->id,
                        '/barber',
                        [
                            'trans_id' => $transfer->trans_id,
                            'iban_masked' => $transfer->iban_masked,
                            'iban_last4' => $transfer->iban_last4_snapshot,
                            'final_submerchant_amount' => (float) $transfer->final_submerchant_amount,
                        ],
                        "PAYOUT_TRANSFER_COMPLETED:{$transfer->id}:{$transfer->provider_user_id}"
                    );
                }
            });
        }

        return 'OK';
    }
}
