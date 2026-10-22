<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SupportTicket extends Model
{
    public const STATUS_OPEN = 'OPEN';
    public const STATUS_IN_PROGRESS = 'IN_PROGRESS';
    public const STATUS_RESOLVED = 'RESOLVED';
    public const STATUS_CLOSED = 'CLOSED';

    protected $fillable = [
        'user_id',
        'name',
        'email',
        'category',
        'subject',
        'message',
        'status',
        'handled_by',
        'admin_note',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
