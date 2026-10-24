<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;

/** Returns only public, tightly restricted browser OAuth and map identifiers. */
class RegistrationPublicConfigController extends Controller
{
    public function index(): JsonResponse
    {
        return response()->json([
            'success' => true,
            'data' => [
                'google_client_id' => (string) config('services.google_oauth.web_client_id', ''),
                'maps_browser_api_key' => (string) config('services.google_maps.browser_api_key', ''),
            ],
        ]);
    }
}
