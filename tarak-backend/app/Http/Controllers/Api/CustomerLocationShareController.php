<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\ShareLocationRequest;
use App\Models\Appointment;
use App\Models\LocationShareGrant;
use App\Models\ServiceRequest;
use App\Services\LocationGrantService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CustomerLocationShareController extends Controller
{
    public function __construct(
        protected LocationGrantService $locationGrantService
    ) {}

    /**
     * Share exact location for an assigned instant service request.
     */
    public function shareInstantLocation(ShareLocationRequest $request, int $id): JsonResponse
    {
        $serviceRequest = ServiceRequest::findOrFail($id);

        $grant = $this->locationGrantService->shareLocationForInstantRequest(
            customer: $request->user(),
            request: $serviceRequest,
            source: $request->input('source'),
            explicitConsent: (bool) $request->input('explicit_consent'),
            currentLocationCoordinates: $request->getCoordinates(),
            customerAddressId: $request->input('customer_address_id') ? (int) $request->input('customer_address_id') : null
        );

        return response()->json([
            'success' => true,
            'message' => 'Konum başarıyla paylaşıldı.',
            'data' => [
                'id' => $grant->id,
                'resource_type' => $grant->resource_type,
                'resource_id' => $grant->resource_id,
                'source' => $grant->source,
                'status' => $grant->status,
                'shared_at' => $grant->shared_at?->toISOString(),
                'expires_at' => $grant->expires_at?->toISOString(),
            ],
        ]);
    }

    /**
     * Revoke active location share for an instant service request.
     */
    public function revokeInstantLocation(Request $request, int $id): JsonResponse
    {
        $serviceRequest = ServiceRequest::findOrFail($id);

        $this->locationGrantService->revokeLocationForInstantRequest(
            customer: $request->user(),
            request: $serviceRequest
        );

        return response()->json([
            'success' => true,
            'message' => 'Konum paylaşımı başarıyla durduruldu.',
        ]);
    }

    /**
     * Check active location share grant status for an instant service request.
     */
    public function getInstantLocationStatus(Request $request, int $id): JsonResponse
    {
        $serviceRequest = ServiceRequest::findOrFail($id);

        if ((int) $serviceRequest->customer_user_id !== (int) $request->user()->id) {
            return response()->json([
                'success' => false,
                'message' => 'Bu talebe erişim yetkiniz yok.',
            ], 403);
        }

        $grant = $this->locationGrantService->getActiveGrantForCustomer(
            customer: $request->user(),
            resourceType: LocationShareGrant::RESOURCE_INSTANT_REQUEST,
            resourceId: $id
        );

        return response()->json([
            'success' => true,
            'has_active_grant' => $grant !== null,
            'grant' => $grant ? [
                'id' => $grant->id,
                'resource_type' => $grant->resource_type,
                'resource_id' => $grant->resource_id,
                'source' => $grant->source,
                'status' => $grant->status,
                'shared_at' => $grant->shared_at?->toISOString(),
                'expires_at' => $grant->expires_at?->toISOString(),
            ] : null,
        ]);
    }

    /**
     * Share exact location for a confirmed scheduled appointment.
     */
    public function shareAppointmentLocation(ShareLocationRequest $request, int $id): JsonResponse
    {
        $appointment = Appointment::findOrFail($id);

        $grant = $this->locationGrantService->shareLocationForAppointment(
            customer: $request->user(),
            appointment: $appointment,
            source: $request->input('source'),
            explicitConsent: (bool) $request->input('explicit_consent'),
            currentLocationCoordinates: $request->getCoordinates(),
            customerAddressId: $request->input('customer_address_id') ? (int) $request->input('customer_address_id') : null
        );

        return response()->json([
            'success' => true,
            'message' => 'Konum başarıyla paylaşıldı.',
            'data' => [
                'id' => $grant->id,
                'resource_type' => $grant->resource_type,
                'resource_id' => $grant->resource_id,
                'source' => $grant->source,
                'status' => $grant->status,
                'shared_at' => $grant->shared_at?->toISOString(),
                'expires_at' => $grant->expires_at?->toISOString(),
            ],
        ]);
    }

    /**
     * Revoke active location share for a scheduled appointment.
     */
    public function revokeAppointmentLocation(Request $request, int $id): JsonResponse
    {
        $appointment = Appointment::findOrFail($id);

        $this->locationGrantService->revokeLocationForAppointment(
            customer: $request->user(),
            appointment: $appointment
        );

        return response()->json([
            'success' => true,
            'message' => 'Konum paylaşımı başarıyla durduruldu.',
        ]);
    }

    /**
     * Check active location share grant status for a scheduled appointment.
     */
    public function getAppointmentLocationStatus(Request $request, int $id): JsonResponse
    {
        $appointment = Appointment::findOrFail($id);

        if ((int) $appointment->customer_user_id !== (int) $request->user()->id) {
            return response()->json([
                'success' => false,
                'message' => 'Bu randevuya erişim yetkiniz yok.',
            ], 403);
        }

        $grant = $this->locationGrantService->getActiveGrantForCustomer(
            customer: $request->user(),
            resourceType: LocationShareGrant::RESOURCE_SCHEDULED_APPOINTMENT,
            resourceId: $id
        );

        return response()->json([
            'success' => true,
            'has_active_grant' => $grant !== null,
            'grant' => $grant ? [
                'id' => $grant->id,
                'resource_type' => $grant->resource_type,
                'resource_id' => $grant->resource_id,
                'source' => $grant->source,
                'status' => $grant->status,
                'shared_at' => $grant->shared_at?->toISOString(),
                'expires_at' => $grant->expires_at?->toISOString(),
            ] : null,
        ]);
    }
}
