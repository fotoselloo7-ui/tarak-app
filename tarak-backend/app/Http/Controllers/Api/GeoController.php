<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\GoogleGeocodingService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class GeoController extends Controller
{
    public function __construct(private GoogleGeocodingService $geocoding) {}

    /** Public map configuration; no API key is required. */
    public function config(): JsonResponse
    {
        return response()->json([
            'success' => true,
            'data' => [
                'provider' => 'openfreemap',
                'style_url' => 'https://tiles.openfreemap.org/styles/liberty',
            ],
        ])->header('Cache-Control', 'public, max-age=3600');
    }

    public function search(Request $request): JsonResponse
    {
        $request->merge(['q' => trim((string) $request->query('q', ''))]);
        $validated = $request->validate([
            'q' => ['required', 'string', 'min:3', 'max:200'],
        ]);

        return $this->respond($this->geocoding->search(trim($validated['q'])));
    }

    public function reverse(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'lat' => ['required', 'numeric', 'between:-90,90'],
            'lng' => ['required', 'numeric', 'between:-180,180'],
        ]);

        return $this->respond($this->geocoding->reverse((float) $validated['lat'], (float) $validated['lng']));
    }

    /** @param array<string, mixed> $result */
    private function respond(array $result): JsonResponse
    {
        return match ($result['status'] ?? null) {
            'OK' => response()->json(['success' => true, 'data' => $result['data']]),
            'ZERO_RESULTS' => response()->json(['success' => false, 'message' => 'Bu konum için adres bulunamadı. Alanları elle düzenleyebilirsiniz.'], 404),
            'NOT_CONFIGURED' => response()->json(['success' => false, 'message' => 'Harita adres arama servisi henüz yapılandırılmadı.'], 503),
            default => response()->json(['success' => false, 'message' => 'Harita adres arama servisine şu anda ulaşılamıyor.'], 503),
        };
    }
}
