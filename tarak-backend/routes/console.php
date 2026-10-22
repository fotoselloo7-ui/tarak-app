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

