<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;

class ProviderPackage extends Model
{
    protected $table = 'provider_packages';

    protected $fillable = [
        'provider_profile_id',
        'title',
        'description',
        'price',
        'duration_minutes',
        'is_active',
        'sort_order',
    ];

    protected function casts(): array
    {
        return [
            'price' => 'decimal:2',
            'duration_minutes' => 'integer',
            'is_active' => 'boolean',
            'sort_order' => 'integer',
        ];
    }

    public function providerProfile(): BelongsTo
    {
        return $this->belongsTo(ProviderProfile::class);
    }

    public function services(): BelongsToMany
    {
        return $this->belongsToMany(Service::class, 'provider_package_items')
            ->withPivot('sort_order')
            ->withTimestamps()
            ->orderBy('provider_package_items.sort_order');
    }
}
