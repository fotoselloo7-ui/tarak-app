<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ProviderProfileResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => (string) $this->id,
            'user_id' => (string) $this->user_id,
            'provider_type' => $this->provider_type,
            'work_mode' => $this->work_mode,
            'business_name' => $this->business_name,
            'is_approved' => (bool) $this->is_approved,
            'identity_status' => $this->identity_status,
            'is_online' => (bool) $this->is_online,
            'accepts_new_clients' => (bool) $this->accepts_new_clients,
            'service_radius_km' => (int) $this->service_radius_km,
            'experience_years' => $this->experience_years !== null ? (int) $this->experience_years : null,
            'profile_completed' => (bool) $this->profile_completed,
            'city' => $this->city,
            'district' => $this->district,
            'address_detail' => $this->address_detail,
            // Exact pin is returned only to its owner for secure map edits.
            'latitude' => (int) ($request->user()?->id ?? 0) === (int) $this->user_id && $this->latitude !== null ? (float) $this->latitude : null,
            'longitude' => (int) ($request->user()?->id ?? 0) === (int) $this->user_id && $this->longitude !== null ? (float) $this->longitude : null,
            'bio' => $this->bio,
            'title' => $this->title,
            // Canonical avatar lives on users.avatar_url (shared with customer).
            'avatar_url' => $this->user?->avatar_url,
            'cover_url' => $this->cover_url,
            'cover_position_x' => (int) $this->cover_position_x,
            'cover_position_y' => (int) $this->cover_position_y,
            'gallery' => $this->gallery ?? [],
            'commission_rate_override' => $this->commission_rate_override !== null ? (float) $this->commission_rate_override : null,
            'rejection_reason' => $this->rejection_reason,
            'reupload_reason' => $this->reupload_reason,
            'has_received_welcome_bonus' => (bool) $this->has_received_welcome_bonus,
            'approved_at' => $this->approved_at?->toISOString(),
            'reviewed_at' => $this->reviewed_at?->toISOString(),
            'is_verified' => $this->isVerified(),
            'services' => ProviderServiceResource::collection($this->whenLoaded('providerServices')),
            'documents' => ProviderDocumentResource::collection($this->whenLoaded('documents')),
        ];
    }
}
