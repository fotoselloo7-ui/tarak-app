<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class UserPushPreference extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'push_enabled',
        'campaign_enabled',
    ];

    protected $casts = [
        'push_enabled' => 'boolean',
        'campaign_enabled' => 'boolean',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Determine if push notifications are enabled for the specified user.
     * Defaults to true if no preference record exists.
     */
    public static function isPushEnabledForUser(int $userId): bool
    {
        $pref = static::where('user_id', $userId)->first();
        return $pref ? (bool) $pref->push_enabled : true;
    }

    /** Provider discount campaigns ("bildirim reklamı"); defaults to true. */
    public static function isCampaignEnabledForUser(int $userId): bool
    {
        $pref = static::where('user_id', $userId)->first();

        return $pref ? (bool) $pref->campaign_enabled : true;
    }
}
