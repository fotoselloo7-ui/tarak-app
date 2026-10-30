<?php

namespace App\Jobs;

use App\Models\PushDeliveryAttempt;
use App\Models\PushDevice;
use App\Models\UserNotification;
use App\Models\UserPushPreference;
use App\Services\FcmPushService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

class SendPushNotification implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $tries = 3;

    public array $backoff = [10, 30, 60];

    public int $userNotificationId;

    /**
     * Create a new job instance.
     */
    public function __construct(int $userNotificationId)
    {
        $this->userNotificationId = $userNotificationId;
        $this->onQueue('push');
    }

    /**
     * Execute the job.
     */
    public function handle(FcmPushService $fcmService): void
    {
        $notification = UserNotification::find($this->userNotificationId);
        if (!$notification) {
            return;
        }

        // Re-check the same eligibility after queue delays, cancellations or provider moves.
        if ($notification->type === UserNotification::TYPE_INSTANT_OPPORTUNITY) {
            $request = \App\Models\ServiceRequest::find($notification->resource_id);
            $provider = $notification->user;
            if (!$request || !$provider || !app(\App\Services\InstantMatchingService::class)
                ->isProviderEligibleForRequest($provider, $request)['eligible']) return;
        }

        // Verify recipient push preferences
        if (!UserPushPreference::isPushEnabledForUser($notification->user_id)) {
            return;
        }

        // A customer may revoke marketing consent between campaign creation and
        // queue delivery. Re-check at actual push-send time as well.
        if (in_array($notification->type, [
            UserNotification::TYPE_PROVIDER_CAMPAIGN,
            UserNotification::TYPE_ADMIN_CAMPAIGN,
        ], true) && !UserPushPreference::isCampaignEnabledForUser($notification->user_id)) {
            return;
        }

        // Fetch recipient's active mobile devices
        $devices = PushDevice::where('user_id', $notification->user_id)
            ->active()
            ->get();

        if ($devices->isEmpty()) {
            return;
        }

        // If FCM is not enabled or credentials are missing in local dev, gracefully skip
        if (!$fcmService->isConfigured()) {
            Log::info('FCM is not configured, skipping push job delivery.', [
                'notification_id' => $notification->id,
                'user_id' => $notification->user_id,
            ]);
            return;
        }

        $transientErrors = [];

        foreach ($devices as $device) {
            // Check or create delivery attempt record to enforce idempotency
            $attempt = PushDeliveryAttempt::firstOrCreate(
                [
                    'user_notification_id' => $notification->id,
                    'push_device_id' => $device->id,
                ],
                [
                    'status' => PushDeliveryAttempt::STATUS_PENDING,
                    'attempt_count' => 1,
                ]
            );

            // Never re-push if already sent or previously skipped
            if ($attempt->status === PushDeliveryAttempt::STATUS_SENT ||
                $attempt->status === PushDeliveryAttempt::STATUS_SKIPPED
            ) {
                continue;
            }

            $result = $fcmService->sendToDevice($device, $notification, $attempt);

            if ($result['success']) {
                $attempt->markSent($result['provider_message_id']);
            } elseif ($result['is_invalid_token']) {
                $attempt->markFailed($result['error_code'], true);
            } elseif ($result['is_transient']) {
                $attempt->increment('attempt_count');
                $attempt->update([
                    'last_attempt_at' => now(),
                    'error_code' => $result['error_code'],
                ]);
                $transientErrors[] = $result['error_code'];
            } elseif ($result['status'] === PushDeliveryAttempt::STATUS_SKIPPED) {
                $attempt->markSkipped($result['error_code']);
            } else {
                $attempt->markFailed($result['error_code'], false);
            }
        }

        // If any transient errors occurred and attempts haven't reached max tries, trigger backoff retry
        if (!empty($transientErrors) && $this->attempts() < $this->tries) {
            throw new \RuntimeException('Transient FCM push delivery failure: ' . implode(', ', $transientErrors));
        }
    }

    /**
     * Handle job permanent failure without leaking tokens or private data.
     */
    public function failed(?\Throwable $exception): void
    {
        Log::error('SendPushNotification job permanently failed', [
            'user_notification_id' => $this->userNotificationId,
            'error' => $exception?->getMessage(),
        ]);
    }
}
