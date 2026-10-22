<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\UserNotification;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class NotificationController extends Controller
{
    /**
     * GET /api/notifications
     * List authenticated user's notifications with pagination and filters.
     */
    public function index(Request $request): JsonResponse
    {
        $user = $request->user();
        $query = UserNotification::where('user_id', $user->id);

        // Filter unread
        if ($request->has('unread')) {
            $unreadVal = $request->query('unread');
            $isUnread = filter_var($unreadVal, FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);
            if ($isUnread === true || $unreadVal === '1') {
                $query->unread();
            } elseif ($isUnread === false || $unreadVal === '0') {
                $query->whereNotNull('read_at');
            }
        }

        // Filter type
        if ($request->filled('type')) {
            $query->where('type', strtoupper(trim((string) $request->query('type'))));
        }

        // Always newest first
        $query->orderByDesc('created_at')->orderByDesc('id');

        $perPage = min(max((int) $request->query('per_page', 15), 1), 100);
        $paginator = $query->paginate($perPage);

        return response()->json([
            'success' => true,
            'data' => $paginator->getCollection()->map(function ($notification) {
                $data = $notification->toArray();
                $data['message'] = \App\Support\CustomerNote::forNotification($notification->message);
                return $data;
            }),
            'meta' => [
                'current_page' => $paginator->currentPage(),
                'last_page' => $paginator->lastPage(),
                'per_page' => $paginator->perPage(),
                'total' => $paginator->total(),
            ],
        ]);
    }

    /**
     * GET /api/notifications/unread-count
     * Server source of truth for badge counters.
     */
    public function unreadCount(Request $request): JsonResponse
    {
        $count = UserNotification::where('user_id', $request->user()->id)
            ->unread()
            ->count();

        return response()->json([
            'count' => $count,
        ]);
    }

    /**
     * POST /api/notifications/{id}/read
     * Mark a single notification as read. Idempotent and user-scoped.
     */
    public function markOneRead(Request $request, $id): JsonResponse
    {
        $user = $request->user();
        $notification = UserNotification::find($id);

        if (!$notification) {
            return response()->json([
                'success' => false,
                'message' => 'Bildirim bulunamadı.',
            ], 404);
        }

        if ((int) $notification->user_id !== (int) $user->id) {
            return response()->json([
                'success' => false,
                'message' => 'Bu bildirimi okuma yetkiniz bulunmuyor.',
            ], 403);
        }

        $notification->markAsRead();

        return response()->json([
            'success' => true,
            'message' => 'Bildirim okundu olarak işaretlendi.',
            'data' => $notification->fresh(),
        ]);
    }

    /**
     * POST /api/notifications/read-all
     * Mark all unread notifications of the authenticated user as read.
     */
    public function markAllRead(Request $request): JsonResponse
    {
        $user = $request->user();

        $updated = UserNotification::where('user_id', $user->id)
            ->unread()
            ->update([
                'read_at' => now(),
            ]);

        return response()->json([
            'success' => true,
            'message' => 'Tüm bildirimler okundu olarak işaretlendi.',
            'updated_count' => $updated,
        ]);
    }
}
