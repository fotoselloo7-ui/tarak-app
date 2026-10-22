<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\ProviderMarketplaceRequestResource;
use App\Http\Resources\ServiceOfferResource;
use App\Models\ServiceOffer;
use App\Models\ServiceRequest;
use App\Services\InstantAssignmentService;
use App\Services\InstantMatchingService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class ProviderServiceRequestController extends Controller
{
    /**
     * Provider Marketplace: List open instant requests matching this provider's eligibility criteria.
     */
    public function marketplace(Request $request, InstantMatchingService $matchingService): JsonResponse
    {
        $user = $request->user();

        $eligibleRequests = $matchingService->getEligibleRequestsForProvider($user);

        return response()->json([
            'success' => true,
            'data' => ProviderMarketplaceRequestResource::collection($eligibleRequests),
        ]);
    }

    /**
     * View sanitized marketplace request details.
     */
    public function show(int $id, Request $request, InstantMatchingService $matchingService): JsonResponse
    {
        $user = $request->user();

        $serviceRequest = ServiceRequest::with(['services', 'category', 'servicePayment', 'disputeCase'])->find($id);
        if (!$serviceRequest) {
            return response()->json([
                'success' => false,
                'message' => 'Hizmet talebi bulunamadı.',
            ], 404);
        }

        $check = $matchingService->isProviderEligibleForRequest($user, $serviceRequest);
        if (!$check['eligible'] && $serviceRequest->assigned_provider_user_id !== $user->id) {
            return response()->json([
                'success' => false,
                'message' => $check['reason'] ?? 'Bu talebi görüntüleme yetkiniz bulunmamaktadır.',
            ], 403);
        }

        $serviceRequest->distance_km = $check['distance_km'];
        $serviceRequest->is_approximate_match = $check['is_approximate_match'];

        return response()->json([
            'success' => true,
            'data' => new ProviderMarketplaceRequestResource($serviceRequest),
        ]);
    }

    /**
     * Submit an offer for an open instant service request.
     */
    public function createOffer(int $requestId, Request $request, InstantMatchingService $matchingService): JsonResponse
    {
        $user = $request->user();

        $validated = $request->validate([
            'price' => 'required|numeric|min:1|max:50000',
            'duration_minutes' => 'nullable|integer|min:5|max:300',
            'estimated_arrival_min' => 'nullable|integer|in:15,30,45,60',
            'message' => 'nullable|string|max:500',
            'payment_preference' => 'nullable|string|in:ANY,CASH,ONLINE',
        ], [
            'price.required' => 'Lütfen bir teklif fiyatı belirtiniz.',
            'price.min' => 'Teklif tutarı en az ₺1.00 olmalıdır.',
            'price.max' => 'Teklif tutarı en fazla ₺50,000.00 olabilir.',
            'estimated_arrival_min.in' => 'Tahmini varış süresi 15, 30, 45 veya 60 dakika olarak seçilmelidir.',
        ]);

        $serviceRequest = ServiceRequest::find($requestId);
        if (!$serviceRequest) {
            return response()->json([
                'success' => false,
                'message' => 'Hizmet talebi bulunamadı.',
            ], 404);
        }

        if ($serviceRequest->status !== ServiceRequest::STATUS_OPEN) {
            return response()->json([
                'success' => false,
                'message' => 'Bu talep artık açık değil veya bir teklif kabul edilmiş.',
            ], 422);
        }

        if ($serviceRequest->isDirect()) {
            return response()->json([
                'success' => false,
                'message' => 'Bu size özel doğrudan bir taleptir; fiyatı müşterinin seçtiği hizmetle sabittir. Lütfen kabul edin veya reddedin.',
            ], 422);
        }

        // Check if provider already has an active offer for this request
        $existingOffer = ServiceOffer::where('service_request_id', $serviceRequest->id)
            ->where('provider_user_id', $user->id)
            ->where('status', ServiceOffer::STATUS_PENDING)
            ->exists();

        if ($existingOffer) {
            return response()->json([
                'success' => false,
                'message' => 'Bu ilana zaten aktif bir teklifiniz bulunmaktadır.',
            ], 422);
        }

        // Re-verify eligibility at the exact moment of offer submission
        $check = $matchingService->isProviderEligibleForRequest($user, $serviceRequest);
        if (!$check['eligible']) {
            return response()->json([
                'success' => false,
                'message' => $check['reason'] ?? 'Bu talep için uygunluk kriterlerini karşılamıyorsunuz.',
            ], 422);
        }

        // Financial Eligibility: For CASH requests, provider wallet must be able to afford the commission
        $paymentMethod = strtoupper($serviceRequest->payment_method ?? 'CASH');
        if ($paymentMethod === 'CASH') {
            $financialService = app(\App\Services\FinancialService::class);
            $commission = $financialService->calculateCommission($user->id, (string) $validated['price']);
            if (!$financialService->canProviderAffordCommission($user->id, $commission['commission_amount'])) {
                return response()->json([
                    'success' => false,
                    'message' => \App\Services\FinancialService::MSG_INSUFFICIENT_COMMISSION,
                    'code' => \App\Services\FinancialService::CODE_INSUFFICIENT_COMMISSION,
                    'hint' => \App\Services\FinancialService::HINT_INSUFFICIENT_COMMISSION,
                ], 422);
            }
        }

        $offer = ServiceOffer::create([
            'service_request_id' => $serviceRequest->id,
            'provider_user_id' => $user->id,
            'price' => $validated['price'],
            'duration_minutes' => $validated['duration_minutes'] ?? 30,
            'estimated_arrival_min' => $validated['estimated_arrival_min'] ?? 30,
            'payment_preference' => $paymentMethod,
            'message' => $validated['message'] ?? null,
            'status' => ServiceOffer::STATUS_PENDING,
        ]);

        app(\App\Services\NotificationService::class)->notifyUser(
            $serviceRequest->customer_user_id,
            \App\Models\UserNotification::TYPE_OFFER_RECEIVED,
            'Yeni Hizmet Teklifi',
            'Hemen Çağır talebinize yeni bir teklif geldi.',
            \App\Models\UserNotification::RESOURCE_INSTANT_REQUEST,
            $serviceRequest->id,
            '/customer',
            [
                'service_request_id' => $serviceRequest->id,
                'offer_id' => $offer->id,
                'price' => (float) $offer->price,
            ],
            "OFFER_RECEIVED:{$offer->id}:{$serviceRequest->customer_user_id}"
        );

        return response()->json([
            'success' => true,
            'message' => 'Teklifiniz müşteriye başarıyla iletildi.',
            'data' => new ServiceOfferResource($offer->load('provider.providerProfile')),
        ], 201);
    }

    /**
     * Accept a direct request at its snapshot price; assigns atomically through the canonical assignment flow.
     */
    public function acceptDirect(int $requestId, Request $request, InstantMatchingService $matchingService, InstantAssignmentService $assignment): JsonResponse
    {
        $user = $request->user();

        $validated = $request->validate([
            'estimated_arrival_min' => 'nullable|integer|in:15,30,45,60',
            'message' => 'nullable|string|max:500',
        ], [
            'estimated_arrival_min.in' => 'Tahmini varış süresi 15, 30, 45 veya 60 dakika olarak seçilmelidir.',
        ]);

        return DB::transaction(function () use ($user, $requestId, $validated, $matchingService, $assignment) {
            $serviceRequest = ServiceRequest::whereKey($requestId)->lockForUpdate()->first();

            if (!$serviceRequest || !$serviceRequest->isDirect() || (int) $serviceRequest->target_provider_user_id !== (int) $user->id) {
                return response()->json(['success' => false, 'message' => 'Size yönelik doğrudan talep bulunamadı.'], 404);
            }

            if ($serviceRequest->status !== ServiceRequest::STATUS_OPEN) {
                return response()->json(['success' => false, 'message' => 'Bu talep artık açık değil.'], 422);
            }

            $check = $matchingService->isProviderEligibleForRequest($user, $serviceRequest);
            if (!$check['eligible']) {
                return response()->json([
                    'success' => false,
                    'message' => $check['reason'] ?? 'Bu talebi şu anda kabul edemezsiniz.',
                ], 422);
            }

            $price = (string) $serviceRequest->snapshot_price;
            $paymentMethod = strtoupper($serviceRequest->payment_method ?? 'CASH');

            if ($paymentMethod === 'CASH') {
                $financialService = app(\App\Services\FinancialService::class);
                $commission = $financialService->calculateCommission($user->id, $price);
                if (!$financialService->canProviderAffordCommission($user->id, $commission['commission_amount'])) {
                    return response()->json([
                        'success' => false,
                        'message' => \App\Services\FinancialService::MSG_INSUFFICIENT_COMMISSION,
                        'code' => \App\Services\FinancialService::CODE_INSUFFICIENT_COMMISSION,
                        'hint' => \App\Services\FinancialService::HINT_INSUFFICIENT_COMMISSION,
                    ], 422);
                }
            }

            $offer = ServiceOffer::create([
                'service_request_id' => $serviceRequest->id,
                'provider_user_id' => $user->id,
                'price' => $price,
                'duration_minutes' => $serviceRequest->snapshot_duration_minutes ?? 30,
                'estimated_arrival_min' => $validated['estimated_arrival_min'] ?? 30,
                'payment_preference' => $paymentMethod,
                'message' => $validated['message'] ?? null,
                'status' => ServiceOffer::STATUS_PENDING,
            ]);

            $assignment->assign($serviceRequest, $offer);

            app(\App\Services\NotificationService::class)->notifyUser(
                $serviceRequest->customer_user_id,
                \App\Models\UserNotification::TYPE_INSTANT_ASSIGNED,
                'Uzman Talebinizi Kabul Etti',
                'Doğrudan çağırdığınız uzman talebinizi kabul etti ve yola çıkmaya hazırlanıyor.',
                \App\Models\UserNotification::RESOURCE_INSTANT_REQUEST,
                $serviceRequest->id,
                '/customer',
                [
                    'service_request_id' => $serviceRequest->id,
                    'price' => (float) $offer->price,
                    'estimated_arrival_min' => $offer->estimated_arrival_min,
                ],
                "INSTANT_ASSIGNED:{$serviceRequest->id}:{$serviceRequest->customer_user_id}"
            );

            return response()->json([
                'success' => true,
                'message' => 'Talebi kabul ettiniz. İş size atandı.',
                'data' => new ProviderMarketplaceRequestResource($serviceRequest->fresh(['services', 'category', 'servicePayment', 'disputeCase'])),
            ]);
        });
    }

    /**
     * Decline a direct request addressed to this provider.
     */
    public function declineDirect(int $requestId, Request $request): JsonResponse
    {
        $user = $request->user();

        $validated = $request->validate([
            'reason' => 'nullable|string|max:300',
        ]);

        return DB::transaction(function () use ($user, $requestId, $validated) {
            $serviceRequest = ServiceRequest::whereKey($requestId)->lockForUpdate()->first();

            if (!$serviceRequest || !$serviceRequest->isDirect() || (int) $serviceRequest->target_provider_user_id !== (int) $user->id) {
                return response()->json(['success' => false, 'message' => 'Size yönelik doğrudan talep bulunamadı.'], 404);
            }

            if ($serviceRequest->status !== ServiceRequest::STATUS_OPEN) {
                return response()->json(['success' => false, 'message' => 'Bu talep artık açık değil.'], 422);
            }

            $serviceRequest->status = ServiceRequest::STATUS_CANCELLED;
            $serviceRequest->cancelled_at = now();
            $serviceRequest->save();

            $reason = trim((string) ($validated['reason'] ?? ''));

            app(\App\Services\NotificationService::class)->notifyUser(
                $serviceRequest->customer_user_id,
                \App\Models\UserNotification::TYPE_DIRECT_REQUEST_DECLINED,
                'Uzman Talebinizi Yanıtlayamadı',
                'Çağırdığınız uzman şu anda talebinizi kabul edemedi.' . ($reason !== '' ? " Not: {$reason}" : '') . ' Genel Hemen Çağır ile diğer uzmanlardan teklif alabilirsiniz.',
                \App\Models\UserNotification::RESOURCE_INSTANT_REQUEST,
                $serviceRequest->id,
                '/customer',
                ['service_request_id' => $serviceRequest->id],
                "DIRECT_REQUEST_DECLINED:{$serviceRequest->id}:{$serviceRequest->customer_user_id}"
            );

            return response()->json([
                'success' => true,
                'message' => 'Talep reddedildi.',
            ]);
        });
    }

    /**
     * List requests assigned to this provider.
     */
    public function assigned(Request $request): JsonResponse
    {
        $user = $request->user();

        $assignedRequests = ServiceRequest::where('assigned_provider_user_id', $user->id)
            ->with(['services', 'category', 'customer', 'servicePayment', 'disputeCase'])
            ->orderBy('assigned_at', 'desc')
            ->get();

        return response()->json([
            'success' => true,
            'data' => ProviderMarketplaceRequestResource::collection($assignedRequests),
        ]);
    }

    /**
     * List all offers created by this provider.
     */
    public function myOffers(Request $request): JsonResponse
    {
        $user = $request->user();

        $offers = ServiceOffer::where('provider_user_id', $user->id)
            ->with(['serviceRequest.services', 'serviceRequest.category', 'serviceRequest.servicePayment', 'serviceRequest.disputeCase'])
            ->orderBy('created_at', 'desc')
            ->get();

        return response()->json([
            'success' => true,
            'data' => ServiceOfferResource::collection($offers),
        ]);
    }
}
