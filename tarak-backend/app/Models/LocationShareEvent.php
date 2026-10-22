<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class LocationShareEvent extends Model
{
    use HasFactory;

    public $timestamps = false;

    public const EVENT_SHARED = 'LOCATION_SHARED';
    public const EVENT_REVOKED = 'LOCATION_REVOKED';
    public const EVENT_EXPIRED = 'LOCATION_EXPIRED';

    protected $fillable = [
        'location_share_grant_id',
        'event_type',
        'actor_user_id',
        'created_at',
    ];

    protected function casts(): array
    {
        return [
            'created_at' => 'datetime',
        ];
    }

    public function grant(): BelongsTo
    {
        return $this->belongsTo(LocationShareGrant::class, 'location_share_grant_id');
    }

    public function actor(): BelongsTo
    {
        return $this->belongsTo(User::class, 'actor_user_id');
    }
}
