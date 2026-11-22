<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ProviderStaffTimeOff extends Model
{
    use HasFactory;

    protected $fillable = [
        'provider_staff_id',
        'start_date',
        'end_date',
        'start_time',
        'end_time',
        'reason',
        'note',
    ];

    protected function casts(): array
    {
        return [
            'start_date' => 'date:Y-m-d',
            'end_date' => 'date:Y-m-d',
        ];
    }

    public function staff(): BelongsTo
    {
        return $this->belongsTo(ProviderStaff::class, 'provider_staff_id');
    }
}
