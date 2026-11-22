<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class ProviderStaffWeeklySchedule extends Model
{
    use HasFactory;

    protected $fillable = [
        'provider_staff_id',
        'day_of_week',
        'is_enabled',
        'start_time',
        'end_time',
    ];

    protected function casts(): array
    {
        return [
            'is_enabled' => 'boolean',
        ];
    }

    public function staff(): BelongsTo
    {
        return $this->belongsTo(ProviderStaff::class, 'provider_staff_id');
    }

    public function breaks(): HasMany
    {
        return $this->hasMany(ProviderStaffScheduleBreak::class, 'staff_weekly_schedule_id');
    }
}
