<?php

namespace App\Services;

use App\Models\PushDeliveryAttempt;
use App\Models\PushDevice;
use App\Models\UserNotification;
use Google\Auth\Credentials\ServiceAccountCredentials;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class FcmPushService
{
    protected static ?\Closure $tokenResolver = null;

    /**
     * For testing purposes, allows overriding OAuth access token resolution.
     */
    public static function resolveAccessTokenUsing(?\Closure $resolver): void
    {
        static::$tokenResolver = $resolver;
    }

    /**
     * Determine whether FCM push notifications are configured and enabled.
     */
    public function isConfigured(): bool
    {
        $enabled = config('fcm.enabled', false);
        $projectId = config('fcm.project_id');
        $credentialsPath = config('fcm.credentials_path');

        if (!$enabled || empty($projectId)) {
            return false;
        }

        // If custom token resolver is set (e.g. tests), consider configured
        if (static::$tokenResolver !== null) {
            return true;
        }

        if (!empty($credentialsPath) && file_exists($credentialsPath)) {
            return true;
        }

        return false;
    }

    /**
     * Retrieve or cache a short-lived OAuth 2.0 access token for FCM HTTP v1.
     */
    public function getAccessToken(): ?string
    {
        if (static::$tokenResolver !== null) {
            return (string) call_user_func(static::$tokenResolver);
        }

        if (!$this->isConfigured()) {
            Log::info('FCM not configured, skipping access token generation.');
            return null;
        }

        $cacheKey = config('fcm.access_token_cache_key', 'fcm_http_v1_access_token');
        $cachedToken = Cache::get($cacheKey);
        if ($cachedToken && is_string($cachedToken)) {
            return $cachedToken;
        }

        try {
            $credentialsPath = config('fcm.credentials_path');
            $scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
            $credentials = new ServiceAccountCredentials($scopes, $credentialsPath);

            $tokenData = $credentials->fetchAuthToken();
            if (empty($tokenData['access_token'])) {
                Log::warning('FCM OAuth token exchange returned empty access token.');
                return null;
            }

            $token = $tokenData['access_token'];
            $expiresAt = $tokenData['expires_at'] ?? (time() + 3600);
            $buffer = (int) config('fcm.access_token_ttl_buffer', 300);
            $ttlSeconds = max(60, ($expiresAt - time()) - $buffer);

            Cache::put($cacheKey, $token, now()->addSeconds($ttlSeconds));

            return $token;
        } catch (\Throwable $e) {
            Log::error('FCM OAuth token generation failed.', [
                'error_type' => get_class($e),
                'error_message' => $e->getMessage(),
            ]);
            return null;
        }
    }

    /**
     * Send a push notification to a specific registered mobile device via FCM HTTP v1.
     *
     * @return array Result dictionary [success, status, provider_message_id, is_transient, is_invalid_token, error_code]
     */
    public function sendToDevice(
        PushDevice $device,
        UserNotification $notification,
        ?PushDeliveryAttempt $attempt = null
    ): array {
        if (!$this->isConfigured()) {
            Log::info('FCM not configured, skipping push delivery.', [
                'device_id' => $device->id,
                'notification_id' => $notification->id,
            ]);

            return [
                'success' => false,
                'is_transient' => false,
                'is_invalid_token' => false,
                'status' => PushDeliveryAttempt::STATUS_SKIPPED,
                'error_code' => 'FCM_NOT_CONFIGURED',
            ];
        }

        // Validate device status
        if (!$device->isActive()) {
            return [
                'success' => false,
                'is_transient' => false,
                'is_invalid_token' => true,
                'status' => PushDeliveryAttempt::STATUS_SKIPPED,
                'error_code' => 'DEVICE_NOT_ACTIVE',
            ];
        }

        $accessToken = $this->getAccessToken();
        if (empty($accessToken)) {
            return [
                'success' => false,
                'is_transient' => true,
                'is_invalid_token' => false,
                'status' => PushDeliveryAttempt::STATUS_PENDING,
                'error_code' => 'OAUTH_TOKEN_UNAVAILABLE',
            ];
        }

        $rawToken = $device->token_encrypted;
        if (empty($rawToken)) {
            $device->markInvalid('EMPTY_TOKEN');
            return [
                'success' => false,
                'is_transient' => false,
                'is_invalid_token' => true,
                'status' => PushDeliveryAttempt::STATUS_INVALID_TOKEN,
                'error_code' => 'EMPTY_TOKEN',
            ];
        }

        $projectId = config('fcm.project_id');
        $endpoint = "https://fcm.googleapis.com/v1/projects/{$projectId}/messages:send";

        $payload = $this->buildPayload($rawToken, $notification, $device->platform);

        try {
            $response = Http::withToken($accessToken)
                ->withHeaders([
                    'Content-Type' => 'application/json; UTF-8',
                ])
                ->timeout(10)
                ->post($endpoint, $payload);

            return $this->handleResponse($response, $device, $notification);
        } catch (ConnectionException $e) {
            Log::warning('FCM connection timeout or network failure.', [
                'device_id' => $device->id,
                'notification_id' => $notification->id,
            ]);

            return [
                'success' => false,
                'is_transient' => true,
                'is_invalid_token' => false,
                'status' => PushDeliveryAttempt::STATUS_PENDING,
                'error_code' => 'NETWORK_TIMEOUT',
            ];
        } catch (\Throwable $e) {
            Log::error('FCM unexpected delivery error.', [
                'device_id' => $device->id,
                'notification_id' => $notification->id,
                'error_type' => get_class($e),
            ]);

            return [
                'success' => false,
                'is_transient' => true,
                'is_invalid_token' => false,
                'status' => PushDeliveryAttempt::STATUS_PENDING,
                'error_code' => 'UNEXPECTED_ERROR',
            ];
        }
    }

    /**
     * Build standard FCM HTTP v1 JSON message structure.
     * Guaranteed zero sensitive data leakage (no GPS, exact address, start code, IBAN, TCKN, secret keys).
     */
    public function buildPayload(string $rawToken, UserNotification $notification, string $platform): array
    {
        // Minimal semantic data payload - all values stringified
        $data = [
            'notification_id' => (string) $notification->id,
            'type' => (string) $notification->type,
            'resource_type' => (string) ($notification->resource_type ?? ''),
            'resource_id' => (string) ($notification->resource_id ?? ''),
        ];

        if (!empty($notification->action_url)) {
            $data['action_url'] = (string) $notification->action_url;
        }

        $message = [
            'token' => $rawToken,
            'notification' => [
                'title' => (string) $notification->title,
                'body' => (string) $notification->message,
            ],
            'data' => $data,
        ];

        // Platform-specific configurations
        if (strtoupper($platform) === PushDevice::PLATFORM_ANDROID) {
            $message['android'] = [
                'priority' => 'HIGH',
                'notification' => [
                    'sound' => 'default',
                    'channel_id' => 'berberimgelsin_notifications',
                ],
            ];
        } elseif (strtoupper($platform) === PushDevice::PLATFORM_IOS) {
            $unreadCount = UserNotification::where('user_id', $notification->user_id)
                ->whereNull('read_at')
                ->count();

            $message['apns'] = [
                'headers' => [
                    'apns-priority' => '10',
                ],
                'payload' => [
                    'aps' => [
                        'sound' => 'default',
                        'badge' => $unreadCount,
                    ],
                ],
            ];
        }

        return ['message' => $message];
    }

    /**
     * Parse FCM HTTP v1 response and classify errors.
     */
    protected function handleResponse($response, PushDevice $device, UserNotification $notification): array
    {
        if ($response->successful()) {
            $providerMessageId = $response->json('name') ?? ('projects/' . config('fcm.project_id') . '/messages/' . uniqid());

            return [
                'success' => true,
                'is_transient' => false,
                'is_invalid_token' => false,
                'status' => PushDeliveryAttempt::STATUS_SENT,
                'provider_message_id' => $providerMessageId,
                'error_code' => null,
            ];
        }

        $statusCode = $response->status();
        $errorBody = $response->json('error') ?? [];
        $errorStatus = $errorBody['status'] ?? '';
        $errorMessage = $errorBody['message'] ?? '';
        $details = $errorBody['details'] ?? [];

        // Check for transient failure (429, 5xx)
        if ($statusCode === 429 || ($statusCode >= 500 && $statusCode <= 599)) {
            Log::warning("FCM transient upstream error HTTP {$statusCode}.", [
                'device_id' => $device->id,
                'notification_id' => $notification->id,
                'status_code' => $statusCode,
            ]);

            return [
                'success' => false,
                'is_transient' => true,
                'is_invalid_token' => false,
                'status' => PushDeliveryAttempt::STATUS_PENDING,
                'error_code' => "HTTP_{$statusCode}",
            ];
        }

        // Check for UNREGISTERED / Invalid token
        $isInvalidToken = false;
        $canonicalErrorCode = $errorStatus ?: "HTTP_{$statusCode}";

        if ($errorStatus === 'UNREGISTERED') {
            $isInvalidToken = true;
            $canonicalErrorCode = 'UNREGISTERED';
        } else {
            foreach ($details as $detail) {
                $errCode = $detail['errorCode'] ?? '';
                if ($errCode === 'UNREGISTERED') {
                    $isInvalidToken = true;
                    $canonicalErrorCode = 'UNREGISTERED';
                    break;
                }
                // Differentiate payload error vs token error on INVALID_ARGUMENT
                if ($errCode === 'INVALID_ARGUMENT') {
                    $detailField = $detail['field'] ?? '';
                    if (str_contains(strtolower($detailField), 'token') ||
                        str_contains(strtolower($errorMessage), 'registration token') ||
                        str_contains(strtolower($errorMessage), 'invalid token')
                    ) {
                        $isInvalidToken = true;
                        $canonicalErrorCode = 'INVALID_ARGUMENT_TOKEN';
                        break;
                    }
                }
            }
        }

        if ($isInvalidToken) {
            $device->markInvalid($canonicalErrorCode);

            Log::info('FCM registration token marked invalid.', [
                'device_id' => $device->id,
                'error_code' => $canonicalErrorCode,
            ]);

            return [
                'success' => false,
                'is_transient' => false,
                'is_invalid_token' => true,
                'status' => PushDeliveryAttempt::STATUS_INVALID_TOKEN,
                'error_code' => $canonicalErrorCode,
            ];
        }

        // Other permanent client error (e.g. 400 bad payload, 403 forbidden)
        Log::warning('FCM permanent delivery failure.', [
            'device_id' => $device->id,
            'notification_id' => $notification->id,
            'status_code' => $statusCode,
            'error_status' => $errorStatus,
        ]);

        return [
            'success' => false,
            'is_transient' => false,
            'is_invalid_token' => false,
            'status' => PushDeliveryAttempt::STATUS_FAILED,
            'error_code' => $canonicalErrorCode,
        ];
    }
}
