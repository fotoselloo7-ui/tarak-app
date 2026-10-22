<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ServicePayment;
use App\Services\PaytrService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException;

class CustomerPaymentController extends Controller
{
    public function __construct(
        protected PaytrService $paytrService,
        protected \App\Services\PaytrRefundService $refundService
    ) {}

    /**
     * Which payment methods the platform can actually offer right now.
     *
     * Lets the customer UI hide the online-payment option when the gateway is
     * not configured, instead of sending the user into a 422. CASH is always
     * available and is never gated. No credential or admin detail is exposed —
     * only booleans.
     * GET /api/customer/payment-capabilities
     */
    public function capabilities(): JsonResponse
    {
        return response()->json([
            'success' => true,
            'data' => [
                'online_payment' => $this->paytrService->isConfigured(),
                'cash_payment' => true,
                'online_unavailable_reason' => $this->paytrService->isConfigured()
                    ? null
                    : 'Online ödeme şu anda kullanılamıyor. Nakit ödeme ile devam edebilirsiniz.',
            ],
        ]);
    }

    /**
     * Request PayTR iFrame token for customer's pending online payment.
     * POST /api/customer/service-payments/{payment}/paytr/token
     */
    public function createPaytrToken(Request $request, int $paymentId): JsonResponse
    {
        $user = $request->user();

        $servicePayment = ServicePayment::where('id', $paymentId)
            ->where('customer_user_id', $user->id)
            ->first();

        if (!$servicePayment) {
            return response()->json([
                'success' => false,
                'message' => 'Ödeme kaydı bulunamadı veya yetkiniz yok.',
            ], 404);
        }

        try {
            $tokenData = $this->paytrService->requestIframeToken(
                $servicePayment,
                $user,
                $request->ip()
            );

            return response()->json([
                'success' => true,
                'message' => 'PayTR ödeme tokeni başarıyla oluşturuldu.',
                'data' => $tokenData,
            ]);
        } catch (\LogicException $e) {
            return response()->json([
                'success' => false,
                'message' => $e->getMessage(),
            ], 422);
        } catch (\Symfony\Component\HttpKernel\Exception\HttpException $e) {
            return response()->json([
                'success' => false,
                'message' => $e->getMessage(),
            ], $e->getStatusCode());
        }
    }

    /**
     * Get payment status and summary for customer.
     * GET /api/customer/service-payments/{payment}/status
     */
    public function getPaymentStatus(Request $request, int $paymentId): JsonResponse
    {
        $user = $request->user();

        $servicePayment = ServicePayment::where('id', $paymentId)
            ->where('customer_user_id', $user->id)
            ->with(['latestGatewayAttempt'])
            ->first();

        if (!$servicePayment) {
            return response()->json([
                'success' => false,
                'message' => 'Ödeme kaydı bulunamadı veya yetkiniz yok.',
            ], 404);
        }

        $label = match ($servicePayment->status) {
            ServicePayment::STATUS_PENDING => 'Online ödeme bekleniyor',
            ServicePayment::STATUS_HELD => 'Ödeme alındı. Hizmet güvenli şekilde başlayabilir.',
            ServicePayment::STATUS_TRANSFER_PENDING => 'Hizmet tamamlandı. Hakediş aktarım sürecinde.',
            ServicePayment::STATUS_DISPUTED => 'Ödeme uyuşmazlık incelemesinde.',
            ServicePayment::STATUS_REFUND_REQUIRED => 'İade işlemi ödeme sağlayıcısı üzerinden bekleniyor.',
            ServicePayment::STATUS_REFUNDING => 'İade işlemi başlatıldı, banka onayı bekleniyor.',
            ServicePayment::STATUS_REFUNDED => 'Ödemenin tamamı başarıyla iade edildi.',
            ServicePayment::STATUS_PARTIALLY_REFUNDED => 'Ödemenin bir kısmı başarıyla iade edildi.',
            ServicePayment::STATUS_SETTLED => 'Hakediş aktarımı tamamlandı.',
            ServicePayment::STATUS_CANCELLED => 'Ödeme iptal edildi.',
            default => $servicePayment->status,
        };

        $refundSummary = $this->refundService->getCustomerRefundSummary($servicePayment);

        return response()->json([
            'success' => true,
            'data' => [
                'id' => $servicePayment->id,
                'resource_type' => $servicePayment->resource_type,
                'resource_id' => $servicePayment->resource_id,
                'payment_method' => $servicePayment->payment_method,
                'gross_amount' => (float) $servicePayment->gross_amount,
                'status' => $servicePayment->status,
                'status_label' => $label,
                'gateway' => $servicePayment->gateway,
                'held_at' => $servicePayment->held_at?->toISOString(),
                'transfer_pending_at' => $servicePayment->transfer_pending_at?->toISOString(),
                'settled_at' => $servicePayment->settled_at?->toISOString(),
                'latest_attempt' => $servicePayment->latestGatewayAttempt ? [
                    'merchant_oid' => $servicePayment->latestGatewayAttempt->merchant_oid,
                    'status' => $servicePayment->latestGatewayAttempt->status,
                    'failure_message' => $servicePayment->latestGatewayAttempt->failure_message,
                ] : null,
                'refund_summary' => $refundSummary,
            ],
        ]);
    }

    /**
     * Customer payment / transaction history. Reuses existing ServicePayment
     * + PaymentRefund records — no invoice/PDF engine is fabricated.
     * GET /api/customer/payments
     */
    public function history(Request $request): JsonResponse
    {
        $payments = ServicePayment::query()
            ->where('customer_user_id', $request->user()->id)
            ->latest()
            ->limit(100)
            ->get()
            ->map(function (ServicePayment $p) {
                $label = match ($p->status) {
                    ServicePayment::STATUS_PENDING => 'Ödeme bekleniyor',
                    ServicePayment::STATUS_HELD => 'Ödeme alındı',
                    ServicePayment::STATUS_TRANSFER_PENDING => 'Hakediş aktarımında',
                    ServicePayment::STATUS_SETTLED => 'Tamamlandı',
                    ServicePayment::STATUS_DISPUTED => 'Uyuşmazlık incelemesinde',
                    ServicePayment::STATUS_REFUND_REQUIRED, ServicePayment::STATUS_REFUNDING => 'İade sürecinde',
                    ServicePayment::STATUS_REFUNDED => 'İade edildi',
                    ServicePayment::STATUS_PARTIALLY_REFUNDED => 'Kısmen iade edildi',
                    ServicePayment::STATUS_CANCELLED => 'İptal edildi',
                    default => $p->status,
                };

                $ref = $p->gateway_reference;
                $maskedRef = $ref ? (strlen($ref) > 6 ? substr($ref, 0, 3) . '***' . substr($ref, -3) : $ref) : null;

                return [
                    'id' => $p->id,
                    'resource_type' => $p->resource_type,
                    'resource_id' => $p->resource_id,
                    'payment_method' => $p->payment_method,
                    'gross_amount' => (float) $p->gross_amount,
                    'status' => $p->status,
                    'status_label' => $label,
                    'reference' => $maskedRef,
                    'created_at' => $p->created_at?->toIso8601String(),
                ];
            });

        return response()->json(['success' => true, 'data' => $payments]);
    }

    /**
     * Get safe customer refund summary.
     * GET /api/customer/service-payments/{payment}/refunds
     */
    public function getRefundSummary(Request $request, int $paymentId): JsonResponse
    {
        $user = $request->user();

        $servicePayment = ServicePayment::where('id', $paymentId)
            ->where('customer_user_id', $user->id)
            ->first();

        if (!$servicePayment) {
            return response()->json([
                'success' => false,
                'message' => 'Ödeme kaydı bulunamadı veya yetkiniz yok.',
            ], 404);
        }

        $summary = $this->refundService->getCustomerRefundSummary($servicePayment);

        return response()->json([
            'success' => true,
            'data' => $summary,
        ]);
    }
}
