<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PaymentGatewayAttempt extends Model
{
    use HasFactory;

    protected $table = 'payment_gateway_attempts';

    public const STATUS_CREATED = 'CREATED';
    public const STATUS_TOKEN_READY = 'TOKEN_READY';
    public const STATUS_SUCCESS = 'SUCCESS';
    public const STATUS_FAILED = 'FAILED';

    protected $fillable = [
        'service_payment_id',
        'gateway',
        'merchant_oid',
        'status',
        'payment_amount_minor',
        'currency',
        'user_ip',
        'user_basket',
        'failure_code',
        'failure_message',
        'callback_received_at',
        'callback_payload',
    ];

    protected function casts(): array
    {
        return [
            'payment_amount_minor' => 'integer',
            'user_basket' => 'array',
            'callback_payload' => 'array',
            'callback_received_at' => 'datetime',
        ];
    }

    public function servicePayment(): BelongsTo
    {
        return $this->belongsTo(ServicePayment::class, 'service_payment_id');
    }
}
