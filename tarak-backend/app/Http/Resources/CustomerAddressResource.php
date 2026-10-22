<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class CustomerAddressResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => (string) $this->id,
            'title' => $this->title,
            'province' => $this->province,
            'city' => $this->province, // Alias
            'district' => $this->district,
            'neighborhood' => $this->neighborhood,
            'street' => $this->street,
            'building_no' => $this->building_no,
            'apartment_no' => $this->apartment_no,
            'directions' => $this->directions,
            'latitude' => $this->latitude ? (float) $this->latitude : null,
            'longitude' => $this->longitude ? (float) $this->longitude : null,
            'is_default' => (bool) $this->is_default,
            'created_at' => $this->created_at?->toISOString(),
            'updated_at' => $this->updated_at?->toISOString(),
        ];
    }
}
