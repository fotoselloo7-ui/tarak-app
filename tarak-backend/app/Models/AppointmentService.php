<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class AppointmentService extends Model
{
    use HasFactory;

    protected $fillable = [
        'appointment_id',
        'service_id',
        'price_snapshot',
        'duration_minutes_snapshot',
    ];

    protected $casts = [
        'price_snapshot' => 'decimal:2',
        'duration_minutes_snapshot' => 'integer',
    ];

    public function appointment()
    {
        return $this->belongsTo(Appointment::class, 'appointment_id');
    }

    public function service()
    {
        return $this->belongsTo(Service::class, 'service_id');
    }
}
