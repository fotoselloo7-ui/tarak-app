<?php

namespace App\Services;

use App\Models\User;
use App\Models\UserNotification;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\Log;

class NotificationService
{
    /**
     * Notify a specific user with idempotent deduplication and privacy sanitization.
     */
    public function notifyUser(
        User|int $user,
        string $type,
        string $title,
        string $message,
        ?string $resourceType = null,
        mixed $resourceId = null,
        ?string $actionUrl = null,
        array $metadata = [],
        ?string $idempotencyKey = null
    ): ?UserNotification {
        $userId = $user instanceof User ? $user->id : (int) $user;

        if ($userId <= 0) {
            return null;
        }

        $resIdStr = $resourceId !== null ? (string) $resourceId : null;

        // Generate deterministic idempotency key if not explicitly given
        $effectiveKey = $idempotencyKey ?: "{$type}:" . ($resourceType ?: 'NONE') . ":{$resIdStr}:{$userId}";

        // Fast check existing
        $existing = UserNotification::where('idempotency_key', $effectiveKey)->first();
        if ($existing) {
            return $existing;
        }

        $cleanMetadata = self::sanitizeMetadata($metadata);

        try {
            $notification = UserNotification::create([
                'user_id' => $userId,
                'type' => $type,
                'title' => trim($title),
                'message' => trim($message),
                'resource_type' => $resourceType,
                'resource_id' => $resIdStr,
                'action_url' => $actionUrl,
                'metadata' => !empty($cleanMetadata) ? $cleanMetadata : null,
                'idempotency_key' => $effectiveKey,
            ]);

            \Illuminate\Support\Facades\DB::afterCommit(function () use ($notification) {
                try {
                    event(new \App\Events\NotificationCreated($notification));
                } catch (\Throwable $e) {
                    \Illuminate\Support\Facades\Log::warning('Realtime notification broadcast failed: ' . $e->getMessage(), [
                        'notification_id' => $notification->id,
                        'user_id' => $notification->user_id,
                    ]);
                }

                try {
                    \App\Jobs\SendPushNotification::dispatch($notification->id)->onQueue('push');
                } catch (\Throwable $e) {
                    \Illuminate\Support\Facades\Log::warning('Push notification dispatch failed: ' . $e->getMessage(), [
                        'notification_id' => $notification->id,
                        'user_id' => $notification->user_id,
                    ]);
                }
            });

            return $notification;
        } catch (QueryException $e) {
            // Check for unique constraint violation (code 1062 in MySQL)
            if (isset($e->errorInfo[1]) && (int) $e->errorInfo[1] === 1062) {
                return UserNotification::where('idempotency_key', $effectiveKey)->first();
            }
            if (str_contains($e->getMessage(), 'Duplicate entry') || str_contains($e->getMessage(), 'idempotency_key')) {
                return UserNotification::where('idempotency_key', $effectiveKey)->first();
            }
            throw $e;
        }
    }

    /**
     * Notify all active admins with unique idempotency keys per admin.
     *
     * @return UserNotification[]
     */
    public function notifyAdmins(
        string $type,
        string $title,
        string $message,
        ?string $resourceType = null,
        mixed $resourceId = null,
        ?string $actionUrl = null,
        array $metadata = [],
        ?string $idempotencyKeyPrefix = null
    ): array {
        $admins = User::where('role', User::ROLE_ADMIN)->get();
        $notifications = [];

        $resIdStr = $resourceId !== null ? (string) $resourceId : 'NONE';
        $prefix = $idempotencyKeyPrefix ?: "{$type}:" . ($resourceType ?: 'NONE') . ":{$resIdStr}:ADMIN";

        foreach ($admins as $admin) {
            $key = "{$prefix}:{$admin->id}";
            $notif = $this->notifyUser(
                $admin,
                $type,
                $title,
                $message,
                $resourceType,
                $resourceId,
                $actionUrl,
                $metadata,
                $key
            );
            if ($notif) {
                $notifications[] = $notif;
            }
        }

        return $notifications;
    }

    /**
     * Recursively strip sensitive information from notification metadata.
     * Ensures zero leakage of GPS, address, TCKN, secrets, raw codes, or admin notes.
     */
    public static function sanitizeMetadata(array $metadata): array
    {
        $sensitiveKeys = [
            'address',
            'full_address',
            'address_line',
            'customer_address',
            'customer_exact_address',
            'street',
            'building',
            'building_no',
            'apartment',
            'apartment_no',
            'directions',
            'latitude',
            'longitude',
            'lat',
            'lng',
            'tckn',
            'tax_id',
            'vkn',
            'tax_id_or_tckn',
            'tax_id_or_tckn_encrypted',
            'iban',
            'full_iban',
            'iban_encrypted',
            'merchant_key',
            'merchant_salt',
            'paytr_token',
            'token',
            'sanctum_token',
            'service_start_code',
            'start_code',
            'raw_code',
            'code_hash',
            'encrypted_code',
            'encrypted_location',
            'encrypted_location_payload',
            'password',
            'password_confirmation',
            'secret',
            'admin_note',
            'internal_note',
            'private_note',
        ];

        $clean = [];
        foreach ($metadata as $k => $v) {
            $lowerKey = strtolower((string) $k);
            if (in_array($lowerKey, $sensitiveKeys, true)) {
                continue;
            }
            if (is_array($v)) {
                $clean[$k] = self::sanitizeMetadata($v);
            } else {
                $clean[$k] = $v;
            }
        }

        return $clean;
    }
}
