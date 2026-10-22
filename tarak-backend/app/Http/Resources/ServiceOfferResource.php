<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ServiceOfferResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $providerUser = $this->provider;
        $profile = $providerUser?->providerProfile;

        return [
            'id' => $this->id,
            'service_request_id' => $this->service_request_id,
            'provider_user_id' => $this->provider_user_id,
            'price' => (float) $this->price,
            'duration_minutes' => (int) $this->duration_minutes,
            'estimated_arrival_min' => $this->estimated_arrival_min !== null ? (int) $this->estimated_arrival_min : null,
            'payment_preference' => $this->payment_preference,
            'message' => $this->message,
            'status' => $this->status,
            'accepted_at' => $this->accepted_at?->toISOString(),
            'rejected_at' => $this->rejected_at?->toISOString(),
            'created_at' => $this->created_at?->toISOString(),
            'provider' => $this->when($providerUser !== null, function () use ($providerUser, $profile) {
                return [
                    'id' => $providerUser->id,
                    'name' => $providerUser->name,
                    'business_name' => $profile?->business_name ?: $providerUser->name,
                    'provider_type' => $profile?->provider_type ?: 'barber',
                    'city' => $profile?->city,
                    'district' => $profile?->district,
                    'experience_years' => $profile?->experience_years,
                    'is_verified' => $profile?->isVerified() ?? false,
                    'avatar_url' => $providerUser->avatar_url,
                ];
            }),
            'service_request' => $this->whenLoaded('serviceRequest', function () {
                return new ProviderMarketplaceRequestResource($this->serviceRequest);
            }),
        ];
    }
}
