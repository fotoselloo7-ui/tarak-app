<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable, SoftDeletes;

    public const ROLE_CUSTOMER = 'CUSTOMER';
    public const ROLE_PROVIDER = 'PROVIDER';
    public const ROLE_ADMIN = 'ADMIN';

    /**
     * The attributes that are mass assignable.
     *
     * @var list<string>
     */
    protected $fillable = [
        'role',
        'first_name',
        'last_name',
        'name',
        'email',
        'phone',
        'password',
        'gender',
        'status',
        'is_demo',
        'avatar_url',
        'phone_verified_at',
        'email_verified_at',
        'last_login_at',
    ];

    /**
     * The attributes that should be hidden for serialization.
     *
     * @var list<string>
     */
    protected $hidden = [
        'password',
        'remember_token',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'phone_verified_at' => 'datetime',
            'last_login_at' => 'datetime',
            'is_demo' => 'boolean',
            'password' => 'hashed',
        ];
    }

    /**
     * Seed/demo marker is an internal admin purge flag only.
     * Customer/public surfaces must treat seeded accounts exactly like ordinary accounts.
     * Database queries such as where('is_demo', true) are unaffected, so admin bulk purge still works.
     */
    public function getIsDemoAttribute(mixed $value): bool
    {
        $actual = filter_var($value, FILTER_VALIDATE_BOOL);

        if (app()->runningInConsole()) {
            return $actual;
        }

        try {
            $request = request();
            if ($request->is('api/admin/*') || $request->is('admin/*')) {
                return $actual;
            }
        } catch (\Throwable) {
            return $actual;
        }

        return false;
    }

    public function getAvatarUrlAttribute(?string $value): ?string
    {
        return \App\Support\MediaUrl::resolve($value);
    }

    public function customerProfile(): HasOne
    {
        return $this->hasOne(CustomerProfile::class);
    }

    public function providerProfile(): HasOne
    {
        return $this->hasOne(ProviderProfile::class);
    }

    public function wallet(): HasOne
    {
        return $this->hasOne(Wallet::class);
    }

    public function payoutAccount(): HasOne
    {
        return $this->hasOne(ProviderPayoutAccount::class, 'provider_user_id');
    }

    public function payoutTransfers(): \Illuminate\Database\Eloquent\Relations\HasMany
    {
        return $this->hasMany(PayoutTransfer::class, 'provider_user_id');
    }

    public function notifications(): \Illuminate\Database\Eloquent\Relations\HasMany
    {
        return $this->hasMany(UserNotification::class, 'user_id');
    }

    public function isAdmin(): bool
    {
        return $this->role === self::ROLE_ADMIN;
    }

    public function isProvider(): bool
    {
        return $this->role === self::ROLE_PROVIDER;
    }

    public function isCustomer(): bool
    {
        return $this->role === self::ROLE_CUSTOMER;
    }

    public function customerAppointments(): \Illuminate\Database\Eloquent\Relations\HasMany
    {
        return $this->hasMany(Appointment::class, 'customer_user_id');
    }

    public function providerAppointments(): \Illuminate\Database\Eloquent\Relations\HasMany
    {
        return $this->hasMany(Appointment::class, 'provider_user_id');
    }

    /**
     * Canonical Phone Normalizer for Turkey (+905XXXXXXXXX).
     */
    public static function normalizePhone(?string $phone): ?string
    {
        if (!$phone) {
            return null;
        }

        // Remove everything except digits
        $digits = preg_replace('/\D/', '', $phone);

        // Strip country code if present (90)
        if (str_starts_with($digits, '90') && strlen($digits) === 12) {
            $digits = substr($digits, 2);
        }

        // Strip leading trunk zero if present (05...)
        if (str_starts_with($digits, '0') && strlen($digits) === 11) {
            $digits = substr($digits, 1);
        }

        // Validate Turkish mobile: 10 digits, starts with 5
        if (strlen($digits) === 10 && str_starts_with($digits, '5')) {
            return '+90' . $digits;
        }

        return null;
    }

    /**
     * Canonical Email Normalizer.
     */
    public static function normalizeEmail(?string $email): ?string
    {
        if (!$email) {
            return null;
        }

        $trimmed = trim(strtolower($email));
        return filter_var($trimmed, FILTER_VALIDATE_EMAIL) ? $trimmed : null;
    }

    /**
     * Mobile push devices registered for this user.
     */
    public function pushDevices(): \Illuminate\Database\Eloquent\Relations\HasMany
    {
        return $this->hasMany(PushDevice::class);
    }

    /**
     * User push notification preferences.
     */
    public function pushPreference(): HasOne
    {
        return $this->hasOne(UserPushPreference::class);
    }
}

