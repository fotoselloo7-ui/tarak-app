<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ProviderClosedDate extends Model
{
    use HasFactory;

    protected $fillable = [
        'provider_profile_id',
        'date',
        'reason',
        'note',
    ];

    protected $casts = [
        'date' => 'date:Y-m-d',
    ];

    public function providerProfile()
    {
        return $this->belongsTo(ProviderProfile::class, 'provider_profile_id');
    }
}
