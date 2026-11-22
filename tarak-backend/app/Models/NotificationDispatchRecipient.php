<?php

namespace App\Models;

use App\Services\FinancialService;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class NotificationDispatchRecipient extends Model
{
    use HasFactory;

    public const BILLING_FREE = 'FREE';
    public const BILLING_RESERVED = 'RESERVED';
    public const BILLING_CAPTURED = 'CAPTURED';
    public const BILLING_RELEASED = 'RELEASED';
    public const BILLING_REFUNDED = 'REFUNDED';
    public const BILLING_FAILED = 'FAILED';
    public const BILLING_CHARGED_CAMPAIGN = 'CHARGED_CAMPAIGN';

    public const DELIVERY_QUEUED = 'QUEUED';
    public const DELIVERY_FCM_ACCEPTED = 'FCM_ACCEPTED';
    public const DELIVERY_IN_APP_ONLY = 'IN_APP_ONLY';
    public const DELIVERY_NO_ACTIVE_DEVICE = 'NO_ACTIVE_DEVICE';
    public const DELIVERY_OPTED_OUT = 'OPTED_OUT';
    public const DELIVERY_BLOCKED_BY_ADMIN = 'BLOCKED_BY_ADMIN';
    public const DELIVERY_FAILED = 'FAILED';
    public const DELIVERY_INVALID_TOKEN = 'INVALID_TOKEN';
    public const DELIVERY_SKIPPED = 'SKIPPED';

    /** Honest push delivery status labels: never claim guaranteed device display. */
    public const DELIVERY_LABELS = [
        self::DELIVERY_QUEUED => 'Kuyrukta bekliyor',
        self::DELIVERY_FCM_ACCEPTED => 'FCM tarafından kabul edildi',
        self::DELIVERY_IN_APP_ONLY => 'Yalnızca uygulama içi bildirim',
        self::DELIVERY_NO_ACTIVE_DEVICE => 'Aktif push cihazı yok',
        self::DELIVERY_OPTED_OUT => 'Kullanıcı izni kapalı / iptal edilmiş',
        self::DELIVERY_BLOCKED_BY_ADMIN => 'Yönetici tarafından engellendi',
        self::DELIVERY_FAILED => 'FCM gönderimi başarısız',
        self::DELIVERY_INVALID_TOKEN => 'Geçersiz cihaz belirteci',
        self::DELIVERY_SKIPPED => 'Push atlandı (FCM yapılandırılmamış/atlandı)',
    ];

    protected $fillable = [
        'dispatch_id',
        'provider_user_id',
        'recipient_user_id',
        'user_notification_id',
        'birthday_delivery_id',
        'billing_reference',
        'unit_price',
        'reserved_promo_amount',
        'reserved_cash_amount',
        'captured_promo_amount',
        'captured_cash_amount',
        'billing_status',
        'delivery_status',
        'delivery_error_code',
        'device_attempts_count',
        'fcm_accepted_devices_count',
        'attempted_at',
        'settled_at',
    ];

    protected function casts(): array
    {
        return [
            'unit_price' => 'decimal:2',
            'reserved_promo_amount' => 'decimal:2',
            'reserved_cash_amount' => 'decimal:2',
            'captured_promo_amount' => 'decimal:2',
            'captured_cash_amount' => 'decimal:2',
            'device_attempts_count' => 'integer',
            'fcm_accepted_devices_count' => 'integer',
            'attempted_at' => 'datetime',
            'settled_at' => 'datetime',
        ];
    }

    public function dispatch(): BelongsTo
    {
        return $this->belongsTo(NotificationDispatch::class, 'dispatch_id');
    }

    public function recipient(): BelongsTo
    {
        return $this->belongsTo(User::class, 'recipient_user_id');
    }

    public function userNotification(): BelongsTo
    {
        return $this->belongsTo(UserNotification::class, 'user_notification_id');
    }

    public function birthdayDelivery(): BelongsTo
    {
        return $this->belongsTo(BirthdayGreetingDelivery::class, 'birthday_delivery_id');
    }

    /** Strictly returns display identity + attempt state (ZERO birth_date, address, email, phone, or tokens). */
    public function presentForAdmin(): array
    {
        $recipient = $this->recipient;
        $capturedCents = FinancialService::parseToCents($this->captured_promo_amount)
            + FinancialService::parseToCents($this->captured_cash_amount);

        return [
            'id' => $this->id,
            'recipient_user_id' => (int) $this->recipient_user_id,
            'display_name' => $recipient?->name ?: ('Kullanıcı #' . $this->recipient_user_id),
            'billing_reference' => $this->billing_reference,
            'unit_price' => (float) $this->unit_price,
            'captured_amount' => (float) FinancialService::formatFromCents($capturedCents),
            'billing_status' => $this->billing_status,
            'delivery_status' => $this->delivery_status,
            'delivery_status_label' => self::DELIVERY_LABELS[$this->delivery_status] ?? $this->delivery_status,
            'delivery_error_code' => $this->delivery_error_code,
            'device_attempts_count' => (int) $this->device_attempts_count,
            'fcm_accepted_devices_count' => (int) $this->fcm_accepted_devices_count,
            'attempted_at' => $this->attempted_at?->toISOString(),
            'settled_at' => $this->settled_at?->toISOString(),
            'created_at' => $this->created_at?->toISOString(),
        ];
    }
}
