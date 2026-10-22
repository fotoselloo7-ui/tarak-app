<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

/** An admin-priced "öne çıkarma" package (duration + price). */
class FeaturedPackage extends Model
{
    protected $fillable = [
        'placement',
        'name',
        'description',
        'badge',
        'duration_days',
        'price',
        'is_active',
        'sort_order',
    ];

    protected function casts(): array
    {
        return [
            'duration_days' => 'integer',
            'price' => 'decimal:2',
            'is_active' => 'boolean',
            'sort_order' => 'integer',
        ];
    }

    public function scopePlacement(Builder $query, string $placement): Builder
    {
        return $query->where('placement', $placement);
    }

    public function promotions(): HasMany
    {
        return $this->hasMany(FeaturedPromotion::class);
    }

    /** Public / provider-facing shape. */
    public function present(): array
    {
        return [
            'id' => $this->id,
            'placement' => $this->placement ?: FeaturedPromotion::PLACEMENT_HOME,
            'name' => $this->name,
            'description' => $this->description,
            'badge' => $this->badge,
            'duration_days' => $this->duration_days,
            'price' => (float) $this->price,
            'is_active' => $this->is_active,
            'sort_order' => $this->sort_order,
        ];
    }
}
