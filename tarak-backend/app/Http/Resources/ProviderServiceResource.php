<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ProviderServiceResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $service = $this->whenLoaded('service') ?? $this->resource->service;

        return [
            'id' => (string) $this->id,
            'service_id' => (string) $this->service_id,
            'name' => $service?->name,
            'category_id' => $service?->category_id,
            'custom_price' => $this->custom_price !== null ? (float) $this->custom_price : ($service ? (float) $service->base_price : 0.0),
            'price' => $this->custom_price !== null ? (float) $this->custom_price : ($service ? (float) $service->base_price : 0.0), // Alias
            'custom_duration_minutes' => $this->custom_duration_minutes !== null ? (int) $this->custom_duration_minutes : ($service ? (int) $service->duration_minutes : 30),
            'duration_min' => $this->custom_duration_minutes !== null ? (int) $this->custom_duration_minutes : ($service ? (int) $service->duration_minutes : 30), // Alias
            'description' => $this->description,
            'is_active' => (bool) $this->is_active,
            'service' => $service ? new ServiceResource($service) : null,
        ];
    }
}
