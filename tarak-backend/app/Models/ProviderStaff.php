<?php

namespace App\Models;

use App\Support\MediaUrl;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;

class ProviderStaff extends Model
{
    use HasFactory;

    protected $table = 'provider_staff';

    protected $fillable = [
        'provider_profile_id',
        'first_name',
        'last_name',
        'photo_url',
        'title',
        'specialty',
        'is_active',
        'accepts_appointments',
        'visible_to_customers',
        'sort_order',
        'archived_at',
    ];

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
            'accepts_appointments' => 'boolean',
            'visible_to_customers' => 'boolean',
            'sort_order' => 'integer',
            'archived_at' => 'datetime',
        ];
    }

    public function getFullNameAttribute(): string
    {
        return trim($this->first_name . ' ' . $this->last_name);
    }

    public function getResolvedPhotoUrlAttribute(): ?string
    {
        return MediaUrl::resolve($this->photo_url);
    }

    public function providerProfile(): BelongsTo
    {
        return $this->belongsTo(ProviderProfile::class);
    }

    public function staffServices(): HasMany
    {
        return $this->hasMany(ProviderStaffService::class, 'provider_staff_id');
    }

    public function services(): BelongsToMany
    {
        return $this->belongsToMany(Service::class, 'provider_staff_services')
            ->withPivot(['custom_duration_minutes', 'is_active'])
            ->withTimestamps();
    }

    public function weeklySchedules(): HasMany
    {
        return $this->hasMany(ProviderStaffWeeklySchedule::class, 'provider_staff_id');
    }

    public function timeOffs(): HasMany
    {
        return $this->hasMany(ProviderStaffTimeOff::class, 'provider_staff_id');
    }

    public function appointments(): HasMany
    {
        return $this->hasMany(Appointment::class, 'staff_id');
    }

    public function scopeActive(Builder $query): Builder
    {
        return $query->where('is_active', true)->whereNull('archived_at');
    }

    public function scopeBookable(Builder $query): Builder
    {
        return $query->active()->where('accepts_appointments', true);
    }

    public function scopeCustomerVisible(Builder $query): Builder
    {
        return $query->bookable()->where('visible_to_customers', true);
    }
}
