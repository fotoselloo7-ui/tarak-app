<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ProviderWeeklySchedule extends Model
{
    use HasFactory;

    protected $fillable = [
        'provider_profile_id',
        'day_of_week',
        'is_enabled',
        'start_time',
        'end_time',
    ];

    protected $casts = [
        'is_enabled' => 'boolean',
    ];

    public function providerProfile()
    {
        return $this->belongsTo(ProviderProfile::class, 'provider_profile_id');
    }

    public function breaks()
    {
        return $this->hasMany(ProviderScheduleBreak::class, 'weekly_schedule_id');
    }
}
