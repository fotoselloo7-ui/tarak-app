<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\ServiceOfferResource;
use App\Http\Resources\ServiceRequestResource;
use App\Models\LocationShareGrant;
use App\Models\Service;
use App\Models\ServiceOffer;
use App\Models\ServiceRequest;
use App\Services\InstantAssignmentService;
use App\Services\InstantMatchingService;
use App\Services\ProviderAvailabilityService;
use App\Services\ProviderOfferingService;
use App\Services\ServiceLifecycleService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class CustomerServiceRequestController extends Controller
{
    /**
     * List all instant service requests created by authenticated customer.
     */
    public function index(Request $request): JsonResponse
    {
        $user = $request->user();

        $query = ServiceRequest::where('customer_user_id', $user->id)
            ->with(['services', 'category', 'assignedProvider.providerProfile', 'disputeCase'])
            ->withCount('offers')
            ->orderBy('created_at', 'desc');

        if ($request->has('status') && $request->input('status') !== 'all') {
            $query->where('status', $request->input('status'));
        }

        $requests = $query->get();

        return response()->json([
            'success' => true,
            'data' => ServiceRequestResource::collection($requests),
        ]);
    }

    /**
     * Create a new instant service request.
     */
    public function store(Request $request): JsonResponse
    {
        $user = $request->user();

        if ($request->filled('provider_service_id') || $request->filled('provider_package_id')) {
            return $this->storeDirect($request);
        }

        $validated = $request->validate([
            'service_ids' => 'required|array|min:1',
            'service_ids.*' => 'required|integer|exists:services,id',
            'category_id' => 'nullable|string|exists:service_categories,id',
            'customer_address_id' => 'required|integer|exists:customer_addresses,id',
            'approx_province' => 'nullable|string|max:100',
            'approx_district' => 'nullable|string|max:100',
            'approx_neighborhood' => 'nullable|string|max:150',
            'private_latitude' => 'nullable|numeric|between:-90,90',
            'private_longitude' => 'nullable|numeric|between:-180,180',
            'payment_method' => 'nullable|string|in:CASH,ONLINE',
            'customer_note' => 'nullable|string|max:1000',
            'duration_preference' => 'nullable|max:50',
            'urgency' => 'nullable|string|max:30',
        ], [
            'service_ids.required' => 'Lütfen en az bir hizmet seçiniz.',
            'service_ids.min' => 'Lütfen en az bir hizmet seçiniz.',
            'service_ids.*.exists' => 'Seçilen hizmet sistemde bulunamadı.',
        ]);

        // 1. Verify all requested services are active
        $activeServicesCount = Service::whereIn('id', $validated['service_ids'])
            ->where('is_active', true)
            ->count();

        if ($activeServicesCount !== count($validated['service_ids'])) {
            return response()->json([
                'success' => false,
                'message' => 'Seçilen hizmetlerden biri veya birkaçı şu anda aktif değil.',
            ], 422);
        }

        // 2. Saved Address Ownership Verification & Snapshot
        $approxProvince = $validated['approx_province'] ?? null;
        $approxDistrict = $validated['approx_district'] ?? null;
        $approxNeighborhood = $validated['approx_neighborhood'] ?? null;
        $privateLat = $validated['private_latitude'] ?? null;
        $privateLon = $validated['private_longitude'] ?? null;
        $locationText = null;

        if (!empty($validated['customer_address_id'])) {
            $savedAddress = app(\App\Services\SavedCustomerLocation::class)->resolve($user, (int) $validated['customer_address_id']);

            // Extract privacy-safe regional snapshot and private coordinates
            $approxProvince = $savedAddress->province;
            $approxDistrict = $savedAddress->district;
            $approxNeighborhood = $savedAddress->neighborhood;
            $privateLat = $savedAddress->latitude;
            $privateLon = $savedAddress->longitude;
            $locationText = "{$savedAddress->district}, {$savedAddress->province}";
        } else {
            if ($approxDistrict && $approxProvince) {
                $locationText = "{$approxDistrict}, {$approxProvince}";
            }
        }

        // 3. Deduce Category ID if not explicitly provided
        $categoryId = $validated['category_id'] ?? null;
        if (!$categoryId) {
            $firstService = Service::find($validated['service_ids'][0]);
            $categoryId = $firstService?->category_id;
        }

        // 4. Create Service Request within DB transaction
        $serviceRequest = DB::transaction(function () use ($user, $validated, $categoryId, $approxProvince, $approxDistrict, $approxNeighborhood, $privateLat, $privateLon, $locationText) {
            $record = ServiceRequest::create([
                'customer_user_id' => $user->id,
                'category_id' => $categoryId,
                'mode' => ServiceRequest::MODE_INSTANT,
                'status' => ServiceRequest::STATUS_OPEN,
                'payment_method' => $validated['payment_method'] ?? 'CASH',
                'customer_address_id' => $validated['customer_address_id'] ?? null,
                'location_text' => $locationText,
                'approx_province' => $approxProvince,
                'approx_district' => $approxDistrict,
                'approx_neighborhood' => $approxNeighborhood,
                'private_latitude' => $privateLat,
                'private_longitude' => $privateLon,
                'customer_note' => $validated['customer_note'] ?? null,
                'duration_preference' => $validated['duration_preference'] ?? '1h',
                'urgency' => $validated['urgency'] ?? 'urgent',
            ]);

            $record->services()->sync($validated['service_ids']);
            app(\App\Services\InstantOpportunityNotifier::class)->notifyEligible($record);

            return $record;
        });

        return response()->json([
            'success' => true,
            'message' => 'Hemen çağır talebiniz başarıyla oluşturuldu.',
            'data' => new ServiceRequestResource($serviceRequest->load(['services', 'category'])),
        ], 201);
    }

    /**
     * Direct call: the customer picked a specific provider's service or package.
     * The request targets only that provider and carries an immutable price/content snapshot.
     */
    private function storeDirect(Request $request): JsonResponse
    {
        $user = $request->user();

        $validated = $request->validate([
            'provider_service_id' => 'nullable|integer|required_without:provider_package_id|prohibits:provider_package_id',
            'provider_package_id' => 'nullable|integer|required_without:provider_service_id',
            'customer_address_id' => 'required|integer|exists:customer_addresses,id',
            'approx_province' => 'nullable|string|max:100',
            'approx_district' => 'nullable|string|max:100',
            'approx_neighborhood' => 'nullable|string|max:150',
            'private_latitude' => 'nullable|numeric|between:-90,90',
            'private_longitude' => 'nullable|numeric|between:-180,180',
            'payment_method' => 'nullable|string|in:CASH,ONLINE',
            'customer_note' => 'nullable|string|max:1000',
        ], [
            'provider_service_id.prohibits' => 'Aynı anda hem hizmet hem paket seçilemez.',
        ]);

        $offering = app(ProviderOfferingService::class)->resolveOffering(
            isset($validated['provider_service_id']) ? (int) $validated['provider_service_id'] : null,
            isset($validated['provider_package_id']) ? (int) $validated['provider_package_id'] : null,
        );
        $profile = $offering['profile'];

        if ((int) $profile->user_id === (int) $user->id) {
            return response()->json(['success' => false, 'message' => 'Kendi hizmetinizi çağıramazsınız.'], 422);
        }

        $alreadyOpen = ServiceRequest::where('customer_user_id', $user->id)
            ->where('target_provider_user_id', $profile->user_id)
            ->where('status', ServiceRequest::STATUS_OPEN)
            ->exists();
        if ($alreadyOpen) {
            return response()->json([
                'success' => false,
                'message' => 'Bu uzmana yanıt bekleyen bir talebiniz zaten var.',
            ], 422);
        }

        $location = $this->resolveLocation($user, $validated);
        if ($location instanceof JsonResponse) {
            return $location;
        }

        $window = app(ProviderAvailabilityService::class)->instantWindowCheck($profile, $offering['duration_minutes']);
        if (!$window['available']) {
            return response()->json(['success' => false, 'message' => $window['reason']], 422);
        }

        $matchingService = app(InstantMatchingService::class);

        try {
            $serviceRequest = DB::transaction(function () use ($user, $validated, $offering, $profile, $location, $matchingService) {
                $record = ServiceRequest::create([
                    'customer_user_id' => $user->id,
                    'category_id' => $offering['category_id'],
                    'mode' => ServiceRequest::MODE_INSTANT,
                    'status' => ServiceRequest::STATUS_OPEN,
                    'payment_method' => $validated['payment_method'] ?? 'CASH',
                    'customer_address_id' => $validated['customer_address_id'] ?? null,
                    'location_text' => $location['location_text'],
                    'approx_province' => $location['approx_province'],
                    'approx_district' => $location['approx_district'],
                    'approx_neighborhood' => $location['approx_neighborhood'],
                    'private_latitude' => $location['private_latitude'],
                    'private_longitude' => $location['private_longitude'],
                    'customer_note' => $validated['customer_note'] ?? null,
                    'duration_preference' => $offering['duration_minutes'] . 'm',
                    'urgency' => 'urgent',
                    'target_provider_user_id' => $profile->user_id,
                    'provider_service_id' => $offering['provider_service_id'],
                    'provider_package_id' => $offering['provider_package_id'],
                    'snapshot_price' => $offering['price'],
                    'snapshot_duration_minutes' => $offering['duration_minutes'],
                    'offering_snapshot' => $offering['snapshot'],
                ]);
                $record->services()->sync($offering['service_ids']);

                // Same rules as generic matching: approval, documents, online, accepting clients, busy, radius.
                $check = $matchingService->isProviderEligibleForRequest($profile->user, $record);
                if (!$check['eligible']) {
                    throw new \RuntimeException($check['reason'] ?? 'Hizmet veren şu anda müsait değil.');
                }

                return $record;
            });
        } catch (\RuntimeException $e) {
            return response()->json([
                'success' => false,
                'message' => 'Bu uzman şu anda çağrılamıyor: ' . $e->getMessage(),
            ], 422);
        }

        app(\App\Services\NotificationService::class)->notifyUser(
            $profile->user_id,
            \App\Models\UserNotification::TYPE_DIRECT_REQUEST_RECEIVED,
            'Yeni iş fırsatı',
            "Bir müşteri sizi doğrudan çağırdı: {$offering['snapshot']['title']}.",
            \App\Models\UserNotification::RESOURCE_INSTANT_REQUEST,
            $serviceRequest->id,
            '/barber',
            [
                'service_request_id' => $serviceRequest->id,
                'price' => $offering['price'],
                'duration_minutes' => $offering['duration_minutes'],
            ],
            "DIRECT_REQUEST_RECEIVED:{$serviceRequest->id}:{$profile->user_id}"
        );

        return response()->json([
            'success' => true,
            'message' => 'Talebiniz ' . ($offering['snapshot']['provider_name'] ?? 'uzmana') . ' adlı uzmana iletildi. Yanıtı bekleniyor.',
            'data' => new ServiceRequestResource($serviceRequest->load(['services', 'category', 'targetProvider.providerProfile'])),
        ], 201);
    }

    /**
     * Privacy-safe regional snapshot plus private coordinates from a saved address or approx fields.
     */
    private function resolveLocation($user, array $validated): array|JsonResponse
    {
        if (!empty($validated['customer_address_id'])) {
            $savedAddress = app(\App\Services\SavedCustomerLocation::class)->resolve($user, (int) $validated['customer_address_id']);

            return [
                'approx_province' => $savedAddress->province,
                'approx_district' => $savedAddress->district,
                'approx_neighborhood' => $savedAddress->neighborhood,
                'private_latitude' => $savedAddress->latitude,
                'private_longitude' => $savedAddress->longitude,
                'location_text' => "{$savedAddress->district}, {$savedAddress->province}",
            ];
        }

        $province = $validated['approx_province'] ?? null;
        $district = $validated['approx_district'] ?? null;

        return [
            'approx_province' => $province,
            'approx_district' => $district,
            'approx_neighborhood' => $validated['approx_neighborhood'] ?? null,
            'private_latitude' => $validated['private_latitude'] ?? null,
            'private_longitude' => $validated['private_longitude'] ?? null,
            'location_text' => $district && $province ? "{$district}, {$province}" : null,
        ];
    }

    /**
     * Show single customer request detail.
     */
    public function show(int $id, Request $request): JsonResponse
    {
        $user = $request->user();

        $serviceRequest = ServiceRequest::where('id', $id)
            ->where('customer_user_id', $user->id)
            ->with(['services', 'category', 'assignedProvider.providerProfile'])
            ->first();

        if (!$serviceRequest) {
            return response()->json([
                'success' => false,
                'message' => 'Hizmet talebi bulunamadı.',
            ], 404);
        }

        return response()->json([
            'success' => true,
            'data' => new ServiceRequestResource($serviceRequest),
        ]);
    }

    /**
     * Cancel an OPEN instant service request.
     */
    public function cancel(int $id, Request $request): JsonResponse
    {
        $user = $request->user();

        $serviceRequest = ServiceRequest::where('id', $id)
            ->where('customer_user_id', $user->id)
            ->first();

        if (!$serviceRequest) {
            return response()->json([
                'success' => false,
                'message' => 'Hizmet talebi bulunamadı.',
            ], 404);
        }

        if ($serviceRequest->status !== ServiceRequest::STATUS_OPEN) {
            return response()->json([
                'success' => false,
                'message' => 'Yalnızca açık durumdaki talepler iptal edilebilir.',
            ], 422);
        }

        $serviceRequest->status = ServiceRequest::STATUS_CANCELLED;
        $serviceRequest->cancelled_at = now();
        $serviceRequest->save();

        // Release commission reservation or cancel online payment if any
        $paymentMethod = strtoupper($serviceRequest->payment_method ?? 'CASH');
        if ($paymentMethod === 'CASH') {
            app(\App\Services\FinancialService::class)->releaseCashCommission(
                LocationShareGrant::RESOURCE_INSTANT_REQUEST,
                $serviceRequest->id,
                'REQUEST_CANCELLED'
            );
        } else {
            app(\App\Services\FinancialService::class)->cancelOnlinePayment(
                LocationShareGrant::RESOURCE_INSTANT_REQUEST,
                $serviceRequest->id
            );
        }

        // Reject any pending offers
        ServiceOffer::where('service_request_id', $serviceRequest->id)
            ->where('status', ServiceOffer::STATUS_PENDING)
            ->update([
                'status' => ServiceOffer::STATUS_REJECTED,
                'rejected_at' => now(),
            ]);

        return response()->json([
            'success' => true,
            'message' => 'Hizmet talebi başarıyla iptal edildi.',
            'data' => new ServiceRequestResource($serviceRequest->fresh(['services', 'category'])),
        ]);
    }

    /**
     * List incoming offers for a customer's request.
     */
    public function offers(int $id, Request $request): JsonResponse
    {
        $user = $request->user();

        $serviceRequest = ServiceRequest::where('id', $id)
            ->where('customer_user_id', $user->id)
            ->first();

        if (!$serviceRequest) {
            return response()->json([
                'success' => false,
                'message' => 'Hizmet talebi bulunamadı.',
            ], 404);
        }

        $offers = $serviceRequest->offers()
            ->with(['provider.providerProfile'])
            ->orderBy('created_at', 'desc')
            ->get();

        return response()->json([
            'success' => true,
            'data' => ServiceOfferResource::collection($offers),
        ]);
    }

    /**
     * Accept a provider offer for a service request (Strict Transaction & Concurrency Lock).
     */
    public function acceptOffer(int $requestId, int $offerId, Request $request, InstantMatchingService $matchingService): JsonResponse
    {
        $user = $request->user();

        return DB::transaction(function () use ($user, $requestId, $offerId, $matchingService) {
            // Lock request row for update to prevent race conditions
            $serviceRequest = ServiceRequest::where('id', $requestId)
                ->where('customer_user_id', $user->id)
                ->lockForUpdate()
                ->first();

            if (!$serviceRequest) {
                return response()->json([
                    'success' => false,
                    'message' => 'Hizmet talebi bulunamadı.',
                ], 404);
            }

            if ($serviceRequest->status !== ServiceRequest::STATUS_OPEN) {
                return response()->json([
                    'success' => false,
                    'message' => 'Bu talep artık açık değil veya bir teklif zaten kabul edilmiş.',
                ], 422);
            }

            // Lock offer row
            $offer = ServiceOffer::where('id', $offerId)
                ->where('service_request_id', $serviceRequest->id)
                ->lockForUpdate()
                ->first();

            if (!$offer) {
                return response()->json([
                    'success' => false,
                    'message' => 'Teklif bulunamadı.',
                ], 404);
            }

            if ($offer->status !== ServiceOffer::STATUS_PENDING) {
                return response()->json([
                    'success' => false,
                    'message' => 'Bu teklif artık geçerli değil.',
                ], 422);
            }

            // Verify provider is still eligible (not busy, still approved, etc.)
            $providerUser = $offer->provider;
            $check = $matchingService->isProviderEligibleForRequest($providerUser, $serviceRequest);
            if (!$check['eligible']) {
                return response()->json([
                    'success' => false,
                    'message' => 'Hizmet veren şu anda bu işi almak için müsait değil: ' . ($check['reason'] ?? ''),
                ], 422);
            }

            // Financial reservation, assignment, start code and competing-offer rejection (atomic)
            app(InstantAssignmentService::class)->assign($serviceRequest, $offer);

            app(\App\Services\NotificationService::class)->notifyUser(
                $offer->provider_user_id,
                \App\Models\UserNotification::TYPE_OFFER_ACCEPTED,
                'Teklifiniz Kabul Edildi',
                'Teklifiniz müşteri tarafından kabul edildi.',
                \App\Models\UserNotification::RESOURCE_INSTANT_REQUEST,
                $serviceRequest->id,
                '/barber',
                [
                    'service_request_id' => $serviceRequest->id,
                    'offer_id' => $offer->id,
                    'price' => (float) $offer->price,
                ],
                "OFFER_ACCEPTED:{$serviceRequest->id}:{$offer->provider_user_id}"
            );

            return response()->json([
                'success' => true,
                'message' => 'Teklif başarıyla kabul edildi ve hizmet veren atandı.',
                'data' => new ServiceRequestResource($serviceRequest->fresh(['services', 'category', 'assignedProvider.providerProfile'])),
            ]);
        });
    }
}
