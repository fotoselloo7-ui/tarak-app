<?php

namespace App\Services;

use App\Models\Appointment;
use App\Models\LocationShareEvent;
use App\Models\LocationShareGrant;
use App\Models\ServiceRequest;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;
use Symfony\Component\HttpKernel\Exception\UnprocessableEntityHttpException;

class LocationGrantService
{
    /**
     * Get default TTL minutes from configuration.
     */
    public function getTtlMinutes(): int
    {
        return (int) config('services.location_share.ttl_minutes', 120);
    }

    /**
     * Customer shares exact location for an ASSIGNED Instant Service Request.
     */
    public function shareLocationForInstantRequest(
        User $customer,
        ServiceRequest $request,
        string $source,
        bool $explicitConsent,
        ?array $currentLocationCoordinates = null,
        ?int $customerAddressId = null
    ): LocationShareGrant {
        // 1. Explicit consent validation
        if (!$explicitConsent) {
            throw ValidationException::withMessages([
                'explicit_consent' => ['Açık onay (explicit_consent = true) zorunludur.'],
            ]);
        }

        // 2. Customer ownership
        if ((int) $request->customer_user_id !== (int) $customer->id) {
            throw new AccessDeniedHttpException('Bu talebe ait konum paylaşma yetkiniz bulunmuyor.');
        }

        // 3. Status guard: Only ASSIGNED can be shared
        if ($request->status !== ServiceRequest::STATUS_ASSIGNED) {
            throw new UnprocessableEntityHttpException('Yalnızca hizmet veren atanmış (ASSIGNED) talepler için konum paylaşılabilir.');
        }

        if (empty($request->assigned_provider_user_id)) {
            throw new UnprocessableEntityHttpException('Bu talebe henüz atanmış bir hizmet veren bulunmuyor.');
        }

        // Financial Readiness Gate: ONLINE requires HELD, CASH requires RESERVED
        app(\App\Services\FinancialService::class)->ensureFinanciallyReadyForLocationShare(
            LocationShareGrant::RESOURCE_INSTANT_REQUEST,
            $request->id,
            $request->payment_method ?? 'CASH'
        );

        // 4. Source validation and payload preparation
        $payload = $this->preparePayload(
            source: $source,
            associatedAddressId: $request->customer_address_id,
            requestAddressId: $customerAddressId,
            currentLocationCoordinates: $currentLocationCoordinates
        );

        return DB::transaction(function () use ($customer, $request, $source, $payload) {
            // Revoke any existing active grants for this instant request
            $this->deactivateExistingActiveGrants(
                LocationShareGrant::RESOURCE_INSTANT_REQUEST,
                $request->id,
                $customer->id
            );

            $expiresAt = Carbon::now()->addMinutes($this->getTtlMinutes());

            $grant = LocationShareGrant::create([
                'customer_user_id' => $customer->id,
                'provider_user_id' => $request->assigned_provider_user_id,
                'resource_type' => LocationShareGrant::RESOURCE_INSTANT_REQUEST,
                'resource_id' => $request->id,
                'source' => $source,
                'status' => LocationShareGrant::STATUS_ACTIVE,
                'customer_address_id' => $source === LocationShareGrant::SOURCE_SAVED_ADDRESS ? $request->customer_address_id : null,
                'exact_location_payload' => $payload,
                'shared_at' => Carbon::now(),
                'expires_at' => $expiresAt,
            ]);

            LocationShareEvent::create([
                'location_share_grant_id' => $grant->id,
                'event_type' => LocationShareEvent::EVENT_SHARED,
                'actor_user_id' => $customer->id,
                'created_at' => Carbon::now(),
            ]);

            app(\App\Services\NotificationService::class)->notifyUser(
                $grant->provider_user_id,
                \App\Models\UserNotification::TYPE_LOCATION_SHARED,
                'Konum Paylaşıldı',
                'Müşteri bu hizmet için konumunu paylaştı.',
                $grant->resource_type,
                $grant->resource_id,
                '/barber',
                ['grant_id' => $grant->id, 'source' => $grant->source],
                "LOCATION_SHARED:{$grant->id}:{$grant->provider_user_id}"
            );

            return $grant;
        });
    }

    /**
     * Customer shares exact location for a CONFIRMED Scheduled Appointment.
     */
    public function shareLocationForAppointment(
        User $customer,
        Appointment $appointment,
        string $source,
        bool $explicitConsent,
        ?array $currentLocationCoordinates = null,
        ?int $customerAddressId = null
    ): LocationShareGrant {
        // 1. Explicit consent validation
        if (!$explicitConsent) {
            throw ValidationException::withMessages([
                'explicit_consent' => ['Açık onay (explicit_consent = true) zorunludur.'],
            ]);
        }

        // 2. Customer ownership
        if ((int) $appointment->customer_user_id !== (int) $customer->id) {
            throw new AccessDeniedHttpException('Bu randevuya ait konum paylaşma yetkiniz bulunmuyor.');
        }

        // 3. Status guard: Only CONFIRMED appointments can be shared
        if ($appointment->status !== 'CONFIRMED') {
            throw new UnprocessableEntityHttpException('Yalnızca onaylanmış (CONFIRMED) randevular için konum paylaşılabilir.');
        }

        if (empty($appointment->provider_user_id)) {
            throw new UnprocessableEntityHttpException('Bu randevuya atanmış bir hizmet veren bulunmuyor.');
        }

        // Financial Readiness Gate: ONLINE requires HELD, CASH requires RESERVED
        app(\App\Services\FinancialService::class)->ensureFinanciallyReadyForLocationShare(
            LocationShareGrant::RESOURCE_SCHEDULED_APPOINTMENT,
            $appointment->id,
            $appointment->payment_method ?? 'CASH'
        );

        // 4. Source validation and payload preparation
        $payload = $this->preparePayload(
            source: $source,
            associatedAddressId: $appointment->customer_address_id,
            requestAddressId: $customerAddressId,
            currentLocationCoordinates: $currentLocationCoordinates
        );

        return DB::transaction(function () use ($customer, $appointment, $source, $payload) {
            // Revoke any existing active grants for this appointment
            $this->deactivateExistingActiveGrants(
                LocationShareGrant::RESOURCE_SCHEDULED_APPOINTMENT,
                $appointment->id,
                $customer->id
            );

            $expiresAt = Carbon::now()->addMinutes($this->getTtlMinutes());

            $grant = LocationShareGrant::create([
                'customer_user_id' => $customer->id,
                'provider_user_id' => $appointment->provider_user_id,
                'resource_type' => LocationShareGrant::RESOURCE_SCHEDULED_APPOINTMENT,
                'resource_id' => $appointment->id,
                'source' => $source,
                'status' => LocationShareGrant::STATUS_ACTIVE,
                'customer_address_id' => $source === LocationShareGrant::SOURCE_SAVED_ADDRESS ? $appointment->customer_address_id : null,
                'exact_location_payload' => $payload,
                'shared_at' => Carbon::now(),
                'expires_at' => $expiresAt,
            ]);

            LocationShareEvent::create([
                'location_share_grant_id' => $grant->id,
                'event_type' => LocationShareEvent::EVENT_SHARED,
                'actor_user_id' => $customer->id,
                'created_at' => Carbon::now(),
            ]);

            app(\App\Services\NotificationService::class)->notifyUser(
                $grant->provider_user_id,
                \App\Models\UserNotification::TYPE_LOCATION_SHARED,
                'Konum Paylaşıldı',
                'Müşteri bu hizmet için konumunu paylaştı.',
                $grant->resource_type,
                $grant->resource_id,
                '/barber',
                ['grant_id' => $grant->id, 'source' => $grant->source],
                "LOCATION_SHARED:{$grant->id}:{$grant->provider_user_id}"
            );

            return $grant;
        });
    }

    /**
     * Customer revokes an active grant for an Instant Request.
     */
    public function revokeLocationForInstantRequest(User $customer, ServiceRequest $request): bool
    {
        if ((int) $request->customer_user_id !== (int) $customer->id) {
            throw new AccessDeniedHttpException('Bu talep için işlem yapma yetkiniz bulunmuyor.');
        }

        return $this->revokeGrantsForResource(
            LocationShareGrant::RESOURCE_INSTANT_REQUEST,
            $request->id,
            $customer->id
        );
    }

    /**
     * Customer revokes an active grant for an Appointment.
     */
    public function revokeLocationForAppointment(User $customer, Appointment $appointment): bool
    {
        if ((int) $appointment->customer_user_id !== (int) $customer->id) {
            throw new AccessDeniedHttpException('Bu randevu için işlem yapma yetkiniz bulunmuyor.');
        }

        return $this->revokeGrantsForResource(
            LocationShareGrant::RESOURCE_SCHEDULED_APPOINTMENT,
            $appointment->id,
            $customer->id
        );
    }

    /**
     * Get active grant for customer to display in UI.
     */
    public function getActiveGrantForCustomer(User $customer, string $resourceType, int $resourceId): ?LocationShareGrant
    {
        $grant = LocationShareGrant::where('resource_type', $resourceType)
            ->where('resource_id', $resourceId)
            ->where('customer_user_id', $customer->id)
            ->where('status', LocationShareGrant::STATUS_ACTIVE)
            ->latest('id')
            ->first();

        if (!$grant) {
            return null;
        }

        // If expired, transition to EXPIRED
        if ($grant->isExpired()) {
            $this->markGrantAsExpired($grant);
            return null;
        }

        return $grant;
    }

    /**
     * Provider reads the shared exact location.
     * Enforces resource ownership, active status, resource state guard, and expiry.
     */
    public function getSharedLocationForProvider(User $provider, string $resourceType, int $resourceId): array
    {
        // 1. Verify resource ownership and state guard
        $this->validateResourceStateForProvider($provider, $resourceType, $resourceId);

        // 2. Find active grant
        $grant = LocationShareGrant::where('resource_type', $resourceType)
            ->where('resource_id', $resourceId)
            ->where('provider_user_id', $provider->id)
            ->where('status', LocationShareGrant::STATUS_ACTIVE)
            ->latest('id')
            ->first();

        if (!$grant) {
            throw new NotFoundHttpException('Müşteri henüz konumunu paylaşmadı veya paylaşım izni bulunamadı.');
        }

        // 3. Expiry check
        if ($grant->isExpired()) {
            $this->markGrantAsExpired($grant);
            throw new NotFoundHttpException('Konum paylaşım izninin süresi dolmuş.');
        }

        // 4. Decrypt and project payload strictly
        $rawPayload = $grant->exact_location_payload ?? [];
        $projectedLocation = $this->projectExactLocation($rawPayload);

        return [
            'resource_type' => $grant->resource_type,
            'resource_id' => $grant->resource_id,
            'source' => $grant->source,
            'shared_at' => $grant->shared_at?->toISOString(),
            'expires_at' => $grant->expires_at?->toISOString(),
            'exact_location' => $projectedLocation,
        ];
    }

    /**
     * Hook to expire grants when resource transitions out of active service.
     * Can be invoked by future lifecycle handlers (COMPLETED, DISPUTED, CANCELLED).
     */
    public function expireGrantsForResource(string $resourceType, int $resourceId, ?string $reason = null): int
    {
        $grants = LocationShareGrant::where('resource_type', $resourceType)
            ->where('resource_id', $resourceId)
            ->where('status', LocationShareGrant::STATUS_ACTIVE)
            ->get();

        $count = 0;
        foreach ($grants as $grant) {
            $this->markGrantAsExpired($grant);
            $count++;
        }

        return $count;
    }

    /**
     * Deactivate existing active grants when customer shares again.
     */
    protected function deactivateExistingActiveGrants(string $resourceType, int $resourceId, int $actorUserId): void
    {
        $existingGrants = LocationShareGrant::where('resource_type', $resourceType)
            ->where('resource_id', $resourceId)
            ->where('status', LocationShareGrant::STATUS_ACTIVE)
            ->lockForUpdate()
            ->get();

        foreach ($existingGrants as $grant) {
            $grant->update([
                'status' => LocationShareGrant::STATUS_REVOKED,
                'revoked_at' => Carbon::now(),
            ]);

            LocationShareEvent::create([
                'location_share_grant_id' => $grant->id,
                'event_type' => LocationShareEvent::EVENT_REVOKED,
                'actor_user_id' => $actorUserId,
                'created_at' => Carbon::now(),
            ]);
        }
    }

    /**
     * Revoke active grants for a specific resource by customer.
     */
    protected function revokeGrantsForResource(string $resourceType, int $resourceId, int $actorUserId): bool
    {
        return DB::transaction(function () use ($resourceType, $resourceId, $actorUserId) {
            $activeGrants = LocationShareGrant::where('resource_type', $resourceType)
                ->where('resource_id', $resourceId)
                ->where('status', LocationShareGrant::STATUS_ACTIVE)
                ->lockForUpdate()
                ->get();

            if ($activeGrants->isEmpty()) {
                return false;
            }

            foreach ($activeGrants as $grant) {
                $grant->update([
                    'status' => LocationShareGrant::STATUS_REVOKED,
                    'revoked_at' => Carbon::now(),
                ]);

                LocationShareEvent::create([
                    'location_share_grant_id' => $grant->id,
                    'event_type' => LocationShareEvent::EVENT_REVOKED,
                    'actor_user_id' => $actorUserId,
                    'created_at' => Carbon::now(),
                ]);
            }

            return true;
        });
    }

    /**
     * Mark a grant as expired and log audit event.
     */
    protected function markGrantAsExpired(LocationShareGrant $grant): void
    {
        $grant->update([
            'status' => LocationShareGrant::STATUS_EXPIRED,
            'expired_at' => Carbon::now(),
        ]);

        LocationShareEvent::create([
            'location_share_grant_id' => $grant->id,
            'event_type' => LocationShareEvent::EVENT_EXPIRED,
            'actor_user_id' => $grant->customer_user_id,
            'created_at' => Carbon::now(),
        ]);
    }

    /**
     * Validate and snapshot location payload according to source.
     */
    protected function preparePayload(
        string $source,
        ?int $associatedAddressId,
        ?int $requestAddressId,
        ?array $currentLocationCoordinates
    ): array {
        if ($source === LocationShareGrant::SOURCE_SAVED_ADDRESS) {
            if (!$associatedAddressId) {
                throw new UnprocessableEntityHttpException('Bu hizmet talebine bağlı kayıtlı bir adres bulunamadı.');
            }

            // Customer cannot send another address ID to alter resource address
            if ($requestAddressId !== null && (int) $requestAddressId !== (int) $associatedAddressId) {
                throw new UnprocessableEntityHttpException('Yalnızca bu talep için seçilmiş olan kayıtlı adres paylaşılabilir.');
            }

            $address = \App\Models\CustomerAddress::find($associatedAddressId);
            if (!$address) {
                throw new UnprocessableEntityHttpException('Kayıtlı adres veritabanında bulunamadı.');
            }

            // Snapshot address details
            return [
                'province' => $address->province,
                'district' => $address->district,
                'neighborhood' => $address->neighborhood,
                'street' => $address->street,
                'building_no' => $address->building_no,
                'apartment_no' => $address->apartment_no,
                'directions' => $address->directions,
                'latitude' => $address->latitude !== null ? (float) $address->latitude : null,
                'longitude' => $address->longitude !== null ? (float) $address->longitude : null,
            ];
        }

        if ($source === LocationShareGrant::SOURCE_CURRENT_LOCATION) {
            if (!isset($currentLocationCoordinates['latitude']) || !isset($currentLocationCoordinates['longitude'])) {
                throw ValidationException::withMessages([
                    'coordinates' => ['Geçerli enlem ve boylam koordinatları zorunludur.'],
                ]);
            }

            $lat = $currentLocationCoordinates['latitude'];
            $lng = $currentLocationCoordinates['longitude'];

            if (!is_numeric($lat) || !is_numeric($lng)) {
                throw ValidationException::withMessages([
                    'coordinates' => ['Koordinatlar sayısal değer olmalıdır.'],
                ]);
            }

            $lat = (float) $lat;
            $lng = (float) $lng;

            if ($lat < -90 || $lat > 90) {
                throw ValidationException::withMessages([
                    'latitude' => ['Enlem (latitude) -90 ile 90 arasında olmalıdır.'],
                ]);
            }

            if ($lng < -180 || $lng > 180) {
                throw ValidationException::withMessages([
                    'longitude' => ['Boylam (longitude) -180 ile 180 arasında olmalıdır.'],
                ]);
            }

            return [
                'latitude' => $lat,
                'longitude' => $lng,
            ];
        }

        throw new UnprocessableEntityHttpException('Geçersiz konum kaynağı (source). SAVED_ADDRESS veya CURRENT_LOCATION olmalıdır.');
    }

    /**
     * Validate resource ownership and state guards for provider.
     */
    protected function validateResourceStateForProvider(User $provider, string $resourceType, int $resourceId): void
    {
        if ($resourceType === LocationShareGrant::RESOURCE_INSTANT_REQUEST) {
            $request = ServiceRequest::find($resourceId);
            if (!$request) {
                throw new NotFoundHttpException('Hizmet talebi bulunamadı.');
            }

            if ((int) $request->assigned_provider_user_id !== (int) $provider->id) {
                throw new AccessDeniedHttpException('Bu hizmet talebine erişim yetkiniz yok.');
            }

            // State guard: ONLY ASSIGNED (and future active states: IN_PROGRESS, AWAITING_CUSTOMER_CONFIRMATION)
            $allowedStates = [
                ServiceRequest::STATUS_ASSIGNED,
                'IN_PROGRESS',
                'AWAITING_CUSTOMER_CONFIRMATION',
            ];

            if (!in_array($request->status, $allowedStates, true)) {
                throw new AccessDeniedHttpException('Hizmet talebinin mevcut durumu (' . $request->status . ') konum erişimine uygun değil.');
            }

            return;
        }

        if ($resourceType === LocationShareGrant::RESOURCE_SCHEDULED_APPOINTMENT) {
            $appointment = Appointment::find($resourceId);
            if (!$appointment) {
                throw new NotFoundHttpException('Randevu bulunamadı.');
            }

            if ((int) $appointment->provider_user_id !== (int) $provider->id) {
                throw new AccessDeniedHttpException('Bu randevuya erişim yetkiniz yok.');
            }

            // State guard: ONLY CONFIRMED (and future active states: IN_PROGRESS)
            $allowedStates = [
                'CONFIRMED',
                'IN_PROGRESS',
            ];

            if (!in_array($appointment->status, $allowedStates, true)) {
                throw new AccessDeniedHttpException('Randevunun mevcut durumu (' . $appointment->status . ') konum erişimine uygun değil.');
            }

            return;
        }

        throw new UnprocessableEntityHttpException('Geçersiz kaynak türü.');
    }

    /**
     * Strictly project location payload to allowed privacy fields.
     * Prevents any leakage of email, phone, or internal attributes.
     */
    protected function projectExactLocation(array $payload): array
    {
        $projected = [];

        $allowedFields = [
            'province',
            'district',
            'neighborhood',
            'street',
            'building_no',
            'apartment_no',
            'directions',
            'latitude',
            'longitude',
        ];

        foreach ($allowedFields as $field) {
            if (array_key_exists($field, $payload) && $payload[$field] !== null && $payload[$field] !== '') {
                $projected[$field] = $payload[$field];
            }
        }

        return $projected;
    }
}
