<?php

namespace App\Models;

use App\Services\FinancialService;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class NotificationDispatch extends Model
{
    use HasFactory;

    public const TYPE_NOTIFICATION_AD = 'NOTIFICATION_AD';
    public const TYPE_BIRTHDAY_GREETING = 'BIRTHDAY_GREETING';
    public const TYPE_AUTO_SPECIAL_DAY = 'AUTO_SPECIAL_DAY';

    public const PRICING_PER_CAMPAIGN = 'PER_CAMPAIGN';
    public const PRICING_PER_RECIPIENT = 'PER_RECIPIENT';
    public const PRICING_FREE = 'FREE';

    public const SOURCE_NONE = 'NONE';
    public const SOURCE_PROMO = 'PROMO';
    public const SOURCE_CASH = 'CASH';
    public const SOURCE_MIXED = 'MIXED';
    public const SOURCE_CARD = 'CARD';

    public const STATUS_PENDING_PAYMENT = 'PENDING_PAYMENT';
    public const STATUS_RESERVED = 'RESERVED';
    public const STATUS_QUEUED = 'QUEUED';
    public const STATUS_PROCESSING = 'PROCESSING';
    public const STATUS_COMPLETED = 'COMPLETED';
    public const STATUS_PARTIAL = 'PARTIAL';
    public const STATUS_BLOCKED = 'BLOCKED';
    public const STATUS_FAILED = 'FAILED';
    public const STATUS_REFUNDED = 'REFUNDED';
    public const STATUS_CANCELLED = 'CANCELLED';

    public const TYPE_LABELS = [
        self::TYPE_NOTIFICATION_AD => 'Bildirim Reklamı',
        self::TYPE_BIRTHDAY_GREETING => 'Doğum Günü Kutlaması',
        self::TYPE_AUTO_SPECIAL_DAY => 'Otomatik Özel Gün Mesajı',
    ];

    public const STATUS_LABELS = [
        self::STATUS_PENDING_PAYMENT => 'Ödeme Bekleniyor',
        self::STATUS_RESERVED => 'Bakiye Rezerve Edildi',
        self::STATUS_QUEUED => 'Kuyrukta',
        self::STATUS_PROCESSING => 'İşleniyor',
        self::STATUS_COMPLETED => 'İşlendi (FCM İletim Kaydı)',
        self::STATUS_PARTIAL => 'Kısmi İletim',
        self::STATUS_BLOCKED => 'Yönetici Tarafından Durduruldu',
        self::STATUS_FAILED => 'Başarısız',
        self::STATUS_REFUNDED => 'İade Edildi',
        self::STATUS_CANCELLED => 'İptal Edildi',
    ];

    public const SOURCE_LABELS = [
        self::SOURCE_NONE => 'Ücretsiz',
        self::SOURCE_PROMO => 'Promosyon Bakiyesi',
        self::SOURCE_CASH => 'Nakit Bakiye',
        self::SOURCE_MIXED => 'Promosyon + Nakit',
        self::SOURCE_CARD => 'Kart (PayTR)',
    ];

    protected $fillable = [
        'reference_code',
        'provider_user_id',
        'provider_profile_id',
        'notification_type',
        'source_type',
        'source_id',
        'title',
        'body',
        'pricing_mode',
        'unit_price',
        'total_cost',
        'reserved_promo_amount',
        'reserved_cash_amount',
        'captured_promo_amount',
        'captured_cash_amount',
        'refunded_promo_amount',
        'refunded_cash_amount',
        'balance_source',
        'targeted_count',
        'eligible_count',
        'attempted_count',
        'fcm_accepted_count',
        'failed_count',
        'skipped_count',
        'status',
        'status_reason',
        'sent_at',
        'completed_at',
    ];

    protected function casts(): array
    {
        return [
            'unit_price' => 'decimal:2',
            'total_cost' => 'decimal:2',
            'reserved_promo_amount' => 'decimal:2',
            'reserved_cash_amount' => 'decimal:2',
            'captured_promo_amount' => 'decimal:2',
            'captured_cash_amount' => 'decimal:2',
            'refunded_promo_amount' => 'decimal:2',
            'refunded_cash_amount' => 'decimal:2',
            'targeted_count' => 'integer',
            'eligible_count' => 'integer',
            'attempted_count' => 'integer',
            'fcm_accepted_count' => 'integer',
            'failed_count' => 'integer',
            'skipped_count' => 'integer',
            'sent_at' => 'datetime',
            'completed_at' => 'datetime',
        ];
    }

    public function provider(): BelongsTo
    {
        return $this->belongsTo(User::class, 'provider_user_id');
    }

    public function providerProfile(): BelongsTo
    {
        return $this->belongsTo(ProviderProfile::class, 'provider_profile_id');
    }

    public function recipients(): HasMany
    {
        return $this->hasMany(NotificationDispatchRecipient::class, 'dispatch_id');
    }

    public function recalculateCounters(): self
    {
        $rows = $this->recipients()->get();
        if ($rows->isEmpty()) {
            return $this;
        }

        $eligible = $rows->count();
        $attempted = $rows->whereNotIn('delivery_status', [NotificationDispatchRecipient::DELIVERY_QUEUED])->count();
        $accepted = $rows->where('delivery_status', NotificationDispatchRecipient::DELIVERY_FCM_ACCEPTED)->count();
        $failed = $rows->whereIn('delivery_status', [
            NotificationDispatchRecipient::DELIVERY_FAILED,
            NotificationDispatchRecipient::DELIVERY_INVALID_TOKEN,
        ])->count();
        $skipped = $rows->whereIn('delivery_status', [
            NotificationDispatchRecipient::DELIVERY_IN_APP_ONLY,
            NotificationDispatchRecipient::DELIVERY_NO_ACTIVE_DEVICE,
            NotificationDispatchRecipient::DELIVERY_OPTED_OUT,
            NotificationDispatchRecipient::DELIVERY_BLOCKED_BY_ADMIN,
            NotificationDispatchRecipient::DELIVERY_SKIPPED,
        ])->count();
        $queued = $rows->where('delivery_status', NotificationDispatchRecipient::DELIVERY_QUEUED)->count();

        $updates = [
            'eligible_count' => $eligible,
            'attempted_count' => $attempted,
            'fcm_accepted_count' => $accepted,
            'failed_count' => $failed,
            'skipped_count' => $skipped,
        ];

        if ($this->pricing_mode === self::PRICING_PER_RECIPIENT) {
            $reservedPromoCents = $rows->where('billing_status', NotificationDispatchRecipient::BILLING_RESERVED)
                ->sum(fn ($r) => FinancialService::parseToCents($r->reserved_promo_amount));
            $reservedCashCents = $rows->where('billing_status', NotificationDispatchRecipient::BILLING_RESERVED)
                ->sum(fn ($r) => FinancialService::parseToCents($r->reserved_cash_amount));
            $capturedPromoCents = $rows->sum(fn ($r) => FinancialService::parseToCents($r->captured_promo_amount));
            $capturedCashCents = $rows->sum(fn ($r) => FinancialService::parseToCents($r->captured_cash_amount));

            $updates['reserved_promo_amount'] = FinancialService::formatFromCents($reservedPromoCents);
            $updates['reserved_cash_amount'] = FinancialService::formatFromCents($reservedCashCents);
            $updates['captured_promo_amount'] = FinancialService::formatFromCents($capturedPromoCents);
            $updates['captured_cash_amount'] = FinancialService::formatFromCents($capturedCashCents);
            $updates['total_cost'] = FinancialService::formatFromCents($capturedPromoCents + $capturedCashCents);

            if ($capturedPromoCents > 0 && $capturedCashCents > 0) {
                $updates['balance_source'] = self::SOURCE_MIXED;
            } elseif ($capturedPromoCents > 0 || $reservedPromoCents > 0) {
                $updates['balance_source'] = self::SOURCE_PROMO;
            } elseif ($capturedCashCents > 0 || $reservedCashCents > 0) {
                $updates['balance_source'] = self::SOURCE_CASH;
            }
        }

        if ($queued === 0 && !in_array($this->status, [self::STATUS_BLOCKED, self::STATUS_REFUNDED, self::STATUS_CANCELLED], true)) {
            if ($accepted > 0 && ($failed > 0 || $skipped > 0)) {
                $updates['status'] = self::STATUS_PARTIAL;
            } elseif ($accepted > 0) {
                $updates['status'] = self::STATUS_COMPLETED;
            } elseif ($failed > 0 && $skipped === 0) {
                $updates['status'] = self::STATUS_FAILED;
            } else {
                $updates['status'] = self::STATUS_COMPLETED;
            }
            $updates['completed_at'] = $this->completed_at ?? now();
        }

        $this->forceFill($updates)->save();

        return $this;
    }

    public function present(): array
    {
        $profile = $this->providerProfile;
        $user = $this->provider;

        return [
            'id' => $this->id,
            'reference_code' => $this->reference_code,
            'provider' => [
                'id' => (int) $this->provider_user_id,
                'name' => $user?->name,
                'business_name' => $profile?->business_name ?: $user?->name,
                'city' => $profile?->city,
            ],
            'notification_type' => $this->notification_type,
            'notification_type_label' => self::TYPE_LABELS[$this->notification_type] ?? $this->notification_type,
            'source_type' => $this->source_type,
            'source_id' => $this->source_id ? (int) $this->source_id : null,
            'title' => $this->title,
            'body' => $this->body,
            'pricing_mode' => $this->pricing_mode,
            'unit_price' => (float) $this->unit_price,
            'total_cost' => (float) $this->total_cost,
            'reserved_promo_amount' => (float) $this->reserved_promo_amount,
            'reserved_cash_amount' => (float) $this->reserved_cash_amount,
            'captured_promo_amount' => (float) $this->captured_promo_amount,
            'captured_cash_amount' => (float) $this->captured_cash_amount,
            'refunded_promo_amount' => (float) $this->refunded_promo_amount,
            'refunded_cash_amount' => (float) $this->refunded_cash_amount,
            'balance_source' => $this->balance_source,
            'balance_source_label' => self::SOURCE_LABELS[$this->balance_source] ?? $this->balance_source,
            'targeted_count' => (int) $this->targeted_count,
            'eligible_count' => (int) $this->eligible_count,
            'attempted_count' => (int) $this->attempted_count,
            'fcm_accepted_count' => (int) $this->fcm_accepted_count,
            'failed_count' => (int) $this->failed_count,
            'skipped_count' => (int) $this->skipped_count,
            'status' => $this->status,
            'status_label' => self::STATUS_LABELS[$this->status] ?? $this->status,
            'status_reason' => $this->status_reason,
            'sent_at' => $this->sent_at?->toISOString(),
            'completed_at' => $this->completed_at?->toISOString(),
            'created_at' => $this->created_at?->toISOString(),
        ];
    }
}
