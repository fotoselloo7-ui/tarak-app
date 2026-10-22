<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * Proof that the OS cron -> `schedule:run` chain is actually alive.
 * Written by App\Console\Commands\SchedulerHeartbeatCommand every minute.
 */
class SchedulerHeartbeat extends Model
{
    protected $table = 'scheduler_heartbeats';

    public const TASK_SCHEDULER = 'scheduler';

    protected $fillable = [
        'task',
        'last_run_at',
        'last_success_at',
        'status',
        'message',
    ];

    protected function casts(): array
    {
        return [
            'last_run_at' => 'datetime',
            'last_success_at' => 'datetime',
        ];
    }

    /**
     * The scheduler is considered alive when it checked in within the last
     * 5 minutes (cron granularity is 1 minute; 5 gives headroom).
     */
    public function isAlive(): bool
    {
        return $this->last_success_at !== null
            && $this->last_success_at->greaterThan(now()->subMinutes(5));
    }
}
