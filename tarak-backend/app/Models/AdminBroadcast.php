<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AdminBroadcast extends Model
{
    public const DRAFT = 'DRAFT';
    public const QUEUED = 'QUEUED';
    public const SENDING = 'SENDING';
    public const PAUSED = 'PAUSED';
    public const COMPLETED = 'COMPLETED';
    public const CANCELLED = 'CANCELLED';
    public const FAILED = 'FAILED';

    protected $fillable = [
        'created_by', 'kind', 'audience', 'province', 'district', 'title', 'body',
        'sponsor_name', 'action_url', 'status', 'scheduled_at', 'started_at',
        'finished_at', 'last_user_id', 'estimated_recipients', 'processed_recipients',
        'notifications_created', 'last_enqueued_at', 'failure_message',
    ];

    protected function casts(): array
    {
        return [
            'scheduled_at' => 'datetime',
            'started_at' => 'datetime',
            'finished_at' => 'datetime',
            'last_enqueued_at' => 'datetime',
            'estimated_recipients' => 'integer',
            'processed_recipients' => 'integer',
            'notifications_created' => 'integer',
            'last_user_id' => 'integer',
        ];
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }
}
