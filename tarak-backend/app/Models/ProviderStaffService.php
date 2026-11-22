<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ProviderStaffService extends Model
{
    use HasFactory;

    protected $fillable = [
        'provider_staff_id',
        'service_id',
        'custom_duration_minutes',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'custom_duration_minutes' => 'integer',
            'is_active' => 'boolean',
        ];
    }

    public function staff(): BelongsTo
    {
        return $this->belongsTo(ProviderStaff::class, 'provider_staff_id');
    }

    public function service(): BelongsTo
    {
        return $this->belongsTo(Service::class);
    }
}
