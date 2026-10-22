<?php

namespace App\Events;

use App\Models\ConversationMessage;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class MessageCreated implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public ConversationMessage $message
    ) {}

    /**
     * Get the channels the event should broadcast on.
     */
    public function broadcastOn(): array
    {
        return [
            new PrivateChannel('conversation.' . $this->message->conversation_id),
        ];
    }

    /**
     * The event's broadcast name over the wire.
     */
    public function broadcastAs(): string
    {
        return 'MessageCreated';
    }

    /**
     * Get the data to broadcast.
     * Enforces strict privacy: only safe message snapshot.
     */
    public function broadcastWith(): array
    {
        return [
            'id' => $this->message->id,
            'conversation_id' => $this->message->conversation_id,
            'sender_user_id' => $this->message->sender_user_id,
            'body' => \App\Support\CustomerNote::forMessage($this->message->body),
            'status' => $this->message->status,
            'created_at' => $this->message->created_at?->toISOString(),
        ];
    }
}
