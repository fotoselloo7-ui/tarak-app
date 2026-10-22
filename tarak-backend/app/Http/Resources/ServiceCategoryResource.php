<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ServiceCategoryResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'slug' => $this->slug,
            'icon' => $this->icon,
            'provider_type' => $this->provider_type,
            'is_active' => (bool) $this->is_active,
            'sort_order' => (int) $this->sort_order,
            'services' => ServiceResource::collection($this->whenLoaded('services')),
        ];
    }
}
