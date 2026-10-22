<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;

class HealthController extends Controller
{
    public function index(): JsonResponse
    {
        $dbStatus = 'connected';
        try {
            DB::connection()->getPdo();
        } catch (\Throwable $e) {
            $dbStatus = 'error';
        }

        $status = ($dbStatus === 'connected') ? 'ok' : 'degraded';

        return response()->json([
            'status' => $status,
            'database' => $dbStatus,
            'timestamp' => now()->toISOString(),
        ], $status === 'ok' ? 200 : 503);
    }

    /**
     * Readiness check for container orchestrators / load balancers.
     * Checks database and cache reachability without secret leakage.
     */
    public function ready(): JsonResponse
    {
        $dbReady = false;
        try {
            DB::connection()->getPdo();
            $dbReady = true;
        } catch (\Throwable $e) {
            $dbReady = false;
        }

        $cacheReady = false;
        try {
            \Illuminate\Support\Facades\Cache::set('__health_probe__', true, 10);
            $cacheReady = \Illuminate\Support\Facades\Cache::get('__health_probe__') === true;
        } catch (\Throwable $e) {
            $cacheReady = false;
        }

        $isReady = $dbReady && $cacheReady;

        return response()->json([
            'ready' => $isReady,
            'database' => $dbReady,
            'cache' => $cacheReady,
            'timestamp' => now()->toISOString(),
        ], $isReady ? 200 : 503);
    }
}

