<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ServiceResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => (string) $this->id,
            'category_id' => $this->category_id,
            'name' => $this->name,
            'slug' => $this->slug,
            'description' => $this->description,
            'duration_minutes' => (int) $this->duration_minutes,
            'defaultDurationMin' => (int) $this->duration_minutes, // Frontend compatibility alias
            'base_price' => (float) $this->base_price,
            'icon_class' => $this->icon_class,
            'is_active' => (bool) $this->is_active,
            'isActive' => (bool) $this->is_active, // Frontend compatibility alias
            'sort_order' => (int) $this->sort_order,
            'order' => (int) $this->sort_order, // Frontend compatibility alias
        ];
    }
}
