<?php

use App\Models\User;
use Illuminate\Support\Facades\Broadcast;

/*
|--------------------------------------------------------------------------
| Broadcast Channels
|--------------------------------------------------------------------------
|
| Private user channel: only the authenticated user matching the channel's
| userId can subscribe. Role alone is insufficient (even admins cannot
| listen to other users' private notification channels).
|
*/

Broadcast::channel('user.{userId}', function (User $user, $userId) {
    return (int) $user->id === (int) $userId;
}, ['guards' => ['sanctum', 'web']]);

Broadcast::channel('conversation.{conversationId}', function (User $user, $conversationId) {
    $conversation = \App\Models\Conversation::find($conversationId);
    if (!$conversation) {
        return false;
    }
    return $conversation->isParticipant((int) $user->id);
}, ['guards' => ['sanctum', 'web']]);

