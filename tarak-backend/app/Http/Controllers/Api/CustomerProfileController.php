<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\CustomerAddressResource;
use App\Http\Resources\CustomerProfileResource;
use App\Http\Resources\UserResource;
use App\Models\CustomerAddress;
use App\Models\CustomerProfile;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class CustomerProfileController extends Controller
{
    /**
     * Get authenticated customer's profile with addresses.
     */
    public function getProfile(Request $request): JsonResponse
    {
        $user = $request->user();
        $profile = $user->customerProfile()
            ->with(['addresses', 'defaultAddress'])
            ->firstOrCreate(['user_id' => $user->id]);

        return response()->json([
            'success' => true,
            'data' => [
                'user' => new UserResource($user->load(['customerProfile.addresses', 'customerProfile.defaultAddress'])),
                'profile' => new CustomerProfileResource($profile),
            ],
        ]);
    }

    /**
     * Update customer profile and complete onboarding.
     */
    public function updateProfile(Request $request): JsonResponse
    {
        $user = $request->user();
        $profile = $user->customerProfile()->firstOrCreate(['user_id' => $user->id]);

        $validated = $request->validate([
            'first_name' => ['sometimes', 'required', 'string', 'max:50'],
            'last_name' => ['sometimes', 'required', 'string', 'max:50'],
            'gender' => ['nullable', 'string', 'in:male,female,other,unspecified'],
            'birth_date' => ['nullable', 'date'],
            'avatar_url' => ['nullable', 'string', 'max:500'],
            // Optional nested address during onboarding
            'address' => ['nullable', 'array'],
            'address.title' => ['nullable', 'string', 'max:50'],
            'address.province' => ['required_with:address', 'string', 'max:100'],
            'address.district' => ['required_with:address', 'string', 'max:100'],
            'address.neighborhood' => ['nullable', 'string', 'max:150'],
            'address.street' => ['nullable', 'string', 'max:200'],
            'address.building_no' => ['nullable', 'string', 'max:30'],
            'address.apartment_no' => ['nullable', 'string', 'max:30'],
            'address.directions' => ['nullable', 'string'],
            'address.latitude' => ['nullable', 'required_with:address.longitude', 'numeric', 'between:-90,90'],
            'address.longitude' => ['nullable', 'required_with:address.latitude', 'numeric', 'between:-180,180'],
        ], [
            'first_name.required' => 'Ad alanı zorunludur.',
            'last_name.required' => 'Soyad alanı zorunludur.',
            'address.province.required_with' => 'İl seçimi zorunludur.',
            'address.district.required_with' => 'İlçe seçimi zorunludur.',
        ]);

        DB::transaction(function () use ($user, $profile, $validated) {
            // Update User fields
            $userUpdates = [];
            if (isset($validated['first_name'])) {
                $userUpdates['first_name'] = $validated['first_name'];
            }
            if (isset($validated['last_name'])) {
                $userUpdates['last_name'] = $validated['last_name'];
            }
            if (isset($validated['first_name']) || isset($validated['last_name'])) {
                $fn = $validated['first_name'] ?? $user->first_name;
                $ln = $validated['last_name'] ?? $user->last_name;
                $userUpdates['name'] = trim($fn . ' ' . $ln);
            }
            if (isset($validated['gender'])) {
                $userUpdates['gender'] = $validated['gender'];
            }
            if (!empty($userUpdates)) {
                $user->update($userUpdates);
            }

            // Update CustomerProfile fields
            $profileUpdates = [];
            if (array_key_exists('birth_date', $validated)) {
                $profileUpdates['birth_date'] = $validated['birth_date'];
            }
            if (array_key_exists('avatar_url', $validated)) {
                $profileUpdates['avatar_url'] = $validated['avatar_url'];
            }

            // If address provided, create or update default address
            if (!empty($validated['address'])) {
                $addrData = $validated['address'];
                $defaultAddr = $profile->defaultAddress()->first();
                if ($defaultAddr) {
                    $defaultAddr->update([
                        'title' => $addrData['title'] ?? $defaultAddr->title ?? 'Ev',
                        'province' => $addrData['province'],
                        'district' => $addrData['district'],
                        'neighborhood' => $addrData['neighborhood'] ?? null,
                        'street' => $addrData['street'] ?? null,
                        'building_no' => $addrData['building_no'] ?? null,
                        'apartment_no' => $addrData['apartment_no'] ?? null,
                        'directions' => $addrData['directions'] ?? null,
                        'latitude' => $addrData['latitude'] ?? null,
                        'longitude' => $addrData['longitude'] ?? null,
                        'is_default' => true,
                    ]);
                } else {
                    $profile->addresses()->create([
                        'title' => $addrData['title'] ?? 'Ev',
                        'province' => $addrData['province'],
                        'district' => $addrData['district'],
                        'neighborhood' => $addrData['neighborhood'] ?? null,
                        'street' => $addrData['street'] ?? null,
                        'building_no' => $addrData['building_no'] ?? null,
                        'apartment_no' => $addrData['apartment_no'] ?? null,
                        'directions' => $addrData['directions'] ?? null,
                        'latitude' => $addrData['latitude'] ?? null,
                        'longitude' => $addrData['longitude'] ?? null,
                        'is_default' => true,
                    ]);
                }
            }

            // Check Onboarding Completion Criteria
            // Required: first_name, last_name, gender, at least 1 address
            $hasAddress = $profile->addresses()->exists();
            $isComplete = !empty($user->first_name)
                && !empty($user->last_name)
                && $user->gender !== null
                && $hasAddress;

            $profileUpdates['profile_completed'] = $isComplete;
            $profile->update($profileUpdates);
        });

        $user->load(['customerProfile.addresses', 'customerProfile.defaultAddress']);

        return response()->json([
            'success' => true,
            'message' => 'Profil başarıyla güncellendi.',
            'data' => [
                'user' => new UserResource($user),
                'profile' => new CustomerProfileResource($user->customerProfile),
            ],
        ]);
    }

    /**
     * List all customer saved addresses.
     */
    public function getAddresses(Request $request): JsonResponse
    {
        $user = $request->user();
        $profile = $user->customerProfile()->firstOrCreate(['user_id' => $user->id]);
        $addresses = $profile->addresses()->orderByDesc('is_default')->latest()->get();

        return response()->json([
            'success' => true,
            'data' => CustomerAddressResource::collection($addresses),
        ]);
    }

    /**
     * Store new saved address for customer.
     */
    public function storeAddress(Request $request): JsonResponse
    {
        $user = $request->user();
        $profile = $user->customerProfile()->firstOrCreate(['user_id' => $user->id]);

        $validated = $request->validate([
            'title' => ['nullable', 'string', 'max:50'],
            'province' => ['required', 'string', 'max:100'],
            'district' => ['required', 'string', 'max:100'],
            'neighborhood' => ['nullable', 'string', 'max:150'],
            'street' => ['nullable', 'string', 'max:200'],
            'building_no' => ['nullable', 'string', 'max:30'],
            'apartment_no' => ['nullable', 'string', 'max:30'],
            'directions' => ['nullable', 'string'],
            'latitude' => ['nullable', 'required_with:longitude', 'numeric', 'between:-90,90'],
            'longitude' => ['nullable', 'required_with:latitude', 'numeric', 'between:-180,180'],
            'is_default' => ['nullable', 'boolean'],
        ], [
            'province.required' => 'İl seçimi zorunludur.',
            'district.required' => 'İlçe seçimi zorunludur.',
        ]);

        // Ensure an address entered manually is usable by nearby-provider search.
        // The result is an approximate position until the customer chooses a map pin.
        $validated = $this->resolveAddressCoordinates($validated);

        $address = DB::transaction(function () use ($profile, $validated) {
            $isFirst = !$profile->addresses()->exists();
            $shouldBeDefault = $isFirst || !empty($validated['is_default']);

            if ($shouldBeDefault) {
                $profile->addresses()->update(['is_default' => false]);
            }

            $addr = $profile->addresses()->create([
                'title' => $validated['title'] ?? 'Ev',
                'province' => $validated['province'],
                'district' => $validated['district'],
                'neighborhood' => $validated['neighborhood'] ?? null,
                'street' => $validated['street'] ?? null,
                'building_no' => $validated['building_no'] ?? null,
                'apartment_no' => $validated['apartment_no'] ?? null,
                'directions' => $validated['directions'] ?? null,
                'latitude' => $validated['latitude'] ?? null,
                'longitude' => $validated['longitude'] ?? null,
                'is_default' => $shouldBeDefault,
            ]);

            // If profile was not completed, check if it is complete now
            if (!$profile->profile_completed) {
                $user = $profile->user;
                if (!empty($user->first_name) && !empty($user->last_name)) {
                    $profile->update(['profile_completed' => true]);
                }
            }

            return $addr;
        });

        return response()->json([
            'success' => true,
            'message' => 'Adres başarıyla eklendi.',
            'data' => new CustomerAddressResource($address),
        ], 201);
    }

    /**
     * Update existing address. Ownership strictly enforced.
     */
    public function updateAddress(Request $request, int $id): JsonResponse
    {
        $user = $request->user();
        $profile = $user->customerProfile;

        if (!$profile) {
            return response()->json(['success' => false, 'message' => 'Profil bulunamadı.'], 404);
        }

        // Ownership check: must belong to authenticated customer profile
        $address = $profile->addresses()->where('id', $id)->first();
        if (!$address) {
            return response()->json([
                'success' => false,
                'message' => 'Adres bulunamadı veya erişim yetkiniz yok.',
            ], 404);
        }

        $validated = $request->validate([
            'title' => ['sometimes', 'required', 'string', 'max:50'],
            'province' => ['sometimes', 'required', 'string', 'max:100'],
            'district' => ['sometimes', 'required', 'string', 'max:100'],
            'neighborhood' => ['nullable', 'string', 'max:150'],
            'street' => ['nullable', 'string', 'max:200'],
            'building_no' => ['nullable', 'string', 'max:30'],
            'apartment_no' => ['nullable', 'string', 'max:30'],
            'directions' => ['nullable', 'string'],
            'latitude' => ['nullable', 'required_with:longitude', 'numeric', 'between:-90,90'],
            'longitude' => ['nullable', 'required_with:latitude', 'numeric', 'between:-180,180'],
            'is_default' => ['nullable', 'boolean'],
        ]);

        // An edited city/district must never inherit coordinates from the old
        // saved address. Resolve the new region or store null until mapped.
        $locationFields = ['province', 'district', 'neighborhood', 'street', 'building_no'];
        $locationChanged = false;
        foreach ($locationFields as $field) {
            if (array_key_exists($field, $validated) && ($validated[$field] ?? null) !== ($address->{$field} ?? null)) {
                $locationChanged = true;
                break;
            }
        }
        if ($locationChanged) {
            if (!isset($validated['latitude'], $validated['longitude'])) {
                $combined = array_merge($address->only($locationFields), $validated);
                $combined['latitude'] = null;
                $combined['longitude'] = null;
                $resolved = $this->resolveAddressCoordinates($combined);
                $validated['latitude'] = $resolved['latitude'] ?? null;
                $validated['longitude'] = $resolved['longitude'] ?? null;
            }
        }

        DB::transaction(function () use ($profile, $address, $validated) {
            if (!empty($validated['is_default'])) {
                $profile->addresses()->where('id', '!=', $address->id)->update(['is_default' => false]);
            }

            $address->update($validated);
        });

        return response()->json([
            'success' => true,
            'message' => 'Adres güncellendi.',
            'data' => new CustomerAddressResource($address->fresh()),
        ]);
    }

    /**
     * Delete existing address. Ownership strictly enforced.
     */
    public function destroyAddress(Request $request, int $id): JsonResponse
    {
        $user = $request->user();
        $profile = $user->customerProfile;

        if (!$profile) {
            return response()->json(['success' => false, 'message' => 'Profil bulunamadı.'], 404);
        }

        // Ownership check
        $address = $profile->addresses()->where('id', $id)->first();
        if (!$address) {
            return response()->json([
                'success' => false,
                'message' => 'Adres bulunamadı veya erişim yetkiniz yok.',
            ], 404);
        }

        $wasDefault = $address->is_default;
        $address->delete();

        // If default deleted, promote another address to default if exists
        if ($wasDefault) {
            $next = $profile->addresses()->first();
            if ($next) {
                $next->update(['is_default' => true]);
            }
        }

        return response()->json([
            'success' => true,
            'message' => 'Adres başarıyla silindi.',
        ]);
    }
    /**
     * Use approximate geocoded coordinates for manual address forms.
     * Explicit map-pin coordinates always take precedence.
     * @param array<string, mixed> $data
     * @return array<string, mixed>
     */
    private function resolveAddressCoordinates(array $data): array
    {
        if (isset($data['latitude'], $data['longitude'])) return $data;
        if (empty($data['province']) || empty($data['district'])) return $data;
        // Without a pin, prefer a reliably located district centre instead
        // of guessing a street address or reusing coordinates from another city.
        $geocoder = app(\App\Services\GoogleGeocodingService::class);
        $result = $geocoder->search($data['district'] . ', ' . $data['province'] . ', Türkiye');
        if (($result['status'] ?? null) === 'OK') {
            $data['latitude'] = $result['data']['latitude'];
            $data['longitude'] = $result['data']['longitude'];
        }
        return $data;
    }

}
