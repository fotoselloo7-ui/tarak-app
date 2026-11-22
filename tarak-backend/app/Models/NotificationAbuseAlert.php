<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class NotificationAbuseAlert extends Model
{
    use HasFactory;

    public const TYPE_RAPID_CAMPAIGNS = 'RAPID_CAMPAIGNS';
    public const TYPE_REPEATED_SAME_RECIPIENT = 'REPEATED_SAME_RECIPIENT';
    public const TYPE_DUPLICATE_CONTENT = 'DUPLICATE_CONTENT';
    public const TYPE_UNAUTHORIZED_MARKETING = 'UNAUTHORIZED_MARKETING';
    public const TYPE_BIRTHDAY_OPT_OUT_ATTEMPT = 'BIRTHDAY_OPT_OUT_ATTEMPT';
    public const TYPE_BLOCKED_PROVIDER_QUEUE_STOPPED = 'BLOCKED_PROVIDER_QUEUE_STOPPED';
    public const TYPE_INSUFFICIENT_BALANCE_ATTEMPT = 'INSUFFICIENT_BALANCE_ATTEMPT';
    public const TYPE_UNAUTHORIZED_PII_ACCESS = 'UNAUTHORIZED_PII_ACCESS';
    public const TYPE_DAILY_LIMIT_EXCEEDED = 'DAILY_LIMIT_EXCEEDED';

    public const TYPE_LABELS = [
        self::TYPE_RAPID_CAMPAIGNS => 'Kısa Sürede Aşırı Kampanya',
        self::TYPE_REPEATED_SAME_RECIPIENT => 'Aynı Müşteriye Tekrarlı Bildirim',
        self::TYPE_DUPLICATE_CONTENT => 'Aynı İçerikle Sürekli Gönderim',
        self::TYPE_UNAUTHORIZED_MARKETING => 'İzinsiz Pazarlama İçeriği Girişimi',
        self::TYPE_BIRTHDAY_OPT_OUT_ATTEMPT => 'Doğum Günü İzni Kapalı Müşteriye Girişim',
        self::TYPE_BLOCKED_PROVIDER_QUEUE_STOPPED => 'Engelli İşletme Kuyruk İşi Durduruldu',
        self::TYPE_INSUFFICIENT_BALANCE_ATTEMPT => 'Yetersiz Bakiye ile Gönderim Girişimi',
        self::TYPE_UNAUTHORIZED_PII_ACCESS => 'Yetkisiz Kayıt / Kişisel Veri Erişimi',
        self::TYPE_DAILY_LIMIT_EXCEEDED => 'Günlük Gönderim / Alıcı Sınırı Aşıldı',
    ];

    public const STATUS_OPEN = 'OPEN';
    public const STATUS_RESOLVED = 'RESOLVED';

    protected $fillable = [
        'provider_user_id',
        'dispatch_id',
        'alert_type',
        'severity',
        'summary',
        'details',
        'auto_action_taken',
        'status',
        'resolved_by_admin_id',
        'resolved_at',
    ];

    protected function casts(): array
    {
        return [
            'details' => 'array',
            'resolved_at' => 'datetime',
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

    public function resolvedByAdmin(): BelongsTo
    {
        return $this->belongsTo(User::class, 'resolved_by_admin_id');
    }

    public function present(): array
    {
        $user = $this->provider;
        $profile = $user?->providerProfile;

        return [
            'id' => $this->id,
            'provider_user_id' => $this->provider_user_id ? (int) $this->provider_user_id : null,
            'provider_name' => $profile?->business_name ?: $user?->name,
            'dispatch_id' => $this->dispatch_id ? (int) $this->dispatch_id : null,
            'alert_type' => $this->alert_type,
            'alert_type_label' => self::TYPE_LABELS[$this->alert_type] ?? $this->alert_type,
            'severity' => $this->severity,
            'summary' => $this->summary,
            'details' => $this->details,
            'auto_action_taken' => $this->auto_action_taken,
            'status' => $this->status,
            'resolved_at' => $this->resolved_at?->toISOString(),
            'created_at' => $this->created_at?->toISOString(),
        ];
    }
}
