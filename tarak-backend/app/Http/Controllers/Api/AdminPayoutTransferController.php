<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\PayoutTransfer;
use App\Models\ServicePayment;
use App\Services\PayoutTransferService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AdminPayoutTransferController extends Controller
{
    public function __construct(
        protected PayoutTransferService $payoutTransferService
    ) {}

    /**
     * GET /api/admin/payout-transfers
     * Admin view of all payout transfers & pending candidates.
     * Full IBAN is NEVER exposed.
     */
    public function index(Request $request): JsonResponse
    {
        $statusFilter = $request->query('status');

        $query = PayoutTransfer::with(['servicePayment.provider.providerProfile', 'servicePayment.customer'])
            ->orderBy('created_at', 'desc');

        if (!empty($statusFilter)) {
            $query->where('status', strtoupper($statusFilter));
        }

        $transfers = $query->paginate(30);

        // Also fetch any TRANSFER_PENDING online payments that don't yet have a transfer record
        $pendingPayments = ServicePayment::where('status', ServicePayment::STATUS_TRANSFER_PENDING)
            ->where('gateway', 'PAYTR')
            ->whereDoesntHave('payoutTransfer')
            ->with(['provider.providerProfile', 'customer', 'gatewayAttempts'])
            ->get();

        $candidates = $pendingPayments->map(function (ServicePayment $pay) {
            $eval = $this->payoutTransferService->evaluateEligibility($pay);
            return [
                'service_payment_id' => $pay->id,
                'resource_type' => $pay->resource_type,
                'resource_id' => $pay->resource_id,
                'provider' => [
                    'id' => $pay->provider_user_id,
                    'name' => $pay->provider?->name,
                    'business_name' => $pay->provider?->providerProfile?->business_name,
                ],
                'gross_amount' => (float) $pay->gross_amount,
                'commission_amount' => (float) $pay->commission_amount,
                'provider_net_amount' => (float) $pay->provider_net_amount,
                'status' => $eval['status'],
                'eligible' => $eval['eligible'],
                'eligible_at' => $eval['eligible_at']->toISOString(),
                'reasons' => $eval['reasons'],
                'masked_iban' => $eval['payout_account']?->iban_masked ?? null,
                'masked_tax_id' => $eval['payout_account']?->tax_id_masked ?? null,
            ];
        });

        $transformedTransfers = $transfers->getCollection()->map(function (PayoutTransfer $pt) {
            return [
                'id' => $pt->id,
                'service_payment_id' => $pt->service_payment_id,
                'resource_type' => $pt->servicePayment?->resource_type,
                'resource_id' => $pt->servicePayment?->resource_id,
                'provider' => [
                    'id' => $pt->provider_user_id,
                    'name' => $pt->provider?->name,
                    'business_name' => $pt->provider?->providerProfile?->business_name,
                ],
                'merchant_oid' => $pt->merchant_oid,
                'trans_id' => $pt->trans_id,
                'gross_amount' => (float) $pt->gross_amount,
                'platform_commission' => (float) $pt->platform_commission,
                'withholding_amount' => (float) $pt->withholding_amount,
                'final_submerchant_amount' => (float) $pt->final_submerchant_amount,
                'account_holder_name' => $pt->account_holder_name_snapshot,
                'iban_masked' => $pt->iban_masked,
                'status' => $pt->status,
                'status_label' => $pt->status_label,
                'eligible_at' => $pt->eligible_at?->toISOString(),
                'requested_at' => $pt->requested_at?->toISOString(),
                'accepted_by_paytr_at' => $pt->accepted_by_paytr_at?->toISOString(),
                'completed_at' => $pt->completed_at?->toISOString(),
                'failed_at' => $pt->failed_at?->toISOString(),
                'paytr_reference' => $pt->paytr_reference,
                'failure_code' => $pt->failure_code,
                'failure_message' => $pt->failure_message,
                'created_at' => $pt->created_at?->toISOString(),
            ];
        });

        return response()->json([
            'success' => true,
            'data' => [
                'transfers' => $transformedTransfers,
                'candidates' => $candidates,
                'pagination' => [
                    'current_page' => $transfers->currentPage(),
                    'last_page' => $transfers->lastPage(),
                    'total' => $transfers->total(),
                    'per_page' => $transfers->perPage(),
                ],
            ],
        ]);
    }

    /**
     * POST /api/admin/payout-transfers/{payment}/send
     * Initiates or retries PayTR platform transfer for a specific payment.
     */
    public function send(Request $request, ServicePayment $payment): JsonResponse
    {
        $transfer = $this->payoutTransferService->sendTransfer($payment, $request->user());

        return response()->json([
            'success' => true,
            'message' => $transfer->status === PayoutTransfer::STATUS_REQUESTED
                ? 'PayTR transfer talimatı başarıyla iletildi (Sonuç callback ile bekleniyor).'
                : 'Transfer işlemi işlendi (Durum: ' . $transfer->status . ').',
            'data' => [
                'id' => $transfer->id,
                'service_payment_id' => $transfer->service_payment_id,
                'trans_id' => $transfer->trans_id,
                'status' => $transfer->status,
                'status_label' => $transfer->status_label,
                'final_submerchant_amount' => (float) $transfer->final_submerchant_amount,
                'iban_masked' => $transfer->iban_masked,
                'paytr_reference' => $transfer->paytr_reference,
                'failure_message' => $transfer->failure_message,
            ],
        ]);
    }
}
