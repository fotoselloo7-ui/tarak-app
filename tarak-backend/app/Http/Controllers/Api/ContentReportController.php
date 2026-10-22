<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ContentReport;
use App\Models\ConversationMessage;
use App\Models\ProviderReview;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ContentReportController extends Controller
{
    /**
     * Report a chat message or a review for moderation.
     * POST /api/reports
     */
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'content_type' => ['required', 'string', 'in:' . ContentReport::TYPE_MESSAGE . ',' . ContentReport::TYPE_REVIEW],
            'content_id' => ['required', 'integer', 'min:1'],
            'reason' => ['required', 'string', 'in:' . implode(',', ContentReport::REASONS)],
            'details' => ['nullable', 'string', 'max:1000'],
        ], [
            'reason.in' => 'Geçerli bir bildirim nedeni seçin.',
            'content_type.in' => 'Bu içerik türü bildirilemez.',
        ]);

        $reporterId = (int) $request->user()->id;
        $contentId = (int) $validated['content_id'];

        if ($validated['content_type'] === ContentReport::TYPE_MESSAGE) {
            $message = ConversationMessage::query()->with('conversation')->find($contentId);

            // A user may only see (and so report) messages of their own conversations;
            // a foreign or missing id looks identical to avoid leaking existence.
            if (! $message || ! $message->conversation?->isParticipant($reporterId)) {
                return response()->json(['success' => false, 'message' => 'Mesaj bulunamadı.'], 404);
            }
            if ((int) $message->sender_user_id === $reporterId) {
                return response()->json(['success' => false, 'message' => 'Kendi mesajınızı bildiremezsiniz.'], 422);
            }

            $reportedUserId = (int) $message->sender_user_id;
            $snapshot = $message->body;
        } else {
            $review = ProviderReview::query()->find($contentId);
            if (! $review) {
                return response()->json(['success' => false, 'message' => 'Değerlendirme bulunamadı.'], 404);
            }
            if ((int) $review->customer_user_id === $reporterId) {
                return response()->json(['success' => false, 'message' => 'Kendi değerlendirmenizi bildiremezsiniz.'], 422);
            }

            $reportedUserId = (int) $review->customer_user_id;
            $snapshot = trim(($review->rating ? $review->rating . '/5 ' : '') . ($review->comment ?? ''));
        }

        $existing = ContentReport::query()
            ->where('reporter_user_id', $reporterId)
            ->where('content_type', $validated['content_type'])
            ->where('content_id', $contentId)
            ->first();

        if ($existing) {
            return response()->json([
                'success' => true,
                'message' => 'Bu içeriği zaten bildirdiniz. Ekibimiz inceliyor.',
                'data' => ['id' => $existing->id, 'status' => $existing->status, 'already_reported' => true],
            ]);
        }

        $report = ContentReport::create([
            'reporter_user_id' => $reporterId,
            'reported_user_id' => $reportedUserId,
            'content_type' => $validated['content_type'],
            'content_id' => $contentId,
            'reason' => $validated['reason'],
            'details' => isset($validated['details']) ? trim($validated['details']) ?: null : null,
            'content_snapshot' => $snapshot !== '' ? $snapshot : null,
            'status' => ContentReport::STATUS_OPEN,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Bildiriminiz alındı. Ekibimiz inceleyecek.',
            'data' => ['id' => $report->id, 'status' => $report->status, 'already_reported' => false],
        ], 201);
    }
}
