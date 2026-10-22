<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\LocationShareGrant;
use App\Services\ServiceLifecycleService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ProviderServiceLifecycleController extends Controller
{
    public function __construct(
        protected ServiceLifecycleService $lifecycleService
    ) {}

    /**
     * Verify start code for an Instant Service Request and transition to IN_PROGRESS.
     */
    public function verifyInstantRequestStartCode(int $id, Request $request): JsonResponse
    {
        $request->validate([
            'code' => 'required|string',
        ]);

        $user = $request->user();
        $result = $this->lifecycleService->verifyStartCodeForProvider(
            $user,
            LocationShareGrant::RESOURCE_INSTANT_REQUEST,
            $id,
            $request->input('code')
        );

        return response()->json($result);
    }

    /**
     * Mark Instant Service Request as finished (transitions to AWAITING_CUSTOMER_CONFIRMATION).
     */
    public function finishInstantRequest(int $id, Request $request): JsonResponse
    {
        $user = $request->user();
        $result = $this->lifecycleService->providerMarkFinished(
            $user,
            LocationShareGrant::RESOURCE_INSTANT_REQUEST,
            $id
        );

        return response()->json($result);
    }

    /**
     * Verify start code for a Scheduled Appointment and transition to IN_PROGRESS.
     */
    public function verifyAppointmentStartCode(int $id, Request $request): JsonResponse
    {
        $request->validate([
            'code' => 'required|string',
        ]);

        $user = $request->user();
        $result = $this->lifecycleService->verifyStartCodeForProvider(
            $user,
            LocationShareGrant::RESOURCE_SCHEDULED_APPOINTMENT,
            $id,
            $request->input('code')
        );

        return response()->json($result);
    }

    /**
     * Mark Scheduled Appointment as finished (transitions to AWAITING_CUSTOMER_CONFIRMATION).
     */
    public function finishAppointment(int $id, Request $request): JsonResponse
    {
        $user = $request->user();
        $result = $this->lifecycleService->providerMarkFinished(
            $user,
            LocationShareGrant::RESOURCE_SCHEDULED_APPOINTMENT,
            $id
        );

        return response()->json($result);
    }
}
