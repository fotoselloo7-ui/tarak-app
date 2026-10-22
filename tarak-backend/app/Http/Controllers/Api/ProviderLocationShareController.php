<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\LocationShareGrant;
use App\Services\LocationGrantService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

class ProviderLocationShareController extends Controller
{
    public function __construct(
        protected LocationGrantService $locationGrantService
    ) {}

    /**
     * Provider reads exact shared location for an assigned instant request.
     */
    public function getInstantSharedLocation(Request $request, int $id): JsonResponse
    {
        try {
            $sharedLocationData = $this->locationGrantService->getSharedLocationForProvider(
                provider: $request->user(),
                resourceType: LocationShareGrant::RESOURCE_INSTANT_REQUEST,
                resourceId: $id
            );

            return response()->json([
                'success' => true,
                'data' => $sharedLocationData,
            ]);
        } catch (NotFoundHttpException $e) {
            return response()->json([
                'success' => false,
                'message' => $e->getMessage(),
            ], 404);
        } catch (AccessDeniedHttpException $e) {
            return response()->json([
                'success' => false,
                'message' => $e->getMessage(),
            ], 403);
        }
    }

    /**
     * Provider reads exact shared location for a confirmed scheduled appointment.
     */
    public function getAppointmentSharedLocation(Request $request, int $id): JsonResponse
    {
        try {
            $sharedLocationData = $this->locationGrantService->getSharedLocationForProvider(
                provider: $request->user(),
                resourceType: LocationShareGrant::RESOURCE_SCHEDULED_APPOINTMENT,
                resourceId: $id
            );

            return response()->json([
                'success' => true,
                'data' => $sharedLocationData,
            ]);
        } catch (NotFoundHttpException $e) {
            return response()->json([
                'success' => false,
                'message' => $e->getMessage(),
            ], 404);
        } catch (AccessDeniedHttpException $e) {
            return response()->json([
                'success' => false,
                'message' => $e->getMessage(),
            ], 403);
        }
    }
}
