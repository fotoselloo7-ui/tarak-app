<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

/*
|--------------------------------------------------------------------------
| Console Schedule Definitions
|--------------------------------------------------------------------------
| Reconcile pending in-flight payments and requested refunds every 15 minutes.
| withoutOverlapping prevents concurrent reconciliation runs.
*/
Schedule::command('payments:reconcile')->everyFifteenMinutes()->withoutOverlapping();

/*
| Scheduler heartbeat — proves to the admin Integration Center that the OS
| cron -> schedule:run chain is actually alive (not just configured in code).
*/
Schedule::command('scheduler:heartbeat')->everyMinute()->withoutOverlapping();

/*
| "Öne çıkarma" periods: the public section hides a profile the moment its period ends
| (date-based query). This job only sends the provider the "süreniz doldu" notice.
*/
Schedule::command('featured:expire')->hourly()->withoutOverlapping();

/*
| Gift commission right used up: the one-time e-mail normally goes out through the queue right after the completion;
| this hourly sweep only re-queues the ones whose mail failed (idempotent).
*/
Schedule::command('finance:notify-gift-depleted')->hourly()->withoutOverlapping();


/*
| Recover queued/scheduled admin announcements if a web request or queue
| worker died after saving the broadcast. Idempotent per user on delivery.
*/
Artisan::command('broadcasts:requeue-due', function () {
    $rows = \App\Models\AdminBroadcast::query()
        ->whereIn('status', [\App\Models\AdminBroadcast::QUEUED, \App\Models\AdminBroadcast::SENDING])
        ->where(function ($q) {
            $q->whereNull('scheduled_at')->orWhere('scheduled_at', '<=', now());
        })
        ->where(function ($q) {
            $q->whereNull('last_enqueued_at')->orWhere('last_enqueued_at', '<=', now()->subMinutes(10));
        })
        ->orderBy('id')->limit(20)->get();
    foreach ($rows as $broadcast) {
        $broadcast->update(['last_enqueued_at' => now()]);
        \App\Jobs\ProcessAdminBroadcast::dispatch($broadcast->id)->onQueue('push');
    }
    $this->info('Requeued broadcasts: ' . $rows->count());
})->purpose('Resume stalled or scheduled admin broadcast batches');

Schedule::command('broadcasts:requeue-due')->everyMinute()->withoutOverlapping();
