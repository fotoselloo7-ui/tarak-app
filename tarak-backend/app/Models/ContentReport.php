<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ContentReport extends Model
{
    public const TYPE_MESSAGE = 'MESSAGE';
    public const TYPE_REVIEW = 'REVIEW';

    public const REASONS = ['SPAM', 'HARASSMENT', 'INAPPROPRIATE', 'FRAUD', 'OTHER'];

    public const STATUS_OPEN = 'OPEN';
    public const STATUS_REVIEWING = 'REVIEWING';
    public const STATUS_ACTION_TAKEN = 'ACTION_TAKEN';
    public const STATUS_DISMISSED = 'DISMISSED';

    protected $fillable = [
        'reporter_user_id',
        'reported_user_id',
        'content_type',
        'content_id',
        'reason',
        'details',
        'content_snapshot',
        'status',
        'handled_by',
        'admin_note',
        'handled_at',
    ];

    protected function casts(): array
    {
        return [
            'content_id' => 'integer',
            'handled_at' => 'datetime',
        ];
    }

    public function reporter(): BelongsTo
    {
        return $this->belongsTo(User::class, 'reporter_user_id');
    }

    public function reportedUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'reported_user_id');
    }
}
