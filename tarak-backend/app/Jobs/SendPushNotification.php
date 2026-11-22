<?php

namespace App\Jobs;

use App\Models\NotificationAbuseAlert;
use App\Models\NotificationDispatchRecipient;
use App\Models\ProviderNotificationControl;
use App\Models\PushDeliveryAttempt;
use App\Models\PushDevice;
use App\Models\UserNotification;
use App\Models\UserPushPreference;
use App\Services\FcmPushService;
use App\Services\NotificationAbuseGuardService;
use App\Services\NotificationBillingService;
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
    public function handle(
        FcmPushService $fcmService,
        ?NotificationBillingService $billing = null,
        ?NotificationAbuseGuardService $abuseGuard = null
    ): void {
        $billing ??= app(NotificationBillingService::class);
        $abuseGuard ??= app(NotificationAbuseGuardService::class);

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

        // Re-check appointment validity and reminder preferences at delivery time so
        // cancelled, rejected, or rescheduled appointments never receive stale push reminders.
        if ($notification->type === UserNotification::TYPE_APPOINTMENT_REMINDER) {
            $appointment = \App\Models\Appointment::find($notification->resource_id);
            if (!$appointment || $appointment->status !== \App\Models\Appointment::STATUS_CONFIRMED) {
                return;
            }
            $meta = is_array($notification->metadata) ? $notification->metadata : [];
            $metaDate = $meta['appointment_date'] ?? null;
            $metaTime = $meta['start_time'] ?? null;
            $actualDate = $appointment->appointment_date?->format('Y-m-d');
            $actualTime = substr((string) $appointment->start_time, 0, 5);
            if (($metaDate && $metaDate !== $actualDate) || ($metaTime && $metaTime !== $actualTime)) {
                return;
            }
            $prefs = UserPushPreference::forUser((int) $notification->user_id);
            $stage = $meta['reminder_stage'] ?? 'approaching';
            if ($stage === 'start' && !($prefs['appointment_start_alert_enabled'] ?? true)) {
                return;
            }
            if ($stage !== 'start' && !($prefs['appointment_reminder_enabled'] ?? true)) {
                return;
            }
        }

        $meta = is_array($notification->metadata) ? $notification->metadata : [];
        $isTrackedOutbound = in_array($notification->type, [
            UserNotification::TYPE_BIRTHDAY_GREETING,
            UserNotification::TYPE_PROVIDER_CAMPAIGN,
        ], true);

        // Enforce provider-initiated outbound permissions at queue dispatch time too, NEVER blocking
        // essential appointment, chat, payment, or system notifications TO a restricted provider.
        if ($isTrackedOutbound) {
            $providerUserId = (int) ($meta['provider_user_id']
                ?? ($notification->resource_type === UserNotification::RESOURCE_PROVIDER_PROFILE ? $notification->resource_id : 0));

            if ($providerUserId > 0) {
                $blocked = false;
                if ($notification->type === UserNotification::TYPE_PROVIDER_CAMPAIGN) {
                    $blocked = !$abuseGuard->checkPermission($providerUserId, ProviderNotificationControl::CHANNEL_NOTIFICATION_AD)['allowed'];
                } elseif ($notification->type === UserNotification::TYPE_BIRTHDAY_GREETING) {
                    $bdayOk = $abuseGuard->checkPermission($providerUserId, ProviderNotificationControl::CHANNEL_BIRTHDAY)['allowed'];
                    $autoOk = $abuseGuard->checkPermission($providerUserId, ProviderNotificationControl::CHANNEL_AUTO_SPECIAL_DAY)['allowed'];
                    $blocked = !$bdayOk || !$autoOk;
                }

                if ($blocked) {
                    $abuseGuard->recordAlert(
                        $providerUserId,
                        NotificationAbuseAlert::TYPE_BLOCKED_PROVIDER_QUEUE_STOPPED,
                        'Yönetici engeli aktifken kuyruktaki push bildirimi durduruldu.',
                        ['notification_id' => $notification->id, 'type' => $notification->type],
                        dispatchId: isset($meta['dispatch_id']) ? (int) $meta['dispatch_id'] : null,
                        severity: 'HIGH',
                        autoAction: 'PUSH_CANCELLED_AND_RELEASED',
                    );
                    $billing->settleByNotificationId(
                        $notification->id,
                        NotificationDispatchRecipient::DELIVERY_BLOCKED_BY_ADMIN,
                        'ADMIN_BLOCKED',
                        false
                    );

                    return;
                }
            }
        }

        // Verify recipient push preferences
        if (!UserPushPreference::isPushEnabledForUser($notification->user_id)) {
            if ($isTrackedOutbound) {
                $billing->settleByNotificationId(
                    $notification->id,
                    NotificationDispatchRecipient::DELIVERY_OPTED_OUT,
                    'PUSH_DISABLED',
                    false
                );
            }

            return;
        }

        // Birthday greetings use a dedicated explicit opt-in independent of campaign/push defaults.
        if ($notification->type === UserNotification::TYPE_BIRTHDAY_GREETING &&
            !UserPushPreference::isBirthdayGreetingEnabledForUser($notification->user_id)) {
            $abuseGuard->recordAlert(
                isset($meta['provider_user_id']) ? (int) $meta['provider_user_id'] : null,
                NotificationAbuseAlert::TYPE_BIRTHDAY_OPT_OUT_ATTEMPT,
                'Doğum günü izni kapalı kullanıcıya kuyruk teslimi durduruldu.',
                ['notification_id' => $notification->id, 'recipient_user_id' => $notification->user_id],
                dispatchId: isset($meta['dispatch_id']) ? (int) $meta['dispatch_id'] : null,
                severity: 'INFO',
                autoAction: 'PUSH_CANCELLED_AND_RELEASED',
            );
            $billing->settleByNotificationId(
                $notification->id,
                NotificationDispatchRecipient::DELIVERY_OPTED_OUT,
                'BIRTHDAY_OPT_OUT',
                false
            );

            return;
        }

        // Promotional/discount copy in a birthday greeting OR campaign ad MUST check campaign consent at delivery time too.
        $requiresCampaignConsent = in_array($notification->type, [
            UserNotification::TYPE_PROVIDER_CAMPAIGN,
            UserNotification::TYPE_ADMIN_CAMPAIGN,
        ], true) || ($notification->type === UserNotification::TYPE_BIRTHDAY_GREETING && !empty($meta['is_promotional_copy']));

        if ($requiresCampaignConsent && !UserPushPreference::isCampaignEnabledForUser($notification->user_id)) {
            if ($isTrackedOutbound) {
                $billing->settleByNotificationId(
                    $notification->id,
                    NotificationDispatchRecipient::DELIVERY_OPTED_OUT,
                    'CAMPAIGN_OPT_OUT',
                    false
                );
            }

            return;
        }

        // Fetch recipient's active mobile devices
        $devices = PushDevice::where('user_id', $notification->user_id)
            ->active()
            ->get();

        if ($devices->isEmpty()) {
            if ($isTrackedOutbound) {
                $billing->settleByNotificationId(
                    $notification->id,
                    NotificationDispatchRecipient::DELIVERY_NO_ACTIVE_DEVICE,
                    'NO_ACTIVE_DEVICE',
                    false
                );
            }

            return;
        }

        // If FCM is not enabled or credentials are missing in local dev, gracefully skip
        if (!$fcmService->isConfigured()) {
            Log::info('FCM is not configured, skipping push job delivery.', [
                'notification_id' => $notification->id,
                'user_id' => $notification->user_id,
            ]);
            if ($isTrackedOutbound) {
                $billing->settleByNotificationId(
                    $notification->id,
                    NotificationDispatchRecipient::DELIVERY_SKIPPED,
                    'FCM_NOT_CONFIGURED',
                    false
                );
            }

            return;
        }

        $transientErrors = [];
        $acceptedDevices = 0;
        $attemptedDevices = 0;
        $invalidTokens = 0;
        $lastErrorCode = null;

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
            if ($attempt->status === PushDeliveryAttempt::STATUS_SENT) {
                $acceptedDevices++;
                $attemptedDevices++;
                continue;
            }
            if ($attempt->status === PushDeliveryAttempt::STATUS_SKIPPED) {
                continue;
            }

            $attemptedDevices++;
            $result = $fcmService->sendToDevice($device, $notification, $attempt);

            if ($result['success']) {
                $attempt->markSent($result['provider_message_id']);
                $acceptedDevices++;
            } elseif ($result['is_invalid_token']) {
                $attempt->markFailed($result['error_code'], true);
                $invalidTokens++;
                $lastErrorCode = $result['error_code'];
            } elseif ($result['is_transient']) {
                $attempt->increment('attempt_count');
                $attempt->update([
                    'last_attempt_at' => now(),
                    'error_code' => $result['error_code'],
                ]);
                $transientErrors[] = $result['error_code'];
                $lastErrorCode = $result['error_code'];
            } elseif ($result['status'] === PushDeliveryAttempt::STATUS_SKIPPED) {
                $attempt->markSkipped($result['error_code']);
                $lastErrorCode = $result['error_code'];
            } else {
                $attempt->markFailed($result['error_code'], false);
                $lastErrorCode = $result['error_code'];
            }
        }

        // If at least 1 device accepted by FCM, capture billing reservation ONCE regardless of device count.
        if ($acceptedDevices > 0) {
            if ($isTrackedOutbound) {
                $billing->settleByNotificationId(
                    $notification->id,
                    NotificationDispatchRecipient::DELIVERY_FCM_ACCEPTED,
                    null,
                    true,
                    $attemptedDevices,
                    $acceptedDevices
                );
            }

            return;
        }

        // If any transient errors occurred and attempts haven't reached max tries, trigger backoff retry (keep reservation held).
        if (!empty($transientErrors) && $this->attempts() < $this->tries) {
            throw new \RuntimeException('Transient FCM push delivery failure: ' . implode(', ', $transientErrors));
        }

        // Permanent failure across all devices (or exhausted retries / skipped): release reservation cleanly.
        if ($isTrackedOutbound) {
            $status = ($invalidTokens > 0 && $invalidTokens === $attemptedDevices)
                ? NotificationDispatchRecipient::DELIVERY_INVALID_TOKEN
                : ($lastErrorCode === 'FCM_NOT_CONFIGURED'
                    ? NotificationDispatchRecipient::DELIVERY_SKIPPED
                    : NotificationDispatchRecipient::DELIVERY_FAILED);

            $billing->settleByNotificationId(
                $notification->id,
                $status,
                $lastErrorCode ?: 'FCM_FAILED',
                false,
                $attemptedDevices,
                0
            );
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

        app(NotificationBillingService::class)->settleByNotificationId(
            $this->userNotificationId,
            NotificationDispatchRecipient::DELIVERY_FAILED,
            'JOB_FAILED',
            false
        );
    }
}
