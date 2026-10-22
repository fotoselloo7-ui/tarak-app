<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\PushDevice;
use App\Models\UserPushPreference;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class PushNotificationController extends Controller
{
    /**
     * Register or rotate a mobile push device for the authenticated user.
     */
    public function registerDevice(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'platform' => ['required', 'string', 'in:ANDROID,IOS,android,ios'],
            'token' => ['required', 'string', 'min:10', 'max:4096'],
            'installation_id' => ['nullable', 'string', 'max:255'],
            'app_version' => ['nullable', 'string', 'max:32'],
            'device_model' => ['nullable', 'string', 'max:64'],
        ]);

        $user = $request->user();
        $platform = strtoupper($validated['platform']);
        $rawToken = trim($validated['token']);
        $tokenHash = PushDevice::hashToken($rawToken);
        $installHash = PushDevice::hashInstallationId($validated['installation_id'] ?? null);

        $device = DB::transaction(function () use ($user, $platform, $rawToken, $tokenHash, $installHash, $validated) {
            // Check if this exact FCM registration token is already registered (even by a previous user on the same physical phone)
            $existing = PushDevice::where('token_hash', $tokenHash)->lockForUpdate()->first();

            // If an installation ID is provided, deactivate older tokens belonging to this user on the same installation
            if ($installHash) {
                PushDevice::where('user_id', $user->id)
                    ->where('installation_id_hash', $installHash)
                    ->where('token_hash', '!=', $tokenHash)
                    ->update([
                        'status' => PushDevice::STATUS_INACTIVE,
                        'invalidated_at' => now(),
                    ]);
            }

            if ($existing) {
                // Re-bind token to current authenticated user and reactivate
                $existing->update([
                    'user_id' => $user->id,
                    'platform' => $platform,
                    'token_encrypted' => $rawToken,
                    'installation_id_hash' => $installHash,
                    'status' => PushDevice::STATUS_ACTIVE,
                    'invalidated_at' => null,
                    'last_registered_at' => now(),
                    'app_version' => $validated['app_version'] ?? $existing->app_version,
                    'device_model' => $validated['device_model'] ?? $existing->device_model,
                ]);

                return $existing;
            }

            return PushDevice::create([
                'user_id' => $user->id,
                'platform' => $platform,
                'token_hash' => $tokenHash,
                'token_encrypted' => $rawToken,
                'installation_id_hash' => $installHash,
                'status' => PushDevice::STATUS_ACTIVE,
                'last_registered_at' => now(),
                'app_version' => $validated['app_version'] ?? null,
                'device_model' => $validated['device_model'] ?? null,
            ]);
        });

        return response()->json([
            'id' => $device->id,
            'platform' => $device->platform,
            'status' => $device->status,
            'app_version' => $device->app_version,
            'device_model' => $device->device_model,
            'last_registered_at' => $device->last_registered_at?->toIso8601String(),
            'created_at' => $device->created_at?->toIso8601String(),
        ], 200);
    }

    /**
     * Unregister a push device belonging to the authenticated user.
     */
    public function unregisterDevice(Request $request, PushDevice $device): JsonResponse
    {
        if ($device->user_id !== $request->user()->id) {
            return response()->json([
                'message' => 'Bu cihaza erişim yetkiniz bulunmuyor.',
            ], 403);
        }

        $device->update([
            'status' => PushDevice::STATUS_INACTIVE,
            'invalidated_at' => now(),
        ]);

        return response()->json([
            'message' => 'Cihaz kaydı başarıyla silindi.',
        ]);
    }

    /**
     * List all registered devices for the authenticated user (never exposes token).
     */
    public function listDevices(Request $request): JsonResponse
    {
        $devices = $request->user()->pushDevices()
            ->select([
                'id',
                'platform',
                'status',
                'app_version',
                'device_model',
                'last_registered_at',
                'last_used_at',
                'created_at',
            ])
            ->orderByDesc('last_registered_at')
            ->get();

        return response()->json($devices);
    }

    /**
     * Get user push notification preferences.
     */
    public function getPreferences(Request $request): JsonResponse
    {
        $userId = $request->user()->id;

        return response()->json([
            'push_enabled' => UserPushPreference::isPushEnabledForUser($userId),
            // Discount campaigns of providers ("bildirim reklamı"): on by default, can be turned off on its own.
            'campaign_enabled' => UserPushPreference::isCampaignEnabledForUser($userId),
        ]);
    }

    /**
     * Update user push notification preferences.
     */
    public function updatePreferences(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'push_enabled' => ['required_without:campaign_enabled', 'boolean'],
            'campaign_enabled' => ['required_without:push_enabled', 'boolean'],
        ]);

        $changes = [];
        foreach (['push_enabled', 'campaign_enabled'] as $key) {
            if (array_key_exists($key, $validated)) {
                $changes[$key] = (bool) $validated[$key];
            }
        }

        $pref = UserPushPreference::updateOrCreate(['user_id' => $request->user()->id], $changes)->fresh();

        return response()->json([
            'push_enabled' => (bool) $pref->push_enabled,
            'campaign_enabled' => (bool) $pref->campaign_enabled,
        ]);
    }
}
