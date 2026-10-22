<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;

class Service extends Model
{
    use HasFactory;

    protected $fillable = [
        'id',
        'category_id',
        'name',
        'slug',
        'description',
        'duration_minutes',
        'base_price',
        'icon_class',
        'is_active',
        'sort_order',
    ];

    protected function casts(): array
    {
        return [
            'duration_minutes' => 'integer',
            'base_price' => 'decimal:2',
            'is_active' => 'boolean',
            'sort_order' => 'integer',
        ];
    }

    public function category(): BelongsTo
    {
        return $this->belongsTo(ServiceCategory::class, 'category_id', 'id');
    }

    public function providers(): BelongsToMany
    {
        return $this->belongsToMany(ProviderProfile::class, 'provider_services')
            ->withPivot('id', 'custom_price', 'custom_duration_minutes', 'description', 'is_active')
            ->withTimestamps();
    }
}
