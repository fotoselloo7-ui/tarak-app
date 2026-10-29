<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use App\Support\MediaUrl;

class CustomerProfileResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => (string) $this->id,
            'user_id' => (string) $this->user_id,
            'profile_completed' => (bool) $this->profile_completed,
            'birth_date' => $this->birth_date?->format('Y-m-d'),
            // Canonical avatar now lives on users.avatar_url (single source
            // of truth for all roles); customer_profiles.avatar_url is legacy.
            'avatar_url' => MediaUrl::resolve($this->user?->avatar_url),
            'addresses' => CustomerAddressResource::collection($this->whenLoaded('addresses')),
            'default_address' => new CustomerAddressResource($this->whenLoaded('defaultAddress')),
        ];
    }
}
