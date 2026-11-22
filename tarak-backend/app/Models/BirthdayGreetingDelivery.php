<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class BirthdayGreetingDelivery extends Model
{
    use HasFactory;

    protected $fillable = [
        'provider_profile_id',
        'customer_user_id',
        'birthday_year',
        'days_before',
        'celebration_date',
        'sent_at',
        'user_notification_id',
        'dispatch_id',
        'unit_price',
        'charged_amount',
        'promo_amount',
        'cash_amount',
        'balance_source',
        'billing_status',
        'delivery_status',
        'failure_reason',
        'title_snapshot',
        'message_snapshot',
    ];

    protected function casts(): array
    {
        return [
            'birthday_year' => 'integer',
            'days_before' => 'integer',
            'celebration_date' => 'date:Y-m-d',
            'sent_at' => 'datetime',
            'unit_price' => 'decimal:2',
            'charged_amount' => 'decimal:2',
            'promo_amount' => 'decimal:2',
            'cash_amount' => 'decimal:2',
        ];
    }

    public function providerProfile(): BelongsTo
    {
        return $this->belongsTo(ProviderProfile::class);
    }

    public function customer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'customer_user_id');
    }

    public function notification(): BelongsTo
    {
        return $this->belongsTo(UserNotification::class, 'user_notification_id');
    }

    public function dispatch(): BelongsTo
    {
        return $this->belongsTo(NotificationDispatch::class, 'dispatch_id');
    }
}
