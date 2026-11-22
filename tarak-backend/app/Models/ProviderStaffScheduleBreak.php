<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ProviderStaffScheduleBreak extends Model
{
    use HasFactory;

    protected $fillable = [
        'staff_weekly_schedule_id',
        'start_time',
        'end_time',
    ];

    public function weeklySchedule(): BelongsTo
    {
        return $this->belongsTo(ProviderStaffWeeklySchedule::class, 'staff_weekly_schedule_id');
    }
}
