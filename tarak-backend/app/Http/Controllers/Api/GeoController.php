<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\GoogleGeocodingService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class GeoController extends Controller
{
    public function __construct(private GoogleGeocodingService $geocoding) {}

    /** Public browser key is intentionally returned to the existing web registration form. */
    public function config(): JsonResponse
    {
        $key = trim((string) config('services.google_maps.browser_key'));
        if ($key === '') {
            return response()->json([
                'success' => false,
                'message' => 'Google Maps tarayıcı anahtarı henüz yapılandırılmadı.',
            ], 503);
        }

        return response()->json([
            'success' => true,
            'data' => [
                'browser_key' => $key,
                'map_id' => config('services.google_maps.map_id'),
            ],
        ]);
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
