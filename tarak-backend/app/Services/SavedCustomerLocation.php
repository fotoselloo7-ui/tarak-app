<?php

namespace App\Services;

use App\Models\CustomerAddress;
use App\Models\User;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Validation\ValidationException;

/** Resolves only the chosen owned address, never another old address. */
class SavedCustomerLocation
{
    public function resolve(User $user, ?int $addressId = null): CustomerAddress
    {
        $query = CustomerAddress::where('customer_profile_id', $user->customerProfile?->id ?? 0);
        $address = $addressId !== null ? $query->whereKey($addressId)->first() : $query->where('is_default', true)->first();
        if (!$address) {
            if ($addressId !== null) throw new AuthorizationException('Seçilen kayıtlı adres hesabınıza ait değil.');
            throw ValidationException::withMessages(['customer_address_id' => 'Önce varsayılan kayıtlı adresinizi seçin.']);
        }
        if (!$this->hasCoordinates($address)) {
            $text = implode(', ', array_filter([$address->street, $address->building_no,
                $address->neighborhood, $address->district, $address->province, 'Türkiye']));
            $result = app(GoogleGeocodingService::class)->search($text);
            if (($result['status'] ?? null) === 'OK') {
                $address->latitude = $result['data']['latitude'] ?? null;
                $address->longitude = $result['data']['longitude'] ?? null;
                if ($this->hasCoordinates($address)) $address->save();
            }
        }
        if (!$this->hasCoordinates($address)) {
            throw ValidationException::withMessages(['customer_address_id' => 'Seçtiğiniz adresin harita konumunu kaydedin. Başka bir adresin konumu kullanılamaz.']);
        }
        return $address;
    }

    private function hasCoordinates(CustomerAddress $address): bool
    {
        return $address->latitude !== null && $address->longitude !== null
            && abs((float) $address->latitude) <= 90 && abs((float) $address->longitude) <= 180
            && ((float) $address->latitude !== 0.0 || (float) $address->longitude !== 0.0);
    }
}
