<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Conversation extends Model
{
    use HasFactory;

    public const STATUS_ACTIVE = 'ACTIVE';
    public const STATUS_READ_ONLY = 'READ_ONLY';
    public const STATUS_CLOSED = 'CLOSED';

    public const RESOURCE_INSTANT_REQUEST = 'INSTANT_REQUEST';
    public const RESOURCE_SCHEDULED_APPOINTMENT = 'SCHEDULED_APPOINTMENT';

    protected $fillable = [
        'resource_type',
        'resource_id',
        'customer_user_id',
        'provider_user_id',
        'status',
        'last_message_at',
    ];

    protected $casts = [
        'resource_id' => 'integer',
        'customer_user_id' => 'integer',
        'provider_user_id' => 'integer',
        'last_message_at' => 'datetime',
    ];

    protected $appends = [
        'last_message_preview',
    ];

    public function getLastMessagePreviewAttribute(): ?string
    {
        $lastMsg = $this->messages()->latest('id')->first();
        return $lastMsg ? \Illuminate\Support\Str::limit(\App\Support\CustomerNote::forMessage($lastMsg->body), 60) : null;
    }

    public function customer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'customer_user_id');
    }

    public function provider(): BelongsTo
    {
        return $this->belongsTo(User::class, 'provider_user_id');
    }

    public function messages(): HasMany
    {
        return $this->hasMany(ConversationMessage::class, 'conversation_id');
    }

    /**
     * Check if the user is an authorized participant in this conversation.
     */
    public function isParticipant(int $userId): bool
    {
        return (int) $this->customer_user_id === $userId || (int) $this->provider_user_id === $userId;
    }

    /**
     * Check if new messages can be posted to this conversation.
     */
    public function isWritable(): bool
    {
        return $this->status === self::STATUS_ACTIVE;
    }

    /**
     * Get the other participant relative to the given user ID.
     */
    public function getOtherParticipantId(int $userId): ?int
    {
        if ((int) $this->customer_user_id === $userId) {
            return (int) $this->provider_user_id;
        }
        if ((int) $this->provider_user_id === $userId) {
            return (int) $this->customer_user_id;
        }
        return null;
    }

    /**
     * Count unread messages received by the given user in this conversation.
     */
    public function unreadCountForUser(int $userId): int
    {
        return $this->messages()
            ->where('sender_user_id', '!=', $userId)
            ->where('status', ConversationMessage::STATUS_SENT)
            ->count();
    }
}
