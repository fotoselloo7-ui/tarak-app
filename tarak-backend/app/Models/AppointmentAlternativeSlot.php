<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class AppointmentAlternativeSlot extends Model
{
    use HasFactory;

    protected $fillable = [
        'appointment_id',
        'date',
        'start_time',
        'end_time',
        'status',
    ];

    protected $casts = [
        'date' => 'date:Y-m-d',
    ];

    public function appointment()
    {
        return $this->belongsTo(Appointment::class, 'appointment_id');
    }
}
