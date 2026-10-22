<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ConversationMessage extends Model
{
    use HasFactory;

    public const STATUS_SENT = 'SENT';
    public const STATUS_READ = 'READ';

    protected $fillable = [
        'conversation_id',
        'sender_user_id',
        'body',
        'status',
    ];

    protected $casts = [
        'conversation_id' => 'integer',
        'sender_user_id' => 'integer',
    ];

    public function conversation(): BelongsTo
    {
        return $this->belongsTo(Conversation::class, 'conversation_id');
    }

    public function sender(): BelongsTo
    {
        return $this->belongsTo(User::class, 'sender_user_id');
    }
}
