<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\DisputeService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AdminDisputeController extends Controller
{
    public function __construct(
        protected DisputeService $disputeService
    ) {}

    /**
     * List all dispute cases with pagination and filters.
     * Protected: ADMIN only.
     */
    public function index(Request $request): JsonResponse
    {
        $filters = [
            'status' => $request->query('status'),
            'resource_type' => $request->query('resource_type'),
            'payment_method' => $request->query('payment_method'),
            'search' => $request->query('search'),
        ];

        $perPage = min(50, max(1, (int) $request->query('per_page', 15)));
        $paginator = $this->disputeService->listDisputes($filters, $perPage);

        return response()->json([
            'success' => true,
            'data' => $paginator->items(),
            'pagination' => [
                'current_page' => $paginator->currentPage(),
                'last_page' => $paginator->lastPage(),
                'per_page' => $paginator->perPage(),
                'total' => $paginator->total(),
            ],
        ]);
    }

    /**
     * Get detailed dispute case projection.
     * Protected: ADMIN only.
     */
    public function show(string|int $id, Request $request): JsonResponse
    {
        $cleanId = is_numeric($id) ? (int) $id : (int) preg_replace('/[^0-9]/', '', (string) $id);
        $detail = $this->disputeService->getDisputeDetail($cleanId);

        return response()->json([
            'success' => true,
            'data' => $detail,
        ]);
    }

    /**
     * Start review on a dispute case (OPEN -> UNDER_REVIEW).
     * Protected: ADMIN only.
     */
    public function startReview(string|int $id, Request $request): JsonResponse
    {
        $admin = $request->user();
        $cleanId = is_numeric($id) ? (int) $id : (int) preg_replace('/[^0-9]/', '', (string) $id);
        $case = $this->disputeService->startReview($cleanId, $admin);

        return response()->json([
            'success' => true,
            'message' => 'Uyuşmazlık incelemeye alındı.',
            'data' => [
                'id' => $case->id,
                'status' => $case->status,
                'review_started_at' => $case->review_started_at?->toISOString(),
            ],
        ]);
    }

    /**
     * Resolve a dispute case (CUSTOMER_FAVOR or PROVIDER_FAVOR).
     * Protected: ADMIN only.
     */
    public function resolve(string|int $id, Request $request): JsonResponse
    {
        $cleanId = is_numeric($id) ? (int) $id : (int) preg_replace('/[^0-9]/', '', (string) $id);
        $validated = $request->validate([
            'resolution' => 'required|string',
            'admin_note' => 'required|string|min:3|max:2000',
        ], [
            'resolution.required' => 'Nihai karar (resolution) alanı zorunludur.',
            'admin_note.required' => 'Karar gerekçesi ve çözüm açıklaması girilmesi zorunludur.',
            'admin_note.min' => 'Açıklama en az 3 karakter olmalıdır.',
        ]);

        $admin = $request->user();
        $case = $this->disputeService->resolve(
            $id,
            $admin,
            $validated['resolution'],
            $validated['admin_note']
        );

        return response()->json([
            'success' => true,
            'message' => 'Uyuşmazlık başarıyla karara bağlandı.',
            'data' => [
                'id' => $case->id,
                'status' => $case->status,
                'admin_resolution' => $case->admin_resolution,
                'resolved_at' => $case->resolved_at?->toISOString(),
            ],
        ]);
    }
}
