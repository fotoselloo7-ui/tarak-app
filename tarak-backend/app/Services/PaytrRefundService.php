<?php

namespace App\Services;

use App\Jobs\ProcessPaytrRefund;
use App\Models\DisputeCase;
use App\Models\PaymentGatewayAttempt;
use App\Models\PaymentRefund;
use App\Models\PayoutTransfer;
use App\Models\ServiceLifecycleEvent;
use App\Models\ServicePayment;
use App\Models\User;
use App\Models\UserNotification;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Symfony\Component\HttpKernel\Exception\UnprocessableEntityHttpException;

class PaytrRefundService
{
    public function __construct(
        protected PaytrService $paytrService,
        protected NotificationService $notificationService
    ) {}

    /**
     * Generate unique, deterministic refund reference_no (<= 64 chars).
     */
    public function generateReferenceNo(): string
    {
        do {
            $ref = 'REF' . date('ymdHis') . strtoupper(Str::random(8));
        } while (PaymentRefund::where('reference_no', $ref)->exists());

        return $ref;
    }

    /**
     * Find matching return in PayTR status query returns array by reference_no.
     */
    public function findMatchingReturn(array $statusRes, string $referenceNo): ?array
    {
        $returns = $statusRes['returns'] ?? [];
        if (!is_array($returns)) {
            return null;
        }

        foreach ($returns as $ret) {
            if (is_array($ret) && isset($ret['reference_no']) && $ret['reference_no'] === $referenceNo) {
                return $ret;
            }
        }

        return null;
    }

    /**
     * Atomically create and dispatch a PayTR online refund request.
     * Enforces:
     * - CASH payments NEVER call PayTR
     * - Successful PayTR payment merchant_oid reuse (no new merchant_oid)
     * - Payout safety (blocks WAITING/READY payouts; routes to MANUAL_REVIEW if REQUESTED/COMPLETED)
     * - Exact integer minor-unit amount bounds (no float math, no overpayment)
     * - In-flight concurrency & duplicate protection
     * - After-commit queue dispatch
     */
    public function createRefund(
        ServicePayment $payment,
        ?int $amountMinor = null,
        ?DisputeCase $dispute = null,
        ?User $actor = null,
        ?string $referenceNo = null
    ): PaymentRefund {
        // 1. CASH transactions MUST NEVER call PayTR refund API
        if (strtoupper((string) $payment->payment_method) === 'CASH') {
            throw new UnprocessableEntityHttpException('Nakit (CASH) ödemeler için online PayTR iadesi yapılamaz.');
        }

        // 2. Gateway must be PAYTR
        if (strtoupper((string) $payment->gateway) !== 'PAYTR') {
            throw new UnprocessableEntityHttpException('Yalnızca PayTR gateway ödemeleri online iade edilebilir.');
        }

        return DB::transaction(function () use ($payment, $amountMinor, $dispute, $actor, $referenceNo) {
            // Lock payment record for strict concurrency protection
            $lockedPayment = ServicePayment::where('id', $payment->id)->lockForUpdate()->first();
            if (!$lockedPayment) {
                throw new UnprocessableEntityHttpException('Ödeme kaydı bulunamadı.');
            }

            // 3. Find original successful PayTR payment attempt
            $attempt = $lockedPayment->gatewayAttempts()
                ->where('gateway', 'PAYTR')
                ->where('status', PaymentGatewayAttempt::STATUS_SUCCESS)
                ->latest()
                ->first();

            $merchantOid = $attempt?->merchant_oid ?: $lockedPayment->gateway_reference;

            if (empty($merchantOid)) {
                throw new UnprocessableEntityHttpException('Bu ödemeye ait başarılı bir PayTR işlem kaydı (merchant_oid) bulunamadı.');
            }

            // 4. Duplicate dispute refund check (Idempotency)
            if ($dispute !== null) {
                $existingDisputeRefund = PaymentRefund::where('dispute_case_id', $dispute->id)
                    ->whereIn('status', [
                        PaymentRefund::STATUS_PENDING,
                        PaymentRefund::STATUS_REQUESTED,
                        PaymentRefund::STATUS_COMPLETED,
                        PaymentRefund::STATUS_MANUAL_REVIEW,
                    ])
                    ->first();

                if ($existingDisputeRefund) {
                    return $existingDisputeRefund;
                }
            }

            // 5. Minor units arithmetic & previous partial refund check
            $remainingMinor = $lockedPayment->getRemainingRefundableMinor();
            if ($remainingMinor <= 0) {
                throw new UnprocessableEntityHttpException('Bu ödeme için kalan iade edilebilir tutar bulunmamaktadır.');
            }

            // If amount not specified, default to full remaining amount
            $effectiveAmountMinor = $amountMinor ?? $remainingMinor;

            if ($effectiveAmountMinor <= 0) {
                throw new UnprocessableEntityHttpException('İade tutarı sıfırdan büyük olmalıdır.');
            }

            if ($effectiveAmountMinor > $remainingMinor) {
                throw new UnprocessableEntityHttpException("İade tutarı ({$effectiveAmountMinor} kuruş) kalan iade edilebilir tutarı ({$remainingMinor} kuruş) aşamaz.");
            }

            // 6. PAYOUT SAFETY CHECK
            // If payout transfer is already REQUESTED or COMPLETED, automatic refund is prohibited -> MANUAL_REVIEW
            $payoutTransfer = PayoutTransfer::where('service_payment_id', $lockedPayment->id)->first();
            $refNo = $referenceNo ?: $this->generateReferenceNo();

            if ($payoutTransfer && in_array($payoutTransfer->status, [PayoutTransfer::STATUS_REQUESTED, PayoutTransfer::STATUS_COMPLETED])) {
                $refund = PaymentRefund::create([
                    'service_payment_id' => $lockedPayment->id,
                    'dispute_case_id' => $dispute?->id,
                    'merchant_oid' => $merchantOid,
                    'reference_no' => $refNo,
                    'refund_amount_minor' => $effectiveAmountMinor,
                    'currency' => 'TL',
                    'status' => PaymentRefund::STATUS_MANUAL_REVIEW,
                    'failure_reason' => "Hakediş transferi {$payoutTransfer->status} durumunda olduğu için otomatik iade durduruldu. Finans yöneticisi incelemesi (MANUAL_REVIEW) gereklidir.",
                    'created_by_user_id' => $actor?->id,
                    'metadata' => [
                        'payout_transfer_id' => $payoutTransfer->id,
                        'payout_transfer_status' => $payoutTransfer->status,
                        'reason' => 'PAYOUT_ALREADY_IN_FLIGHT_OR_COMPLETED',
                    ],
                ]);

                $lockedPayment->status = ServicePayment::STATUS_REFUND_REQUIRED;
                $lockedPayment->save();

                ServiceLifecycleEvent::create([
                    'resource_type' => $lockedPayment->resource_type,
                    'resource_id' => $lockedPayment->resource_id,
                    'event_type' => ServiceLifecycleEvent::EVENT_PAYTR_REFUND_MANUAL_REVIEW,
                    'actor_user_id' => $actor?->id ?: $lockedPayment->customer_user_id,
                    'metadata' => [
                        'refund_id' => $refund->id,
                        'merchant_oid' => $merchantOid,
                        'reference_no' => $refNo,
                        'payout_status' => $payoutTransfer->status,
                    ],
                    'created_at' => now(),
                ]);

                return $refund;
            }

            // Payout is WAITING_ELIGIBILITY or READY -> block it from transferring!
            if ($payoutTransfer && in_array($payoutTransfer->status, [PayoutTransfer::STATUS_WAITING_ELIGIBILITY, PayoutTransfer::STATUS_READY])) {
                $payoutTransfer->status = PayoutTransfer::STATUS_FAILED;
                $payoutTransfer->failure_message = 'İade süreci başlatıldığı için hakediş transferi sistem tarafından durduruldu.';
                $payoutTransfer->save();
            }

            // 7. Create PaymentRefund record in PENDING status
            $refund = PaymentRefund::create([
                'service_payment_id' => $lockedPayment->id,
                'dispute_case_id' => $dispute?->id,
                'merchant_oid' => $merchantOid,
                'reference_no' => $refNo,
                'refund_amount_minor' => $effectiveAmountMinor,
                'currency' => 'TL',
                'status' => PaymentRefund::STATUS_PENDING,
                'created_by_user_id' => $actor?->id,
                'metadata' => [
                    'created_at' => now()->toIso8601String(),
                ],
            ]);

            // Transition payment to REFUNDING if not already REFUND_REQUIRED
            if ($lockedPayment->status !== ServicePayment::STATUS_REFUND_REQUIRED) {
                $lockedPayment->status = ServicePayment::STATUS_REFUNDING;
                $lockedPayment->save();
            }

            ServiceLifecycleEvent::create([
                'resource_type' => $lockedPayment->resource_type,
                'resource_id' => $lockedPayment->resource_id,
                'event_type' => ServiceLifecycleEvent::EVENT_PAYTR_REFUND_INITIATED,
                'actor_user_id' => $actor?->id ?: $lockedPayment->customer_user_id,
                'metadata' => [
                    'refund_id' => $refund->id,
                    'merchant_oid' => $merchantOid,
                    'reference_no' => $refNo,
                    'amount_minor' => $effectiveAmountMinor,
                ],
                'created_at' => now(),
            ]);

            // 8. Dispatch queue job strictly after DB commit
            DB::afterCommit(function () use ($refund) {
                ProcessPaytrRefund::dispatch($refund->id);
            });

            return $refund;
        });
    }

    /**
     * Process refund instruction against PayTR API.
     * Guaranteed safe against timeouts, duplicate refunds, and network glitches.
     */
    public function processRefund(int $refundId): PaymentRefund
    {
        return DB::transaction(function () use ($refundId) {
            $refund = PaymentRefund::where('id', $refundId)->lockForUpdate()->first();
            if (!$refund) {
                throw new UnprocessableEntityHttpException("İade kaydı bulunamadı: #{$refundId}");
            }

            // Already completed -> idempotent return
            if ($refund->isCompleted()) {
                return $refund;
            }

            // Manual review requires explicit admin action
            if ($refund->isManualReview()) {
                return $refund;
            }

            $payment = ServicePayment::where('id', $refund->service_payment_id)->lockForUpdate()->first();

            // Payout safety check during execution
            $payout = PayoutTransfer::where('service_payment_id', $payment->id)->first();
            if ($payout && in_array($payout->status, [PayoutTransfer::STATUS_REQUESTED, PayoutTransfer::STATUS_COMPLETED])) {
                $refund->status = PaymentRefund::STATUS_MANUAL_REVIEW;
                $refund->failure_reason = "Hakediş transferi {$payout->status} durumunda olduğu için işlem durduruldu (MANUAL_REVIEW).";
                $refund->save();
                return $refund;
            }

            // STEP 1: Reconciliation-first check!
            // In case of timeout or previous attempt, check if PayTR already processed this reference_no
            $statusRes = $this->paytrService->queryPaymentStatus($refund->merchant_oid);
            if (isset($statusRes['status']) && $statusRes['status'] === 'success') {
                $matched = $this->findMatchingReturn($statusRes, $refund->reference_no);
                if ($matched) {
                    return $this->markCompleted($refund, $payment, $matched, $statusRes);
                }
            }

            // STEP 2: Call official PayTR iade API
            $returnAmountFormatted = number_format($refund->refund_amount_minor / 100, 2, '.', '');
            $res = $this->paytrService->requestRefund([
                'merchant_oid' => $refund->merchant_oid,
                'return_amount' => $returnAmountFormatted,
                'reference_no' => $refund->reference_no,
            ]);

            // STEP 3: Handle Network Error / Timeout (Unknown Result)
            if (!empty($res['is_transient']) || ($res['status'] ?? '') === 'network_error') {
                Log::warning('PayTR refund request network error/timeout. Performing status inquiry reconciliation...', [
                    'refund_id' => $refund->id,
                    'reference_no' => $refund->reference_no,
                ]);

                // Query PayTR status inquiry immediately
                $reconRes = $this->paytrService->queryPaymentStatus($refund->merchant_oid);
                if (isset($reconRes['status']) && $reconRes['status'] === 'success') {
                    $matched = $this->findMatchingReturn($reconRes, $refund->reference_no);
                    if ($matched) {
                        return $this->markCompleted($refund, $payment, $matched, $reconRes);
                    }

                    // Durum sorgusu başarılı fakat işlem returns listesinde yok.
                    // Bu işlem henüz gerçekleşmemiş demektir. Transient hata fırlatıp queue backoff tetikliyoruz.
                    throw new \RuntimeException('PayTR iade isteğinde bağlantı hatası oluştu. Durum sorgulaması iadenin henüz gerçekleşmediğini teyit etti; yeniden denenecek.');
                }

                // Hem iade isteği hem durum sorgusu başarısız / timeout oldu:
                // Çift iade riskini önlemek için ASLA körlemesine tekrar gönderme! MANUAL_REVIEW'e al.
                $refund->status = PaymentRefund::STATUS_MANUAL_REVIEW;
                $refund->failure_reason = 'PayTR iade API ve durum sorgusu zaman aşımına uğradı. Çift iade riskini önlemek için işlem MANUAL_REVIEW durumuna alındı.';
                $refund->paytr_response = $res;
                $refund->save();

                return $refund;
            }

            // STEP 4: Handle Refund API Success
            if (!empty($res['success']) && ($res['status'] ?? '') === 'success') {
                $refund->status = PaymentRefund::STATUS_REQUESTED;
                $refund->requested_at = now();
                $refund->paytr_response = $res['raw'] ?? $res;
                $refund->save();

                ServiceLifecycleEvent::create([
                    'resource_type' => $payment->resource_type,
                    'resource_id' => $payment->resource_id,
                    'event_type' => ServiceLifecycleEvent::EVENT_PAYTR_REFUND_REQUESTED,
                    'actor_user_id' => $refund->created_by_user_id,
                    'metadata' => [
                        'refund_id' => $refund->id,
                        'merchant_oid' => $refund->merchant_oid,
                        'reference_no' => $refund->reference_no,
                        'amount_minor' => $refund->refund_amount_minor,
                    ],
                    'created_at' => now(),
                ]);

                // Verify via status query reconciliation to transition REQUESTED -> COMPLETED
                return $this->reconcileRefund($refund, $payment);
            }

            // STEP 5: Permanent failure from PayTR
            $refund->status = PaymentRefund::STATUS_FAILED;
            $refund->failed_at = now();
            $refund->failure_reason = $res['err_msg'] ?? 'PayTR iade işlemi reddedildi';
            $refund->paytr_response = $res['raw'] ?? $res;
            $refund->save();

            // Revert payment status if no other active refunds
            if ($payment->status === ServicePayment::STATUS_REFUNDING) {
                $hasActive = PaymentRefund::where('service_payment_id', $payment->id)
                    ->whereIn('status', [PaymentRefund::STATUS_REQUESTED, PaymentRefund::STATUS_COMPLETED])
                    ->exists();

                if (!$hasActive) {
                    $payment->status = ServicePayment::STATUS_REFUND_REQUIRED;
                    $payment->save();
                }
            }

            ServiceLifecycleEvent::create([
                'resource_type' => $payment->resource_type,
                'resource_id' => $payment->resource_id,
                'event_type' => ServiceLifecycleEvent::EVENT_PAYTR_REFUND_FAILED,
                'actor_user_id' => $refund->created_by_user_id,
                'metadata' => [
                    'refund_id' => $refund->id,
                    'merchant_oid' => $refund->merchant_oid,
                    'reference_no' => $refund->reference_no,
                    'failure_reason' => $refund->failure_reason,
                ],
                'created_at' => now(),
            ]);

            return $refund;
        });
    }

    /**
     * Reconcile refund against PayTR durum-sorgu.
     * Transitions REQUESTED -> COMPLETED if matching reference_no exists in returns.
     * If reference_no doesn't match, does NOT mark completed.
     */
    public function reconcileRefund(PaymentRefund $refund, ?ServicePayment $payment = null): PaymentRefund
    {
        $statusRes = $this->paytrService->queryPaymentStatus($refund->merchant_oid);
        if (isset($statusRes['status']) && $statusRes['status'] === 'success') {
            $matched = $this->findMatchingReturn($statusRes, $refund->reference_no);
            if ($matched) {
                $targetPayment = $payment ?: ServicePayment::find($refund->service_payment_id);
                return $this->markCompleted($refund, $targetPayment, $matched, $statusRes);
            }
        }

        return $refund;
    }

    /**
     * Mark refund as COMPLETED, update service_payment status, and notify customer.
     * Guaranteed idempotent - duplicate reconciliation will not double notify.
     */
    public function markCompleted(
        PaymentRefund $refund,
        ServicePayment $payment,
        array $matchedReturn,
        array $statusRes
    ): PaymentRefund {
        $alreadyCompleted = ($refund->status === PaymentRefund::STATUS_COMPLETED);

        $refund->status = PaymentRefund::STATUS_COMPLETED;
        $refund->completed_at = $refund->completed_at ?: now();
        $refund->paytr_response = $statusRes;
        $refund->save();

        // Calculate total completed refund amount minor
        $totalCompletedMinor = (int) PaymentRefund::where('service_payment_id', $payment->id)
            ->where('status', PaymentRefund::STATUS_COMPLETED)
            ->sum('refund_amount_minor');

        $grossMinor = $payment->getGrossAmountMinor();

        if ($totalCompletedMinor >= $grossMinor) {
            $payment->status = ServicePayment::STATUS_REFUNDED;
        } else {
            $payment->status = ServicePayment::STATUS_PARTIALLY_REFUNDED;
        }
        $payment->save();

        ServiceLifecycleEvent::create([
            'resource_type' => $payment->resource_type,
            'resource_id' => $payment->resource_id,
            'event_type' => ServiceLifecycleEvent::EVENT_PAYTR_REFUND_COMPLETED,
            'actor_user_id' => $refund->created_by_user_id,
            'metadata' => [
                'refund_id' => $refund->id,
                'merchant_oid' => $refund->merchant_oid,
                'reference_no' => $refund->reference_no,
                'amount_minor' => $refund->refund_amount_minor,
                'total_refunded_minor' => $totalCompletedMinor,
                'payment_status' => $payment->status,
            ],
            'created_at' => now(),
        ]);

        // Send PAYMENT_REFUNDED notification with idempotency key
        if (!$alreadyCompleted) {
            $amountFormatted = number_format($refund->refund_amount_minor / 100, 2, ',', '.');
            $this->notificationService->notifyUser(
                $payment->customer_user_id,
                UserNotification::TYPE_PAYMENT_REFUNDED,
                'Ödemeniz İade Edildi',
                "{$amountFormatted} TL tutarındaki ödemeniz kartınıza başarıyla iade edildi.",
                UserNotification::RESOURCE_PAYMENT_REFUND,
                $refund->id,
                '/customer',
                [
                    'refund_id' => $refund->id,
                    'service_payment_id' => $payment->id,
                    'reference_no' => $refund->reference_no,
                    'amount' => (float) ($refund->refund_amount_minor / 100),
                    'payment_status' => $payment->status,
                ],
                "PAYMENT_REFUNDED:{$refund->id}:{$payment->customer_user_id}"
            );
        }

        return $refund;
    }

    /**
     * Admin retry for FAILED or MANUAL_REVIEW refunds.
     * Keeps the SAME PaymentRefund record to prevent record duplication.
     */
    public function retryRefund(int $refundId, User $admin): PaymentRefund
    {
        return DB::transaction(function () use ($refundId, $admin) {
            $refund = PaymentRefund::where('id', $refundId)->lockForUpdate()->first();
            if (!$refund) {
                throw new UnprocessableEntityHttpException("İade kaydı bulunamadı: #{$refundId}");
            }

            if (!in_array($refund->status, [PaymentRefund::STATUS_FAILED, PaymentRefund::STATUS_MANUAL_REVIEW])) {
                throw new UnprocessableEntityHttpException("Yalnızca FAILED veya MANUAL_REVIEW durumundaki iadeler yeniden denenebilir (Mevcut durum: {$refund->status}).");
            }

            $payment = ServicePayment::where('id', $refund->service_payment_id)->lockForUpdate()->first();

            // Re-evaluate payout safety
            $payout = PayoutTransfer::where('service_payment_id', $payment->id)->first();
            if ($payout && in_array($payout->status, [PayoutTransfer::STATUS_REQUESTED, PayoutTransfer::STATUS_COMPLETED])) {
                throw new UnprocessableEntityHttpException("Hakediş transferi {$payout->status} durumunda olduğu için işlem yeniden denenemez. Önce hakediş transfer durumu çözülmelidir.");
            }

            // Reset the SAME refund record
            $refund->status = PaymentRefund::STATUS_PENDING;
            $refund->failure_reason = null;
            $refund->failed_at = null;
            $metadata = $refund->metadata ?? [];
            $metadata['retried_by_admin_user_id'] = $admin->id;
            $metadata['retried_at'] = now()->toIso8601String();
            $refund->metadata = $metadata;
            $refund->save();

            $payment->status = ServicePayment::STATUS_REFUNDING;
            $payment->save();

            DB::afterCommit(function () use ($refund) {
                ProcessPaytrRefund::dispatch($refund->id);
            });

            return $refund;
        });
    }

    /**
     * Customer safe refund summary data (zero token/secret leaks).
     */
    public function getCustomerRefundSummary(ServicePayment $payment): array
    {
        $grossMinor = $payment->getGrossAmountMinor();
        $totalRefundedMinor = $payment->getTotalRefundedMinor();
        $remainingMinor = $payment->getRemainingRefundableMinor();

        $refundItems = $payment->refunds()
            ->orderByDesc('id')
            ->get()
            ->map(function (PaymentRefund $r) {
                return [
                    'id' => $r->id,
                    'reference_no' => $r->reference_no,
                    'amount' => (float) number_format($r->refund_amount_minor / 100, 2, '.', ''),
                    'currency' => $r->currency,
                    'status' => $r->status,
                    'created_at' => $r->created_at?->toISOString(),
                    'completed_at' => $r->completed_at?->toISOString(),
                ];
            })
            ->values()
            ->all();

        $latestRefund = $payment->refunds()->orderByDesc('id')->first();
        $refundStatus = 'NONE';
        if ($latestRefund) {
            $refundStatus = match ($latestRefund->status) {
                PaymentRefund::STATUS_COMPLETED => ($payment->status === ServicePayment::STATUS_PARTIALLY_REFUNDED ? 'PARTIALLY_REFUNDED' : 'COMPLETED'),
                PaymentRefund::STATUS_FAILED => 'FAILED',
                PaymentRefund::STATUS_MANUAL_REVIEW => 'MANUAL_REVIEW',
                PaymentRefund::STATUS_REQUESTED => 'REQUESTED',
                PaymentRefund::STATUS_PENDING => 'PENDING',
                default => 'PENDING',
            };
        } elseif (in_array($payment->status, [
            ServicePayment::STATUS_REFUND_REQUIRED,
            ServicePayment::STATUS_REFUNDING,
            ServicePayment::STATUS_REFUNDED,
            ServicePayment::STATUS_PARTIALLY_REFUNDED,
        ], true)) {
            $refundStatus = match ($payment->status) {
                ServicePayment::STATUS_REFUNDED => 'COMPLETED',
                ServicePayment::STATUS_PARTIALLY_REFUNDED => 'PARTIALLY_REFUNDED',
                ServicePayment::STATUS_REFUNDING => 'REQUESTED',
                ServicePayment::STATUS_REFUND_REQUIRED => 'PENDING',
                default => 'NONE',
            };
        }

        $totalCompletedFormatted = number_format($totalRefundedMinor / 100, 2, '.', '');
        $safeStatusLabel = match ($refundStatus) {
            'PENDING' => 'İade bekleniyor',
            'REQUESTED' => 'İade işleminiz devam ediyor',
            'COMPLETED' => 'İadeniz tamamlandı',
            'PARTIALLY_REFUNDED' => "Kısmi iadeniz tamamlandı ({$totalCompletedFormatted} TL)",
            'FAILED' => 'İade işlemi tamamlanamadı. Destek ekibimiz inceleyecek.',
            'MANUAL_REVIEW' => 'İade işleminiz inceleme altında.',
            default => null,
        };

        return [
            'payment_id' => $payment->id,
            'payment_status' => $payment->status,
            'has_refund' => $refundStatus !== 'NONE',
            'gross_amount' => (float) $payment->gross_amount,
            'total_refunded_amount' => (float) $totalCompletedFormatted,
            'remaining_refundable_amount' => (float) number_format($remainingMinor / 100, 2, '.', ''),
            'is_partial' => $payment->status === ServicePayment::STATUS_PARTIALLY_REFUNDED,
            'refund_status' => $refundStatus,
            'refund_status_label' => $safeStatusLabel,
            'refunds' => $refundItems,
        ];
    }
}
