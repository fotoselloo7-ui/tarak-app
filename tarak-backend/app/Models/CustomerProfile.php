<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CustomerProfile extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'profile_completed',
        'birth_date',
        'avatar_url',
    ];

    protected function casts(): array
    {
        return [
            'profile_completed' => 'boolean',
            'birth_date' => 'date',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function addresses(): \Illuminate\Database\Eloquent\Relations\HasMany
    {
        return $this->hasMany(CustomerAddress::class);
    }

    public function defaultAddress(): \Illuminate\Database\Eloquent\Relations\HasOne
    {
        return $this->hasOne(CustomerAddress::class)->where('is_default', true);
    }
}
