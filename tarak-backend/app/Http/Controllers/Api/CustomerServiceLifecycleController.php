<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\LocationShareGrant;
use App\Services\ServiceLifecycleService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CustomerServiceLifecycleController extends Controller
{
    public function __construct(
        protected ServiceLifecycleService $lifecycleService
    ) {}

    /**
     * Get start verification code for an Instant Service Request.
     */
    public function getInstantRequestStartCode(int $id, Request $request): JsonResponse
    {
        $user = $request->user();
        $result = $this->lifecycleService->getStartCodeForCustomer(
            $user,
            LocationShareGrant::RESOURCE_INSTANT_REQUEST,
            $id
        );

        return response()->json([
            'success' => true,
            'data' => $result,
        ]);
    }

    /**
     * Regenerate start verification code for an Instant Service Request.
     */
    public function regenerateInstantRequestStartCode(int $id, Request $request): JsonResponse
    {
        $user = $request->user();
        $result = $this->lifecycleService->regenerateStartCodeForCustomer(
            $user,
            LocationShareGrant::RESOURCE_INSTANT_REQUEST,
            $id
        );

        return response()->json([
            'success' => true,
            'message' => 'Yeni hizmet başlangıç kodu oluşturuldu.',
            'data' => $result,
        ]);
    }

    /**
     * Confirm completion for an Instant Service Request.
     */
    public function completeInstantRequest(int $id, Request $request): JsonResponse
    {
        $user = $request->user();
        $result = $this->lifecycleService->customerConfirmCompletion(
            $user,
            LocationShareGrant::RESOURCE_INSTANT_REQUEST,
            $id
        );

        return response()->json($result);
    }

    /**
     * Report problem/dispute for an Instant Service Request.
     */
    public function reportProblemInstantRequest(int $id, Request $request): JsonResponse
    {
        $request->validate([
            'reason' => 'required|string|max:255',
            'note' => 'nullable|string|max:1000',
        ]);

        $user = $request->user();
        $result = $this->lifecycleService->customerReportProblem(
            $user,
            LocationShareGrant::RESOURCE_INSTANT_REQUEST,
            $id,
            $request->input('reason'),
            $request->input('note')
        );

        return response()->json($result);
    }

    /**
     * Get start verification code for a Scheduled Appointment.
     */
    public function getAppointmentStartCode(int $id, Request $request): JsonResponse
    {
        $user = $request->user();
        $result = $this->lifecycleService->getStartCodeForCustomer(
            $user,
            LocationShareGrant::RESOURCE_SCHEDULED_APPOINTMENT,
            $id
        );

        return response()->json([
            'success' => true,
            'data' => $result,
        ]);
    }

    /**
     * Regenerate start verification code for a Scheduled Appointment.
     */
    public function regenerateAppointmentStartCode(int $id, Request $request): JsonResponse
    {
        $user = $request->user();
        $result = $this->lifecycleService->regenerateStartCodeForCustomer(
            $user,
            LocationShareGrant::RESOURCE_SCHEDULED_APPOINTMENT,
            $id
        );

        return response()->json([
            'success' => true,
            'message' => 'Yeni hizmet başlangıç kodu oluşturuldu.',
            'data' => $result,
        ]);
    }

    /**
     * Confirm completion for a Scheduled Appointment.
     */
    public function completeAppointment(int $id, Request $request): JsonResponse
    {
        $user = $request->user();
        $result = $this->lifecycleService->customerConfirmCompletion(
            $user,
            LocationShareGrant::RESOURCE_SCHEDULED_APPOINTMENT,
            $id
        );

        return response()->json($result);
    }

    /**
     * Report problem/dispute for a Scheduled Appointment.
     */
    public function reportProblemAppointment(int $id, Request $request): JsonResponse
    {
        $request->validate([
            'reason' => 'required|string|max:255',
            'note' => 'nullable|string|max:1000',
        ]);

        $user = $request->user();
        $result = $this->lifecycleService->customerReportProblem(
            $user,
            LocationShareGrant::RESOURCE_SCHEDULED_APPOINTMENT,
            $id,
            $request->input('reason'),
            $request->input('note')
        );

        return response()->json($result);
    }
}
