<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AdminLog;
use App\Models\ContentReport;
use App\Models\ConversationMessage;
use App\Models\ProviderReview;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class AdminContentReportController extends Controller
{
    public const REMOVED_MESSAGE_TEXT = '[Bu mesaj kurallara aykırı bulunduğu için kaldırıldı.]';

    /**
     * Admin: list reported content.
     * GET /api/admin/content-reports
     */
    public function index(Request $request): JsonResponse
    {
        $reports = ContentReport::query()
            ->with(['reporter:id,name', 'reportedUser:id,name,role,status'])
            ->when($request->query('status'), fn ($q, $status) => $q->where('status', strtoupper((string) $status)))
            ->latest()
            ->limit(200)
            ->get()
            ->map(fn (ContentReport $r) => [
                'id' => $r->id,
                'content_type' => $r->content_type,
                'content_id' => $r->content_id,
                'reason' => $r->reason,
                'details' => $r->details,
                'content_snapshot' => $r->content_snapshot,
                'status' => $r->status,
                'admin_note' => $r->admin_note,
                'created_at' => $r->created_at?->toIso8601String(),
                'handled_at' => $r->handled_at?->toIso8601String(),
                'reporter' => ['id' => $r->reporter_user_id, 'name' => $r->reporter?->name ?? 'Kullanıcı'],
                'reported_user' => [
                    'id' => $r->reported_user_id,
                    'name' => $r->reportedUser?->name ?? 'Kullanıcı',
                    'role' => $r->reportedUser?->role,
                    'status' => $r->reportedUser?->status,
                ],
            ]);

        return response()->json(['success' => true, 'data' => $reports]);
    }

    /**
     * Admin: update a report; optionally remove the content and/or suspend the author.
     * PATCH /api/admin/content-reports/{id}
     */
    public function update(Request $request, int $id): JsonResponse
    {
        $validated = $request->validate([
            'status' => ['required', 'string', 'in:' . implode(',', [
                ContentReport::STATUS_OPEN,
                ContentReport::STATUS_REVIEWING,
                ContentReport::STATUS_ACTION_TAKEN,
                ContentReport::STATUS_DISMISSED,
            ])],
            'admin_note' => ['nullable', 'string', 'max:2000'],
            'remove_content' => ['nullable', 'boolean'],
            'suspend_user' => ['nullable', 'boolean'],
        ]);

        $report = ContentReport::query()->find($id);
        if (! $report) {
            return response()->json(['success' => false, 'message' => 'Bildirim bulunamadı.'], 404);
        }

        $removeContent = (bool) ($validated['remove_content'] ?? false);
        $suspendUser = (bool) ($validated['suspend_user'] ?? false);

        if (($removeContent || $suspendUser) && $validated['status'] !== ContentReport::STATUS_ACTION_TAKEN) {
            return response()->json([
                'success' => false,
                'message' => 'İçerik kaldırma veya hesap askıya alma için durum "İşlem yapıldı" olmalıdır.',
            ], 422);
        }

        $reportedUser = $report->reported_user_id ? User::query()->find($report->reported_user_id) : null;
        if ($suspendUser && (! $reportedUser || $reportedUser->role === User::ROLE_ADMIN)) {
            return response()->json(['success' => false, 'message' => 'Bu hesap askıya alınamaz.'], 422);
        }

        $adminId = (int) $request->user()->id;

        DB::transaction(function () use ($report, $validated, $removeContent, $suspendUser, $reportedUser, $adminId) {
            if ($removeContent) {
                if ($report->content_type === ContentReport::TYPE_MESSAGE) {
                    ConversationMessage::query()->whereKey($report->content_id)->update(['body' => self::REMOVED_MESSAGE_TEXT]);
                } else {
                    ProviderReview::query()->whereKey($report->content_id)->delete();
                }
            }

            if ($suspendUser && $reportedUser) {
                $reportedUser->update(['status' => 'suspended']);
                $reportedUser->tokens()->delete();
            }

            $report->update([
                'status' => $validated['status'],
                'admin_note' => $validated['admin_note'] ?? $report->admin_note,
                'handled_by' => $validated['status'] === ContentReport::STATUS_OPEN ? null : $adminId,
                'handled_at' => $validated['status'] === ContentReport::STATUS_OPEN ? null : now(),
            ]);

            AdminLog::logAction(
                $adminId,
                AdminLog::ACTION_CONTENT_REPORT_HANDLED,
                AdminLog::TARGET_CONTENT_REPORT,
                (int) $report->id,
                [
                    'status' => $validated['status'],
                    'content_type' => $report->content_type,
                    'removed_content' => $removeContent,
                    'suspended_user' => $suspendUser,
                ]
            );
        });

        return response()->json([
            'success' => true,
            'message' => 'Bildirim güncellendi.',
            'data' => ['id' => $report->id, 'status' => $report->fresh()->status],
        ]);
    }
}
