<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ProviderReview extends Model
{
    protected $fillable = [
        'provider_user_id',
        'customer_user_id',
        'appointment_id',
        'service_request_id',
        'rating',
        'comment',
    ];

    protected function casts(): array
    {
        return ['rating' => 'integer'];
    }

    public function provider(): BelongsTo
    {
        return $this->belongsTo(User::class, 'provider_user_id');
    }

    public function customer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'customer_user_id');
    }
}
