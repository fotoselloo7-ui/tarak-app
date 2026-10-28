<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class UserResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'role' => $this->role,
            'first_name' => $this->first_name,
            'last_name' => $this->last_name,
            'name' => $this->name,
            'email' => $this->email,
            'phone' => $this->phone,
            'gender' => $this->gender,
            'status' => $this->status,
            'is_demo' => (bool) $this->is_demo,
            'avatar_url' => $this->avatar_url,
            'phone_verified_at' => $this->phone_verified_at?->toISOString(),
            'email_verified_at' => $this->email_verified_at?->toISOString(),
            'last_login_at' => $this->last_login_at?->toISOString(),
            'created_at' => $this->created_at?->toISOString(),
            'customer_profile' => $this->when($this->relationLoaded('customerProfile') && $this->customerProfile, function () {
                return new CustomerProfileResource($this->customerProfile);
            }),
            'provider_profile' => $this->when($this->relationLoaded('providerProfile') && $this->providerProfile, function () {
                return new ProviderProfileResource($this->providerProfile);
            }),
            'wallet' => $this->when($this->relationLoaded('wallet') && $this->wallet, function () {
                return [
                    'balance' => (float) $this->wallet->balance,
                    'cash_balance' => (float) $this->wallet->balance,
                    'promo_balance' => (float) $this->wallet->promo_balance,
                    'reserved_cash_balance' => (float) $this->wallet->reserved_cash_balance,
                    'reserved_promo_balance' => (float) $this->wallet->reserved_promo_balance,
                    'usable_cash_balance' => (float) $this->wallet->usable_cash_balance,
                    'usable_promo_balance' => (float) $this->wallet->usable_promo_balance,
                    'available_for_commission' => (float) $this->wallet->usable_commission_balance,
                    'withdrawable_balance' => (float) $this->wallet->withdrawable_balance,
                    'currency' => $this->wallet->currency,
                    'is_frozen' => (bool) $this->wallet->is_frozen,
                ];
            }),
        ];
    }
}
