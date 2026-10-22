<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class UserBlock extends Model
{
    protected $fillable = [
        'blocker_user_id',
        'blocked_user_id',
    ];

    public function blocker(): BelongsTo
    {
        return $this->belongsTo(User::class, 'blocker_user_id');
    }

    public function blocked(): BelongsTo
    {
        return $this->belongsTo(User::class, 'blocked_user_id');
    }

    /**
     * True when either user has blocked the other.
     */
    public static function existsBetween(int $a, int $b): bool
    {
        return static::query()
            ->where(fn ($q) => $q->where('blocker_user_id', $a)->where('blocked_user_id', $b))
            ->orWhere(fn ($q) => $q->where('blocker_user_id', $b)->where('blocked_user_id', $a))
            ->exists();
    }

    /**
     * True only when $blocker has blocked $blocked (one direction).
     */
    public static function hasBlocked(int $blocker, int $blocked): bool
    {
        return static::query()
            ->where('blocker_user_id', $blocker)
            ->where('blocked_user_id', $blocked)
            ->exists();
    }
}
