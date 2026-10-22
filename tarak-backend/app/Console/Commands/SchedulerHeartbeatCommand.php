<?php

namespace App\Console\Commands;

use App\Models\SchedulerHeartbeat;
use Illuminate\Console\Command;

/**
 * Minimal proof-of-life for the OS cron -> `schedule:run` chain.
 *
 * Without this, "scheduler configured" can only ever be guessed from code;
 * with it the admin panel can state whether cron is ACTUALLY running.
 */
class SchedulerHeartbeatCommand extends Command
{
    protected $signature = 'scheduler:heartbeat';

    protected $description = 'Records a scheduler heartbeat so the admin panel can prove cron is alive';

    public function handle(): int
    {
        SchedulerHeartbeat::updateOrCreate(
            ['task' => SchedulerHeartbeat::TASK_SCHEDULER],
            [
                'last_run_at' => now(),
                'last_success_at' => now(),
                'status' => 'ok',
                'message' => null,
            ],
        );

        return self::SUCCESS;
    }
}
