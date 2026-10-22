<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Conversation;
use App\Models\UserBlock;
use App\Services\ConversationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ConversationController extends Controller
{
    public function __construct(
        protected ConversationService $conversationService
    ) {}

    /**
     * List authenticated user's conversations.
     * GET /api/conversations
     */
    public function index(Request $request): JsonResponse
    {
        $conversations = $this->conversationService->getConversationsForUser($request->user());

        return response()->json([
            'success' => true,
            'data' => $conversations,
        ]);
    }

    /**
     * Get global unread message count across all conversations.
     * GET /api/conversations/unread-count
     */
    public function unreadCount(Request $request): JsonResponse
    {
        $count = $this->conversationService->getUnreadCountForUser($request->user());

        return response()->json([
            'success' => true,
            'unread_count' => $count,
        ]);
    }

    /**
     * Get or create conversation for an instant service request (Customer).
     * GET /api/customer/service-requests/{id}/conversation
     */
    public function forCustomerServiceRequest(Request $request, int|string $id): JsonResponse
    {
        $conversation = $this->conversationService->getOrCreateForServiceRequest((int) $id, $request->user());

        return response()->json([
            'success' => true,
            'data' => [
                'id' => $conversation->id,
                'conversation_id' => $conversation->id,
                'resource_type' => $conversation->resource_type,
                'resource_id' => $conversation->resource_id,
                'customer_user_id' => $conversation->customer_user_id,
                'provider_user_id' => $conversation->provider_user_id,
                'status' => $conversation->status,
                'last_message_at' => $conversation->last_message_at?->toISOString(),
            ],
        ]);
    }

    /**
     * Get or create conversation for an instant service request (Provider).
     * GET /api/provider/service-requests/{id}/conversation
     */
    public function forProviderServiceRequest(Request $request, int|string $id): JsonResponse
    {
        $conversation = $this->conversationService->getOrCreateForServiceRequest((int) $id, $request->user());

        return response()->json([
            'success' => true,
            'data' => [
                'id' => $conversation->id,
                'conversation_id' => $conversation->id,
                'resource_type' => $conversation->resource_type,
                'resource_id' => $conversation->resource_id,
                'customer_user_id' => $conversation->customer_user_id,
                'provider_user_id' => $conversation->provider_user_id,
                'status' => $conversation->status,
                'last_message_at' => $conversation->last_message_at?->toISOString(),
                'other_party' => [
                    'id' => $conversation->customer?->id,
                    'name' => $conversation->customer?->name ?? 'Müşteri',
                    'avatar_url' => $conversation->customer?->customerProfile?->avatar_url,
                    'role' => $conversation->customer?->role,
                ],
            ],
        ]);
    }

    /**
     * Get or create conversation for a scheduled appointment (Customer).
     * GET /api/customer/appointments/{id}/conversation
     */
    public function forCustomerAppointment(Request $request, int|string $id): JsonResponse
    {
        $conversation = $this->conversationService->getOrCreateForAppointment((int) $id, $request->user());

        return response()->json([
            'success' => true,
            'data' => [
                'id' => $conversation->id,
                'conversation_id' => $conversation->id,
                'resource_type' => $conversation->resource_type,
                'resource_id' => $conversation->resource_id,
                'customer_user_id' => $conversation->customer_user_id,
                'provider_user_id' => $conversation->provider_user_id,
                'status' => $conversation->status,
                'last_message_at' => $conversation->last_message_at?->toISOString(),
            ],
        ]);
    }

    /**
     * Get or create conversation for a scheduled appointment (Provider).
     * GET /api/provider/appointments/{id}/conversation
     */
    public function forProviderAppointment(Request $request, int|string $id): JsonResponse
    {
        $conversation = $this->conversationService->getOrCreateForAppointment((int) $id, $request->user());

        return response()->json([
            'success' => true,
            'data' => [
                'id' => $conversation->id,
                'conversation_id' => $conversation->id,
                'resource_type' => $conversation->resource_type,
                'resource_id' => $conversation->resource_id,
                'customer_user_id' => $conversation->customer_user_id,
                'provider_user_id' => $conversation->provider_user_id,
                'status' => $conversation->status,
                'last_message_at' => $conversation->last_message_at?->toISOString(),
            ],
        ]);
    }

    /**
     * List messages for a conversation (paginated).
     * GET /api/conversations/{conversation}/messages
     */
    public function messages(Request $request, Conversation $conversation): JsonResponse
    {
        $perPage = min(100, max(1, (int) $request->query('per_page', 30)));
        $paginator = $this->conversationService->getMessages($conversation, $request->user(), $perPage);

        return response()->json([
            'success' => true,
            'data' => $paginator->getCollection()->map(function ($message) {
                $data = $message->toArray();
                $data['body'] = \App\Support\CustomerNote::forMessage($message->body);
                return $data;
            }),
            'meta' => [
                'current_page' => $paginator->currentPage(),
                'last_page' => $paginator->lastPage(),
                'per_page' => $paginator->perPage(),
                'total' => $paginator->total(),
            ],
            'pagination' => [
                'current_page' => $paginator->currentPage(),
                'last_page' => $paginator->lastPage(),
                'per_page' => $paginator->perPage(),
                'total' => $paginator->total(),
            ],
            // Lets clients lock the composer with the same rule sendMessage enforces.
            'conversation' => $this->conversationState($conversation, (int) $request->user()->id),
        ]);
    }

    /**
     * Composer state shared by the clients. `blocked_by_me` is true only when
     * the authenticated user blocked the other party (so they can unblock);
     * being blocked is not revealed, it just makes the chat read-only.
     */
    private function conversationState(Conversation $conversation, int $userId): array
    {
        $otherId = $conversation->getOtherParticipantId($userId);

        return [
            'id' => $conversation->id,
            'status' => $conversation->status,
            'is_writable' => $conversation->isWritable() && ! ($otherId && UserBlock::existsBetween($userId, $otherId)),
            'blocked_by_me' => $otherId ? UserBlock::hasBlocked($userId, $otherId) : false,
            'other_user_id' => $otherId,
        ];
    }

    /**
     * Send a message to the conversation.
     * POST /api/conversations/{conversation}/messages
     */
    public function sendMessage(Request $request, Conversation $conversation): JsonResponse
    {
        $request->validate([
            'body' => ['required', 'string'],
        ]);

        $idempotencyKey = $request->header('X-Idempotency-Key') ?: $request->input('idempotency_key');

        $result = $this->conversationService->sendMessage(
            $conversation,
            $request->user(),
            (string) $request->input('body'),
            $idempotencyKey
        );

        $message = $result['message'];
        $statusCode = $result['is_duplicate'] ? 200 : 201;

        return response()->json([
            'success' => true,
            'data' => [
                'id' => $message->id,
                'conversation_id' => $message->conversation_id,
                'sender_user_id' => $message->sender_user_id,
                'body' => \App\Support\CustomerNote::forMessage($message->body),
                'status' => $message->status,
                'created_at' => $message->created_at?->toISOString(),
            ],
        ], $statusCode);
    }

    /**
     * Mark unread messages in conversation as read.
     * POST /api/conversations/{conversation}/read
     */
    public function markAsRead(Request $request, Conversation $conversation): JsonResponse
    {
        $affected = $this->conversationService->markAsRead($conversation, $request->user());

        return response()->json([
            'success' => true,
            'marked_count' => $affected,
            'marked_read_count' => $affected,
        ]);
    }
}
