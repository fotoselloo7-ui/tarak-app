<?php

namespace App\Events;

use App\Models\UserNotification;
use App\Services\NotificationService;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class NotificationCreated implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public UserNotification $notification
    ) {}

    /**
     * Get the private channel the event should broadcast on.
     */
    public function broadcastOn(): array
    {
        return [
            new PrivateChannel('user.' . $this->notification->user_id),
        ];
    }

    /**
     * The event's broadcast name over the wire.
     */
    public function broadcastAs(): string
    {
        return 'NotificationCreated';
    }

    /**
     * Get the data to broadcast.
     * Enforces sanitization and includes only safe fields.
     */
    public function broadcastWith(): array
    {
        $metadata = is_array($this->notification->metadata) ? $this->notification->metadata : [];
        $cleanMetadata = NotificationService::sanitizeMetadata($metadata);

        return [
            'id' => $this->notification->id,
            'user_id' => $this->notification->user_id,
            'type' => $this->notification->type,
            'title' => $this->notification->title,
            'message' => $this->notification->message,
            'resource_type' => $this->notification->resource_type,
            'resource_id' => $this->notification->resource_id,
            'action_url' => $this->notification->action_url,
            'metadata' => !empty($cleanMetadata) ? $cleanMetadata : null,
            'read_at' => $this->notification->read_at?->toISOString(),
            'created_at' => $this->notification->created_at?->toISOString(),
        ];
    }
}
