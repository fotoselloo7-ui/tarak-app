<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\HomeStatsService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class HomeStatsController extends Controller
{
    public function __construct(private HomeStatsService $stats) {}

    /**
     * Public: resolved home-page statistics (real or admin-typed, per the admin's
     * mode). `audience` = all (landing) | customer | provider.
     */
    public function home(Request $request): JsonResponse
    {
        return response()->json([
            'success' => true,
            'data' => $this->stats->resolve((string) $request->query('audience', 'all')),
        ]);
    }
}
