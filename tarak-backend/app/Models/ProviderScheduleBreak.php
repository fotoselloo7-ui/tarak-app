<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ProviderScheduleBreak extends Model
{
    use HasFactory;

    protected $fillable = [
        'weekly_schedule_id',
        'start_time',
        'end_time',
    ];

    public function weeklySchedule()
    {
        return $this->belongsTo(ProviderWeeklySchedule::class, 'weekly_schedule_id');
    }
}
