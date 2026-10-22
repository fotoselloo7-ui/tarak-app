<?php

namespace App\Services;

use App\Events\MessageCreated;
use App\Models\Appointment;
use App\Models\Conversation;
use App\Models\ConversationMessage;
use App\Models\ServiceRequest;
use App\Models\User;
use Illuminate\Pagination\LengthAwarePaginator;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;
use Symfony\Component\HttpKernel\Exception\UnprocessableEntityHttpException;

class ConversationService
{
    public function __construct(
        protected MessageContentPolicyService $contentPolicyService,
        protected NotificationService $notificationService
    ) {}

    /**
     * Get or create a conversation for an instant service request.
     *
     * @param ServiceRequest|int $serviceRequest
     * @param User|int $user
     */
    public function getOrCreateForServiceRequest($serviceRequest, $user): Conversation
    {
        $request = $serviceRequest instanceof ServiceRequest ? $serviceRequest : ServiceRequest::find($serviceRequest);
        if (!$request) {
            throw new NotFoundHttpException('Hizmet talebi bulunamadı.');
        }

        $userId = $user instanceof User ? (int) $user->id : (int) $user;

        // Must be customer or assigned provider
        $isCustomer = (int) $request->customer_user_id === $userId;
        $isAssignedProvider = $request->assigned_provider_user_id !== null && (int) $request->assigned_provider_user_id === $userId;

        if (!$isCustomer && !$isAssignedProvider) {
            throw new AccessDeniedHttpException('Bu hizmet talebinin sohbetine erişim yetkiniz bulunmamaktadır.');
        }

        // Open status: No provider assigned yet -> Chat is not allowed
        if ($request->status === 'OPEN' || $request->assigned_provider_user_id === null) {
            throw new UnprocessableEntityHttpException('Talep açık durumdayken sohbet başlatılamaz. Bir uzman atandıktan sonra sohbet açılacaktır.');
        }

        return DB::transaction(function () use ($request) {
            $conversation = Conversation::firstOrCreate(
                [
                    'resource_type' => Conversation::RESOURCE_INSTANT_REQUEST,
                    'resource_id' => $request->id,
                ],
                [
                    'customer_user_id' => $request->customer_user_id,
                    'provider_user_id' => $request->assigned_provider_user_id,
                    'status' => Conversation::STATUS_ACTIVE,
                ]
            );

            // Re-sync status based on resource lifecycle
            $this->syncConversationStatusForInstantRequest($conversation, $request);

            return $conversation;
        });
    }

    /**
     * Get or create a conversation for a scheduled appointment.
     *
     * @param Appointment|int $appointment
     * @param User|int $user
     */
    public function getOrCreateForAppointment($appointment, $user): Conversation
    {
        $appointmentModel = $appointment instanceof Appointment ? $appointment : Appointment::find($appointment);
        if (!$appointmentModel) {
            throw new NotFoundHttpException('Randevu bulunamadı.');
        }

        $userId = $user instanceof User ? (int) $user->id : (int) $user;

        // Must be customer or appointment provider
        $isCustomer = (int) $appointmentModel->customer_user_id === $userId;
        $isProvider = (int) $appointmentModel->provider_user_id === $userId;

        if (!$isCustomer && !$isProvider) {
            throw new AccessDeniedHttpException('Bu randevunun sohbetine erişim yetkiniz bulunmamaktadır.');
        }

        // Pending status: Provider has not confirmed yet -> Chat is not allowed
        if ($appointmentModel->status === 'PENDING') {
            throw new UnprocessableEntityHttpException('Randevu henüz onaylanmamıştır. Randevu onaylandıktan sonra sohbet açılacaktır.');
        }

        return DB::transaction(function () use ($appointmentModel) {
            $conversation = Conversation::firstOrCreate(
                [
                    'resource_type' => Conversation::RESOURCE_SCHEDULED_APPOINTMENT,
                    'resource_id' => $appointmentModel->id,
                ],
                [
                    'customer_user_id' => $appointmentModel->customer_user_id,
                    'provider_user_id' => $appointmentModel->provider_user_id,
                    'status' => Conversation::STATUS_ACTIVE,
                ]
            );

            // Re-sync status based on appointment lifecycle
            $this->syncConversationStatusForAppointment($conversation, $appointmentModel);

            return $conversation;
        });
    }

    /**
     * List conversations for the authenticated user.
     */
    public function getConversationsForUser(User $user): array
    {
        $userId = (int) $user->id;

        $conversations = Conversation::where(function ($q) use ($userId) {
            $q->where('customer_user_id', $userId)
              ->orWhere('provider_user_id', $userId);
        })
        ->with([
            'customer:id,name,role',
            'customer.customerProfile:id,user_id,avatar_url',
            'provider:id,name,role',
            'provider.providerProfile:id,user_id,cover_url,is_approved,identity_status',
            'provider.providerProfile.documents:id,provider_profile_id,document_type,status',
            'messages' => function ($q) {
                $q->latest()->limit(1);
            },
        ])
        ->withCount([
            'messages as unread_messages_count' => function ($q) use ($userId) {
                $q->where('sender_user_id', '!=', $userId)
                  ->where('status', \App\Models\ConversationMessage::STATUS_SENT);
            },
        ])
        ->orderByDesc('last_message_at')
        ->orderByDesc('updated_at')
        ->get();

        $blockedByMe = \App\Models\UserBlock::query()
            ->where('blocker_user_id', $userId)
            ->pluck('blocked_user_id')
            ->map(fn ($id) => (int) $id)
            ->all();
        $blockedMe = \App\Models\UserBlock::query()
            ->where('blocked_user_id', $userId)
            ->pluck('blocker_user_id')
            ->map(fn ($id) => (int) $id)
            ->all();

        return $conversations->map(function (Conversation $conv) use ($userId, $blockedByMe, $blockedMe) {
            $isCustomer = (int) $conv->customer_user_id === $userId;
            $otherUser = $isCustomer ? $conv->provider : $conv->customer;

            $otherProfile = $isCustomer
                ? $otherUser?->providerProfile
                : $otherUser?->customerProfile;

            $otherAvatar = $isCustomer
                ? ($otherProfile?->cover_url ?? null)
                : ($otherProfile?->avatar_url ?? null);

            $lastMsg = $conv->messages->first();
            $unreadCount = (int) ($conv->unread_messages_count ?? $conv->unreadCountForUser($userId));
            $otherId = (int) ($otherUser?->id ?? 0);
            $iBlocked = in_array($otherId, $blockedByMe, true);
            $blockedEitherWay = $iBlocked || in_array($otherId, $blockedMe, true);

            return [
                'id' => $conv->id,
                'conversation_id' => $conv->id,
                'resource_type' => $conv->resource_type,
                'resource_id' => $conv->resource_id,
                'customer_user_id' => $conv->customer_user_id,
                'provider_user_id' => $conv->provider_user_id,
                'status' => $conv->status,
                // True only when the authenticated user blocked the other party.
                // Whether the other party blocked us is deliberately not revealed.
                'is_blocked' => $iBlocked,
                'is_writable' => $conv->isWritable() && ! $blockedEitherWay,
                'last_message_at' => $conv->last_message_at?->toISOString(),
                'last_message_preview' => $lastMsg ? Str::limit(\App\Support\CustomerNote::forMessage($lastMsg->body), 60) : null,
                'unread_count' => $unreadCount,
                'other_party' => [
                    'id' => $otherUser?->id,
                    'name' => $otherUser?->name ?? 'Kullanıcı',
                    'avatar_url' => $otherAvatar,
                    'role' => $otherUser?->role,
                    'is_verified' => $isCustomer ? (bool) ($otherProfile?->isVerified() ?? false) : false,
                ],
            ];
        })->toArray();
    }

    /**
     * Get global unread message count for a user across all their conversations.
     */
    public function getUnreadCountForUser(User $user): int
    {
        $userId = (int) $user->id;

        return ConversationMessage::whereHas('conversation', function ($q) use ($userId) {
            $q->where('customer_user_id', $userId)
              ->orWhere('provider_user_id', $userId);
        })
        ->where('sender_user_id', '!=', $userId)
        ->where('status', ConversationMessage::STATUS_SENT)
        ->count();
    }

    /**
     * Get paginated messages for a conversation.
     */
    public function getMessages(Conversation $conversation, User $user, int $perPage = 30): LengthAwarePaginator
    {
        if (!$conversation->isParticipant((int) $user->id)) {
            throw new AccessDeniedHttpException('Bu sohbete erişim yetkiniz bulunmamaktadır.');
        }

        return $conversation->messages()
            ->orderBy('created_at', 'asc')
            ->orderBy('id', 'asc')
            ->paginate($perPage);
    }

    /**
     * Send a new message to the conversation.
     *
     * @param Conversation $conversation
     * @param User|int $sender
     * @param string $rawBody
     * @param string|null $idempotencyKey
     * @return array{message: ConversationMessage, is_duplicate: bool}
     */
    public function sendMessage(Conversation $conversation, $sender, string $rawBody, ?string $idempotencyKey = null): array
    {
        $senderModel = $sender instanceof User ? $sender : User::findOrFail($sender);
        $senderId = (int) $senderModel->id;

        // 1. Participant check
        if (!$conversation->isParticipant($senderId)) {
            throw new AccessDeniedHttpException('Bu sohbete mesaj gönderme yetkiniz bulunmamaktadır.');
        }

        // 1b. Block check: either side blocking the other closes the chat.
        $otherId = $conversation->getOtherParticipantId($senderId);
        if ($otherId && \App\Models\UserBlock::existsBetween($senderId, $otherId)) {
            throw new AccessDeniedHttpException(
                \App\Models\UserBlock::hasBlocked($senderId, $otherId)
                    ? 'Bu kullanıcıyı engellediniz. Mesaj göndermek için önce engeli kaldırın.'
                    : 'Bu kullanıcıya şu anda mesaj gönderemezsiniz.'
            );
        }

        // 2. Writable status check
        if (!$conversation->isWritable()) {
            throw new UnprocessableEntityHttpException('Bu sohbet yeni mesaj gönderimine kapatılmıştır.');
        }

        // 3. Message validation & length
        $cleanBody = strip_tags(trim($rawBody));
        $maxLen = (int) config('chat.max_message_length', 2000);

        if ($cleanBody === '') {
            throw new UnprocessableEntityHttpException('Mesaj metni boş olamaz.');
        }

        if (mb_strlen($cleanBody) > $maxLen) {
            throw new UnprocessableEntityHttpException("Mesaj en fazla {$maxLen} karakter olabilir.");
        }

        // 4. Content policy anti-bypass check
        $this->contentPolicyService->validateContent($cleanBody);

        // 5. Idempotency guard
        if ($idempotencyKey) {
            $cacheKey = "conv_msg_idem:{$idempotencyKey}";
            $existingMessageId = Cache::get($cacheKey);
            if ($existingMessageId) {
                $existingMessage = ConversationMessage::find($existingMessageId);
                if ($existingMessage) {
                    return [
                        'message' => $existingMessage,
                        'is_duplicate' => true,
                    ];
                }
            }
        }

        // 6. Atomic database transaction
        $message = DB::transaction(function () use ($conversation, $senderModel, $cleanBody) {
            $msg = ConversationMessage::create([
                'conversation_id' => $conversation->id,
                'sender_user_id' => $senderModel->id,
                'body' => $cleanBody,
                'status' => ConversationMessage::STATUS_SENT,
            ]);

            $conversation->update([
                'last_message_at' => now(),
            ]);

            $recipientId = $conversation->getOtherParticipantId((int) $senderModel->id);

            // After transaction commit: Realtime broadcast + in-app notification
            DB::afterCommit(function () use ($msg, $conversation, $senderModel, $recipientId, $cleanBody) {
                try {
                    // 1. Broadcast MessageCreated on private-conversation.{id}
                    event(new MessageCreated($msg));
                } catch (\Throwable $e) {
                    Log::warning('Realtime MessageCreated broadcast failed: ' . $e->getMessage(), [
                        'message_id' => $msg->id,
                        'conversation_id' => $conversation->id,
                    ]);
                }

                // 2. Dispatch MESSAGE_RECEIVED notification to recipient (never sender)
                if ($recipientId !== null) {
                    try {
                        $recipient = User::find($recipientId);
                        if ($recipient) {
                            $previewSnippet = Str::limit(\App\Support\CustomerNote::forMessage($cleanBody), 60);
                            $senderName = $senderModel->name ?: 'Kullanıcı';

                            $this->notificationService->notifyUser(
                                $recipient,
                                'MESSAGE_RECEIVED',
                                'Yeni Mesaj',
                                "{$senderName}: {$previewSnippet}",
                                'CONVERSATION',
                                $conversation->id,
                                "/messages?id={$conversation->id}",
                                [
                                    'conversation_id' => $conversation->id,
                                    'sender_id' => $senderModel->id,
                                ],
                                "MESSAGE_RECEIVED:{$msg->id}:{$recipientId}"
                            );
                        }
                    } catch (\Throwable $e) {
                        Log::warning('Notification MESSAGE_RECEIVED delivery failed: ' . $e->getMessage(), [
                            'message_id' => $msg->id,
                            'recipient_id' => $recipientId,
                        ]);
                    }
                }
            });

            return $msg;
        });

        if ($idempotencyKey) {
            Cache::put("conv_msg_idem:{$idempotencyKey}", $message->id, now()->addHours(24));
        }

        return [
            'message' => $message,
            'is_duplicate' => false,
        ];
    }

    /**
     * Mark unread messages in a conversation as READ for the recipient.
     */
    public function markAsRead(Conversation $conversation, User $user): int
    {
        $userId = (int) $user->id;

        if (!$conversation->isParticipant($userId)) {
            throw new AccessDeniedHttpException('Bu sohbete erişim yetkiniz bulunmamaktadır.');
        }

        // Only mark messages sent by the other party
        return $conversation->messages()
            ->where('sender_user_id', '!=', $userId)
            ->where('status', ConversationMessage::STATUS_SENT)
            ->update([
                'status' => ConversationMessage::STATUS_READ,
                'updated_at' => now(),
            ]);
    }

    /**
     * Sync conversation status for an instant service request based on lifecycle.
     */
    protected function syncConversationStatusForInstantRequest(Conversation $conversation, ServiceRequest $request): void
    {
        if ($request->status === 'CANCELLED') {
            if ($conversation->status !== Conversation::STATUS_READ_ONLY) {
                $conversation->update(['status' => Conversation::STATUS_READ_ONLY]);
            }
            return;
        }

        if ($request->status === 'COMPLETED') {
            $hoursLimit = (int) config('chat.after_completion_hours', 72);
            $completedTime = $request->updated_at;
            if ($completedTime && now()->diffInHours($completedTime) > $hoursLimit) {
                if ($conversation->status !== Conversation::STATUS_READ_ONLY) {
                    $conversation->update(['status' => Conversation::STATUS_READ_ONLY]);
                }
            }
        }
    }

    /**
     * Sync conversation status for a scheduled appointment based on lifecycle.
     */
    protected function syncConversationStatusForAppointment(Conversation $conversation, Appointment $appointment): void
    {
        if (in_array($appointment->status, ['CANCELLED', 'REJECTED'], true)) {
            if ($conversation->status !== Conversation::STATUS_READ_ONLY) {
                $conversation->update(['status' => Conversation::STATUS_READ_ONLY]);
            }
            return;
        }

        if ($appointment->status === 'COMPLETED') {
            $hoursLimit = (int) config('chat.after_completion_hours', 72);
            $completedTime = $appointment->updated_at;
            if ($completedTime && now()->diffInHours($completedTime) > $hoursLimit) {
                if ($conversation->status !== Conversation::STATUS_READ_ONLY) {
                    $conversation->update(['status' => Conversation::STATUS_READ_ONLY]);
                }
            }
        }
    }
}
