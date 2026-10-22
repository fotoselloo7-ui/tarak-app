<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CommissionReservation extends Model
{
    use HasFactory;

    protected $table = 'commission_reservations';

    public const STATUS_RESERVED = 'RESERVED';
    public const STATUS_CAPTURED = 'CAPTURED';
    public const STATUS_RELEASED = 'RELEASED';
    public const STATUS_HELD_DISPUTE = 'HELD_DISPUTE';

    public const RESOURCE_INSTANT_REQUEST = 'INSTANT_REQUEST';
    public const RESOURCE_SCHEDULED_APPOINTMENT = 'SCHEDULED_APPOINTMENT';

    protected $fillable = [
        'resource_type',
        'resource_id',
        'provider_user_id',
        'payment_method',
        'gross_amount',
        'commission_rate',
        'commission_amount',
        'reserved_cash_amount',
        'reserved_promo_amount',
        'status',
        'reserved_at',
        'captured_at',
        'released_at',
        'held_dispute_at',
    ];

    protected function casts(): array
    {
        return [
            'gross_amount' => 'decimal:2',
            'commission_rate' => 'decimal:2',
            'commission_amount' => 'decimal:2',
            'reserved_cash_amount' => 'decimal:2',
            'reserved_promo_amount' => 'decimal:2',
            'reserved_at' => 'datetime',
            'captured_at' => 'datetime',
            'released_at' => 'datetime',
            'held_dispute_at' => 'datetime',
        ];
    }

    public function provider(): BelongsTo
    {
        return $this->belongsTo(User::class, 'provider_user_id');
    }
}
