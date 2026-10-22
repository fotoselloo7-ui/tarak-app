<?php

namespace App\Console\Commands;

use App\Models\PaymentGatewayAttempt;
use App\Models\PaymentRefund;
use App\Models\ServiceLifecycleEvent;
use App\Models\ServicePayment;
use App\Models\UserNotification;
use App\Services\NotificationService;
use App\Services\PaytrRefundService;
use App\Services\PaytrService;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class ReconcilePaymentsCommand extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'payments:reconcile {--refunds-only : Only reconcile stale refunds} {--payments-only : Only reconcile pending payments}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Reconcile in-flight PayTR payment and refund states against official gateway status inquiries';

    public function handle(
        PaytrService $paytrService,
        PaytrRefundService $refundService,
        NotificationService $notificationService
    ): int {
        $this->info('Starting payments & refunds reconciliation...');

        if (!$paytrService->isConfigured()) {
            $this->warn('PayTR is not configured. Skipping reconciliation.');
            return Command::SUCCESS;
        }

        $reconcileRefunds = !$this->option('payments-only');
        $reconcilePayments = !$this->option('refunds-only');

        if ($reconcileRefunds) {
            $this->reconcileStaleRefunds($refundService);
        }

        if ($reconcilePayments) {
            $this->reconcileStalePendingPayments($paytrService, $notificationService);
        }

        $this->info('Reconciliation completed successfully.');
        return Command::SUCCESS;
    }

    /**
     * Reconcile stale REQUESTED refunds (requested > 5 minutes ago) using official PayTR status inquiry.
     * Guaranteed no double-POST to PayTR refund API.
     */
    protected function reconcileStaleRefunds(PaytrRefundService $refundService): void
    {
        $this->line('Checking for stale REQUESTED refunds...');

        $staleRefunds = PaymentRefund::where('status', PaymentRefund::STATUS_REQUESTED)
            ->where('requested_at', '<=', now()->subMinutes(5))
            ->get();

        $count = $staleRefunds->count();
        $this->line("Found {$count} stale REQUESTED refund(s).");

        $completed = 0;
        foreach ($staleRefunds as $refund) {
            try {
                $updated = $refundService->reconcileRefund($refund);
                if ($updated->isCompleted()) {
                    $completed++;
                    $this->info("Refund #{$refund->id} (Ref: {$refund->reference_no}) successfully reconciled to COMPLETED.");
                }
            } catch (\Throwable $e) {
                Log::error("Failed to reconcile refund #{$refund->id}", [
                    'refund_id' => $refund->id,
                    'reference_no' => $refund->reference_no,
                    'error' => $e->getMessage(),
                ]);
            }
        }

        $this->line("Reconciled {$completed}/{$count} refunds to COMPLETED.");
    }

    /**
     * Reconcile stale PENDING payments (initiated between 15 minutes and 24 hours ago)
     * using official PayTR durum-sorgu API without inventing endpoints.
     */
    protected function reconcileStalePendingPayments(
        PaytrService $paytrService,
        NotificationService $notificationService
    ): void {
        $this->line('Checking for stale PENDING payments with token ready attempts...');

        $staleAttempts = PaymentGatewayAttempt::where('gateway', 'PAYTR')
            ->where('status', PaymentGatewayAttempt::STATUS_TOKEN_READY)
            ->where('created_at', '<=', now()->subMinutes(15))
            ->where('created_at', '>=', now()->subHours(24))
            ->with('servicePayment')
            ->get();

        $count = $staleAttempts->count();
        $this->line("Found {$count} pending gateway attempt(s) eligible for status check.");

        $reconciled = 0;
        foreach ($staleAttempts as $attempt) {
            $payment = $attempt->servicePayment;
            if (!$payment || $payment->status !== ServicePayment::STATUS_PENDING) {
                continue;
            }

            try {
                $statusRes = $paytrService->queryPaymentStatus($attempt->merchant_oid);

                if (isset($statusRes['status']) && $statusRes['status'] === 'success') {
                    $paytrPaymentStatus = strtolower((string) ($statusRes['payment_status'] ?? ''));

                    if ($paytrPaymentStatus === 'success') {
                        DB::transaction(function () use ($attempt, $payment, $statusRes, $notificationService) {
                            // Lock both records
                            $lockedAttempt = PaymentGatewayAttempt::where('id', $attempt->id)->lockForUpdate()->first();
                            $lockedPayment = ServicePayment::where('id', $payment->id)->lockForUpdate()->first();

                            if ($lockedPayment->status !== ServicePayment::STATUS_PENDING) {
                                return;
                            }

                            $paidAmountMinor = (int) round(((float) ($statusRes['payment_amount'] ?? $statusRes['payment_total'] ?? 0)) * 100);
                            if ($paidAmountMinor <= 0) {
                                $paidAmountMinor = $lockedAttempt->payment_amount_minor;
                            }

                            $lockedAttempt->status = PaymentGatewayAttempt::STATUS_SUCCESS;
                            $lockedAttempt->callback_received_at = now();
                            $lockedAttempt->callback_payload = $statusRes;
                            $lockedAttempt->save();

                            $lockedPayment->status = ServicePayment::STATUS_HELD;
                            $lockedPayment->held_at = now();
                            $lockedPayment->gateway = 'PAYTR';
                            $lockedPayment->gateway_reference = $attempt->merchant_oid;
                            $lockedPayment->save();

                            ServiceLifecycleEvent::create([
                                'resource_type' => $lockedPayment->resource_type,
                                'resource_id' => $lockedPayment->resource_id,
                                'event_type' => ServiceLifecycleEvent::EVENT_PAYTR_PAYMENT_SUCCESS,
                                'actor_user_id' => $lockedPayment->customer_user_id,
                                'metadata' => [
                                    'payment_id' => $lockedPayment->id,
                                    'merchant_oid' => $attempt->merchant_oid,
                                    'amount_minor' => $paidAmountMinor,
                                    'reconciled_via' => 'durum_sorgu_scheduler',
                                ],
                                'created_at' => now(),
                            ]);

                            $notificationService->notifyUser(
                                $lockedPayment->customer_user_id,
                                UserNotification::TYPE_PAYMENT_RECEIVED,
                                'Ödemeniz Alındı',
                                'Online ödemeniz başarıyla alındı ve onaylandı.',
                                UserNotification::RESOURCE_SERVICE_PAYMENT,
                                $lockedPayment->id,
                                '/customer',
                                [
                                    'payment_id' => $lockedPayment->id,
                                    'gross_amount' => (float) $lockedPayment->gross_amount,
                                ],
                                "PAYMENT_RECEIVED:{$lockedPayment->id}:{$lockedPayment->customer_user_id}"
                            );
                        });

                        $reconciled++;
                        $this->info("Payment #{$payment->id} (merchant_oid: {$attempt->merchant_oid}) successfully reconciled to HELD.");
                    } elseif (in_array($paytrPaymentStatus, ['fail', 'failed'], true)) {
                        $attempt->status = PaymentGatewayAttempt::STATUS_FAILED;
                        $attempt->failure_code = 'PAYTR_FAILED';
                        $attempt->failure_message = $statusRes['failed_reason_msg'] ?? 'Ödeme başarısız (durum sorgulama).';
                        $attempt->save();
                    }
                }
            } catch (\Throwable $e) {
                Log::error("Failed to query status for attempt {$attempt->merchant_oid}", [
                    'merchant_oid' => $attempt->merchant_oid,
                    'error' => $e->getMessage(),
                ]);
            }
        }

        $this->line("Reconciled {$reconciled} payment(s).");
    }
}
