<?php

namespace App\Jobs;

use App\Models\NotificationAd;
use App\Services\NotificationAdService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

/** Sends a paid "bildirim reklamı" to its audience (in chunks; a retry never notifies anyone twice). */
class DeliverNotificationAd implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $tries = 3;

    public int $timeout = 900;

    public function __construct(public int $notificationAdId)
    {
        $this->onQueue('push');
    }

    public function handle(NotificationAdService $service): void
    {
        $ad = NotificationAd::find($this->notificationAdId);
        if ($ad) {
            $service->deliver($ad);
        }
    }

    public function failed(?\Throwable $exception): void
    {
        Log::error('DeliverNotificationAd failed', ['notification_ad_id' => $this->notificationAdId, 'error' => $exception?->getMessage()]);
        NotificationAd::query()->whereKey($this->notificationAdId)->where('status', NotificationAd::STATUS_QUEUED)
            ->update(['status' => NotificationAd::STATUS_FAILED, 'failure_message' => 'Gönderim tamamlanamadı.']);
    }
}
