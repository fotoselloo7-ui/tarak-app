<?php

namespace App\Services;

use App\Models\IntegrationSetting;
use Illuminate\Support\Facades\Cache;

/**
 * Single lookup point for integration credentials.
 *
 * PRIORITY (documented contract, section 27 of the spec):
 *   1. encrypted admin setting (integration_settings)
 *   2. ENV / config() fallback  — existing production behaviour is preserved
 *   3. supplied default
 *
 * Nothing here ever returns a secret to the HTTP layer; callers that build API
 * responses must use isConfigured()/mask() instead of get().
 *
 * Config cache safety: values are read through the DB + a short Cache entry
 * that is invalidated on every write, so `php artisan config:cache` can never
 * pin a stale credential.
 */
class IntegrationSettings
{
    private const CACHE_KEY = 'integration_settings_map';
    private const CACHE_TTL = 300; // seconds

    /** Request-local memo so a single request never re-hits the cache store. */
    private ?array $memo = null;

    /**
     * Maps a setting to the config() key it falls back to.
     * Only keys listed here may be overridden from the admin panel.
     */
    public const SCHEMA = [
        'paytr' => [
            'enabled' => ['secret' => false, 'config' => null, 'default' => null],
            'merchant_id' => ['secret' => true, 'config' => 'paytr.merchant_id', 'default' => ''],
            'merchant_key' => ['secret' => true, 'config' => 'paytr.merchant_key', 'default' => ''],
            'merchant_salt' => ['secret' => true, 'config' => 'paytr.merchant_salt', 'default' => ''],
            'test_mode' => ['secret' => false, 'config' => 'paytr.test_mode', 'default' => 1],
            'ok_url' => ['secret' => false, 'config' => 'paytr.ok_url', 'default' => ''],
            'fail_url' => ['secret' => false, 'config' => 'paytr.fail_url', 'default' => ''],
        ],
        'sms' => [
            'enabled' => ['secret' => false, 'config' => null, 'default' => '0'],
            'provider' => ['secret' => false, 'config' => null, 'default' => 'netgsm'],
            'username' => ['secret' => false, 'config' => null, 'default' => ''],
            'password' => ['secret' => true, 'config' => null, 'default' => ''],
            'sender_title' => ['secret' => false, 'config' => null, 'default' => ''],
            'default_country' => ['secret' => false, 'config' => null, 'default' => '90'],
            'test_mode' => ['secret' => false, 'config' => null, 'default' => '1'],
        ],
        'smtp' => [
            'host' => ['secret' => false, 'config' => 'mail.mailers.smtp.host', 'default' => ''],
            'port' => ['secret' => false, 'config' => 'mail.mailers.smtp.port', 'default' => ''],
            'username' => ['secret' => false, 'config' => 'mail.mailers.smtp.username', 'default' => ''],
            'password' => ['secret' => true, 'config' => 'mail.mailers.smtp.password', 'default' => ''],
            'encryption' => ['secret' => false, 'config' => 'mail.mailers.smtp.scheme', 'default' => ''],
            'from_address' => ['secret' => false, 'config' => 'mail.from.address', 'default' => ''],
            'from_name' => ['secret' => false, 'config' => 'mail.from.name', 'default' => ''],
        ],
        'fcm' => [
            'enabled' => ['secret' => false, 'config' => 'fcm.enabled', 'default' => false],
            'project_id' => ['secret' => false, 'config' => 'fcm.project_id', 'default' => ''],
        ],
        'sms_events' => [
            // Per-event enable/disable switches (section 11). Values are '0'/'1'.
            'appointment_created' => ['secret' => false, 'config' => null, 'default' => '0'],
            'appointment_confirmed' => ['secret' => false, 'config' => null, 'default' => '0'],
            'appointment_rejected' => ['secret' => false, 'config' => null, 'default' => '0'],
            'appointment_cancelled' => ['secret' => false, 'config' => null, 'default' => '0'],
            'direct_request_created' => ['secret' => false, 'config' => null, 'default' => '0'],
            'provider_accepted' => ['secret' => false, 'config' => null, 'default' => '0'],
            'service_started' => ['secret' => false, 'config' => null, 'default' => '0'],
            'service_completed' => ['secret' => false, 'config' => null, 'default' => '0'],
            'dispute_opened' => ['secret' => false, 'config' => null, 'default' => '0'],
            'otp' => ['secret' => false, 'config' => null, 'default' => '0'],
        ],
    ];

    /**
     * Resolved value: encrypted admin setting -> config()/ENV -> default.
     */
    public function get(string $group, string $key, mixed $default = null): mixed
    {
        $stored = $this->all()[$group][$key] ?? null;
        if ($stored !== null && $stored !== '') {
            return $stored;
        }

        $schema = self::SCHEMA[$group][$key] ?? null;
        if ($schema && $schema['config']) {
            $fromConfig = config($schema['config']);
            if ($fromConfig !== null && $fromConfig !== '') {
                return $fromConfig;
            }
        }

        if ($default !== null) {
            return $default;
        }

        return $schema['default'] ?? null;
    }

    /** True when a value resolves to something non-empty (no secret exposed). */
    public function isConfigured(string $group, string $key): bool
    {
        $value = $this->get($group, $key);

        return $value !== null && $value !== '' && $value !== false;
    }

    /** Boolean-ish toggle helper ('1'/'0'/true/false/'true'). */
    public function isEnabled(string $group, string $key, bool $default = false): bool
    {
        $raw = $this->get($group, $key);
        if ($raw === null || $raw === '') {
            return $default;
        }

        return filter_var($raw, FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE) ?? $default;
    }

    /**
     * Writes a value. An EMPTY secret is ignored so "save" never wipes an
     * existing credential the admin simply didn't retype (spec section 3).
     *
     * @return bool whether the stored value actually changed
     */
    public function set(string $group, string $key, ?string $value, ?int $userId = null): bool
    {
        $schema = self::SCHEMA[$group][$key] ?? null;
        if (!$schema) {
            return false;
        }

        $isSecret = (bool) $schema['secret'];
        if ($isSecret && ($value === null || $value === '')) {
            return false; // keep the existing secret
        }

        IntegrationSetting::updateOrCreate(
            ['group' => $group, 'key' => $key],
            ['value' => $value, 'is_secret' => $isSecret, 'updated_by' => $userId],
        );

        $this->flush();

        return true;
    }

    /** Masks a credential for display: only the last 4 characters survive. */
    public function mask(string $group, string $key): ?string
    {
        $value = $this->get($group, $key);
        if ($value === null || $value === '') {
            return null;
        }

        $value = (string) $value;
        if (strlen($value) <= 4) {
            return str_repeat('•', 8);
        }

        return str_repeat('•', 8) . substr($value, -4);
    }

    /** Whether the value came from the encrypted admin store (vs ENV). */
    public function isOverridden(string $group, string $key): bool
    {
        $stored = $this->all()[$group][$key] ?? null;

        return $stored !== null && $stored !== '';
    }

    public function updatedAt(string $group, string $key): ?string
    {
        $row = IntegrationSetting::query()
            ->where('group', $group)->where('key', $key)->first();

        return $row?->updated_at?->toIso8601String();
    }

    /** group => [key => decrypted value] */
    private function all(): array
    {
        if ($this->memo !== null) {
            return $this->memo;
        }

        $this->memo = Cache::remember(self::CACHE_KEY, self::CACHE_TTL, function () {
            $map = [];
            foreach (IntegrationSetting::all() as $row) {
                $map[$row->group][$row->key] = $row->value;
            }

            return $map;
        });

        return $this->memo;
    }

    public function flush(): void
    {
        $this->memo = null;
        Cache::forget(self::CACHE_KEY);
    }
}
