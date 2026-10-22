<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ProviderService extends Model
{
    use HasFactory;

    protected $table = 'provider_services';

    protected $fillable = [
        'provider_profile_id',
        'service_id',
        'custom_price',
        'custom_duration_minutes',
        'description',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'custom_price' => 'decimal:2',
            'custom_duration_minutes' => 'integer',
            'is_active' => 'boolean',
        ];
    }

    public function providerProfile(): BelongsTo
    {
        return $this->belongsTo(ProviderProfile::class);
    }

    public function service(): BelongsTo
    {
        return $this->belongsTo(Service::class);
    }

    public function effectivePrice(): float
    {
        return $this->custom_price !== null ? (float) $this->custom_price : (float) ($this->service?->base_price ?? 0);
    }

    public function effectiveDurationMinutes(): int
    {
        return $this->custom_duration_minutes !== null ? (int) $this->custom_duration_minutes : (int) ($this->service?->duration_minutes ?? 30);
    }
}
