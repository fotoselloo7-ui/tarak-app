<?php

namespace App\Http\Requests;

use App\Models\LocationShareGrant;

class ShareLocationRequest extends BaseFormRequest
{
    public function rules(): array
    {
        return [
            'explicit_consent' => [
                'required',
                function ($attribute, $value, $fail) {
                    if ($value !== true && $value !== 1 && $value !== '1' && $value !== 'true') {
                        $fail('Açık müşteri onayı (explicit_consent = true) zorunludur.');
                    }
                },
            ],
            'source' => [
                'required',
                'string',
                'in:' . LocationShareGrant::SOURCE_SAVED_ADDRESS . ',' . LocationShareGrant::SOURCE_CURRENT_LOCATION,
            ],
            'customer_address_id' => [
                'nullable',
                'integer',
            ],
            'latitude' => [
                'nullable',
                'numeric',
                'between:-90,90',
            ],
            'longitude' => [
                'nullable',
                'numeric',
                'between:-180,180',
            ],
            'current_location' => [
                'nullable',
                'array',
            ],
            'current_location.latitude' => [
                'nullable',
                'numeric',
                'between:-90,90',
            ],
            'current_location.longitude' => [
                'nullable',
                'numeric',
                'between:-180,180',
            ],
        ];
    }

    public function withValidator($validator)
    {
        $validator->after(function ($validator) {
            $source = $this->input('source');
            if ($source === LocationShareGrant::SOURCE_CURRENT_LOCATION) {
                $lat = $this->input('latitude') ?? $this->input('current_location.latitude');
                $lng = $this->input('longitude') ?? $this->input('current_location.longitude');

                if ($lat === null || $lat === '' || !is_numeric($lat)) {
                    $validator->errors()->add('latitude', 'Mevcut konum için geçerli sayısal bir enlem (latitude) zorunludur.');
                }
                if ($lng === null || $lng === '' || !is_numeric($lng)) {
                    $validator->errors()->add('longitude', 'Mevcut konum için geçerli sayısal bir boylam (longitude) zorunludur.');
                }
            }
        });
    }

    public function getCoordinates(): ?array
    {
        $lat = $this->input('latitude') ?? $this->input('current_location.latitude');
        $lng = $this->input('longitude') ?? $this->input('current_location.longitude');

        if ($lat !== null && $lng !== null && is_numeric($lat) && is_numeric($lng)) {
            return [
                'latitude' => (float) $lat,
                'longitude' => (float) $lng,
            ];
        }

        return null;
    }
}
