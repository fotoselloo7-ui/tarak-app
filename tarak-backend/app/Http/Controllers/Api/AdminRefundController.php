<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\PaymentRefund;
use App\Models\ServicePayment;
use App\Services\PaytrRefundService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Symfony\Component\HttpKernel\Exception\HttpException;

class AdminRefundController extends Controller
{
    public function __construct(
        protected PaytrRefundService $refundService
    ) {}

    /**
     * GET /api/admin/refunds
     * List all refunds with status filters.
     */
    public function index(Request $request): JsonResponse
    {
        $status = $request->query('status');
        $query = PaymentRefund::with(['servicePayment.customer', 'servicePayment.provider', 'disputeCase'])
            ->orderByDesc('id');

        if (!empty($status)) {
            $query->where('status', strtoupper($status));
        }

        $refunds = $query->paginate(25);

        return response()->json([
            'success' => true,
            'data' => $refunds,
        ]);
    }

    /**
     * GET /api/admin/refunds/{id}
     * Refund details for admin audit.
     */
    public function show(string|int $id): JsonResponse
    {
        $cleanId = is_numeric($id) ? (int) $id : (int) preg_replace('/[^0-9]/', '', (string) $id);
        $refund = PaymentRefund::with(['servicePayment.customer', 'servicePayment.provider', 'disputeCase', 'createdByUser'])
            ->find($cleanId);

        if (!$refund) {
            return response()->json([
                'success' => false,
                'message' => 'İade kaydı bulunamadı.',
            ], 404);
        }

        return response()->json([
            'success' => true,
            'data' => $refund,
        ]);
    }

    /**
     * POST /api/admin/refunds/{id}/retry
     * Admin retry for a FAILED or MANUAL_REVIEW refund.
     */
    public function retry(Request $request, string|int $id): JsonResponse
    {
        $admin = $request->user();
        $cleanId = is_numeric($id) ? (int) $id : (int) preg_replace('/[^0-9]/', '', (string) $id);

        try {
            $refund = $this->refundService->retryRefund($cleanId, $admin);

            return response()->json([
                'success' => true,
                'message' => 'İade işlemi başarıyla yeniden başlatıldı.',
                'data' => $refund,
            ]);
        } catch (HttpException $e) {
            return response()->json([
                'success' => false,
                'message' => $e->getMessage(),
            ], $e->getStatusCode());
        } catch (\Throwable $e) {
            return response()->json([
                'success' => false,
                'message' => 'İade yenilenirken hata oluştu: ' . $e->getMessage(),
            ], 500);
        }
    }

    /**
     * POST /api/admin/service-payments/{payment}/refund
     * Admin manually triggers full or partial refund on an online payment.
     */
    public function triggerRefund(Request $request, int $paymentId): JsonResponse
    {
        $admin = $request->user();
        $validated = $request->validate([
            'amount' => 'nullable|numeric|min:0.01',
            'amount_minor' => 'nullable|integer|min:1',
            'reason' => 'nullable|string|max:255',
        ]);

        $payment = ServicePayment::find($paymentId);
        if (!$payment) {
            return response()->json([
                'success' => false,
                'message' => 'Ödeme kaydı bulunamadı.',
            ], 404);
        }

        $amountMinor = null;
        if (!empty($validated['amount_minor'])) {
            $amountMinor = (int) $validated['amount_minor'];
        } elseif (!empty($validated['amount'])) {
            $amountMinor = \App\Services\FinancialService::parseToCents($validated['amount']);
        }

        try {
            $refund = $this->refundService->createRefund($payment, $amountMinor, null, $admin);

            return response()->json([
                'success' => true,
                'message' => 'İade talebi başarıyla oluşturuldu ve işleme alındı.',
                'data' => $refund,
            ]);
        } catch (HttpException $e) {
            return response()->json([
                'success' => false,
                'message' => $e->getMessage(),
            ], $e->getStatusCode());
        } catch (\Throwable $e) {
            return response()->json([
                'success' => false,
                'message' => 'İade başlatılamadı: ' . $e->getMessage(),
            ], 500);
        }
    }
}
