<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\IntegrationEvent;
use App\Services\PaytrService;
use Illuminate\Http\Request;
use Illuminate\Http\Response;

class PaytrWebhookController extends Controller
{
    public function __construct(
        protected PaytrService $paytrService,
        protected \App\Services\PayoutTransferService $payoutTransferService
    ) {}

    /**
     * Handle incoming PayTR server-to-server callback notification for payments.
     * POST /api/payments/paytr/callback
     * Must return plain text "OK" on success.
     */
    public function handleCallback(Request $request): Response
    {
        $payload = $request->all();

        $result = $this->paytrService->handleCallback($payload);

        // Observability only — payment semantics above are untouched, and the
        // raw payload (hash/token) is deliberately never persisted here.
        $this->recordCallbackEvent('payment_callback', $payload, $result);

        if ($result === 'OK') {
            return response('OK', 200, [
                'Content-Type' => 'text/plain; charset=utf-8',
            ]);
        }

        return response($result, 400, [
            'Content-Type' => 'text/plain; charset=utf-8',
        ]);
    }

    /**
     * Handle incoming PayTR Platform Transfer result notification callback.
     * POST /api/payments/paytr/platform-transfer/callback
     * Must return plain text "OK" on success.
     */
    public function handleTransferCallback(Request $request): Response
    {
        $payload = $request->all();

        $result = $this->payoutTransferService->handleTransferResultCallback($payload);

        $this->recordCallbackEvent('transfer_callback', $payload, $result);

        if ($result === 'OK') {
            return response('OK', 200, [
                'Content-Type' => 'text/plain; charset=utf-8',
            ]);
        }

        return response($result, 400, [
            'Content-Type' => 'text/plain; charset=utf-8',
        ]);
    }

    /**
     * Writes a safe observability record for an inbound PayTR callback.
     * Only the merchant reference and the handler outcome are stored — never
     * the hash, token or any other field of the raw payload.
     */
    private function recordCallbackEvent(string $eventType, array $payload, string $result): void
    {
        try {
            $reference = $payload['merchant_oid'] ?? $payload['trans_id'] ?? null;
            $ok = $result === 'OK';

            IntegrationEvent::record(
                integration: 'paytr',
                eventType: $eventType,
                direction: 'inbound',
                status: $ok ? IntegrationEvent::STATUS_SUCCESS : IntegrationEvent::STATUS_FAILED,
                reference: $reference ? (string) $reference : null,
                httpStatus: $ok ? 200 : 400,
                errorCode: $ok ? null : 'HANDLER_REJECTED',
                errorMessage: $ok ? null : $result,
            );
        } catch (\Throwable) {
            // Observability must never break a payment callback.
        }
    }
}
