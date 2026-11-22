<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\NotificationAbuseAlert;
use App\Models\NotificationDispatch;
use App\Services\NotificationAbuseGuardService;
use App\Services\NotificationReportService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Provider self-service notification report: balances (promo + cash), unit prices,
 * monthly usage, upcoming birthday count, own campaign/birthday history, and active restrictions.
 * Strictly isolated to $request->user()->id; never exposes other providers or customer birth dates.
 */
class ProviderNotificationReportController extends Controller
{
    public function __construct(
        private NotificationReportService $reports,
        private NotificationAbuseGuardService $abuseGuard,
    ) {}

    public function index(Request $request): JsonResponse
    {
        return response()->json([
            'success' => true,
            'data' => $this->reports->providerReport($request->user()),
        ]);
    }

    public function showDispatch(Request $request, int $id): JsonResponse
    {
        $dispatch = NotificationDispatch::query()->find($id);
        if (!$dispatch) {
            return response()->json(['success' => false, 'message' => 'Bildirim gönderim kaydı bulunamadı.'], 404);
        }

        if ((int) $dispatch->provider_user_id !== (int) $request->user()->id) {
            $this->abuseGuard->recordAlert(
                (int) $request->user()->id,
                NotificationAbuseAlert::TYPE_UNAUTHORIZED_PII_ACCESS,
                'Başka bir işletmenin bildirim gönderim kaydına erişim girişimi engellendi.',
                ['attempted_dispatch_id' => $dispatch->id, 'owner_provider_user_id' => $dispatch->provider_user_id],
                dispatchId: $dispatch->id,
                severity: 'HIGH',
                autoAction: 'ACCESS_DENIED_403',
            );

            return response()->json([
                'success' => false,
                'message' => 'Başka bir işletmenin bildirim kayıtlarına erişemezsiniz.',
            ], 403);
        }

        return response()->json([
            'success' => true,
            'data' => [
                'id' => $dispatch->id,
                'reference_code' => $dispatch->reference_code,
                'notification_type' => $dispatch->notification_type,
                'notification_type_label' => NotificationDispatch::TYPE_LABELS[$dispatch->notification_type] ?? $dispatch->notification_type,
                'title' => $dispatch->title,
                'body' => $dispatch->body,
                'unit_price' => (float) $dispatch->unit_price,
                'total_cost' => (float) $dispatch->total_cost,
                'captured_promo_amount' => (float) $dispatch->captured_promo_amount,
                'captured_cash_amount' => (float) $dispatch->captured_cash_amount,
                'balance_source' => $dispatch->balance_source,
                'balance_source_label' => NotificationDispatch::SOURCE_LABELS[$dispatch->balance_source] ?? $dispatch->balance_source,
                'targeted_count' => (int) $dispatch->targeted_count,
                'eligible_count' => (int) $dispatch->eligible_count,
                'attempted_count' => (int) $dispatch->attempted_count,
                'fcm_accepted_count' => (int) $dispatch->fcm_accepted_count,
                'failed_count' => (int) $dispatch->failed_count,
                'skipped_count' => (int) $dispatch->skipped_count,
                'status' => $dispatch->status,
                'status_label' => NotificationDispatch::STATUS_LABELS[$dispatch->status] ?? $dispatch->status,
                'sent_at' => $dispatch->sent_at?->toISOString(),
                'created_at' => $dispatch->created_at?->toISOString(),
            ],
        ]);
    }
}
