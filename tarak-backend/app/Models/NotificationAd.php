<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasOne;

/** One paid "bildirim reklamı": the copy, the audience, the discount it carries and how it went out. */
class NotificationAd extends Model
{
    public const AUDIENCE_SERVICE_AREA = 'service_area';
    public const AUDIENCE_LOCATION = 'location';
    public const AUDIENCE_ALL = 'all';
    public const AUDIENCES = [self::AUDIENCE_SERVICE_AREA, self::AUDIENCE_LOCATION, self::AUDIENCE_ALL];
    public const AUDIENCE_NAMES = [
        self::AUDIENCE_SERVICE_AREA => 'Hizmet bölgem',
        self::AUDIENCE_LOCATION => 'Seçtiğim konum',
        self::AUDIENCE_ALL => 'Tüm kullanıcılar',
    ];
    public const AUDIENCE_HINTS = [
        self::AUDIENCE_SERVICE_AREA => 'Hizmet verdiğin bölgedeki (hizmet yarıçapın) müşteriler',
        self::AUDIENCE_LOCATION => 'Seçtiğin il (ve istersen ilçe) içindeki müşteriler',
        self::AUDIENCE_ALL => 'Uygulamadaki tüm müşteriler',
    ];

    public const STATUS_PENDING_PAYMENT = 'PENDING_PAYMENT';
    public const STATUS_QUEUED = 'QUEUED';
    public const STATUS_SENT = 'SENT';
    public const STATUS_FAILED = 'FAILED';
    public const STATUS_BLOCKED = 'BLOCKED';

    public const SOURCE_WALLET = 'wallet';
    public const SOURCE_CARD = 'card';

    /** PayTR merchant_oid prefix; lets the shared callback tell these orders apart. */
    public const OID_PREFIX = 'NA';

    public const TITLE_MAX = 50;
    public const BODY_MAX = 120;

    protected $fillable = [
        'provider_user_id', 'dispatch_id', 'audience', 'province', 'district', 'title', 'body', 'discount_percent', 'discount_days',
        'amount', 'promo_amount', 'cash_amount', 'balance_source', 'payment_source', 'status', 'targeted_count', 'recipients_count', 'merchant_oid', 'failure_message', 'user_ip',
        'paid_at', 'sent_at', 'callback_payload',
    ];

    protected function casts(): array
    {
        return [
            'discount_percent' => 'integer',
            'discount_days' => 'integer',
            'amount' => 'decimal:2',
            'promo_amount' => 'decimal:2',
            'cash_amount' => 'decimal:2',
            'targeted_count' => 'integer',
            'recipients_count' => 'integer',
            'paid_at' => 'datetime',
            'sent_at' => 'datetime',
            'callback_payload' => 'array',
        ];
    }

    public function provider(): BelongsTo
    {
        return $this->belongsTo(User::class, 'provider_user_id');
    }

    public function dispatch(): BelongsTo
    {
        return $this->belongsTo(NotificationDispatch::class, 'dispatch_id');
    }

    public function discount(): HasOne
    {
        return $this->hasOne(ProviderDiscount::class, 'notification_ad_id');
    }

    public function present(): array
    {
        return [
            'id' => $this->id,
            'dispatch_id' => $this->dispatch_id,
            'audience' => $this->audience,
            'audience_name' => self::AUDIENCE_NAMES[$this->audience] ?? $this->audience,
            'province' => $this->province,
            'district' => $this->district,
            'title' => $this->title,
            'body' => $this->body,
            'discount_percent' => $this->discount_percent,
            'discount_days' => $this->discount_days,
            'amount' => (float) $this->amount,
            'promo_amount' => (float) ($this->promo_amount ?? 0),
            'cash_amount' => (float) ($this->cash_amount ?? 0),
            'balance_source' => $this->balance_source,
            'payment_source' => $this->payment_source,
            'status' => $this->status,
            'targeted_count' => (int) ($this->targeted_count ?? 0),
            'recipients_count' => $this->recipients_count,
            'failure_message' => $this->failure_message,
            'paid_at' => $this->paid_at?->toISOString(),
            'sent_at' => $this->sent_at?->toISOString(),
            'created_at' => $this->created_at?->toISOString(),
        ];
    }
}
