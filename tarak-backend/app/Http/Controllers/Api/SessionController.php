<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SessionController extends Controller
{
    /**
     * List the authenticated user's active sessions (Sanctum personal access
     * tokens). Raw token values are NEVER returned — only safe metadata.
     */
    public function index(Request $request): JsonResponse
    {
        $currentId = $request->user()->currentAccessToken()?->id;

        $sessions = $request->user()->tokens()
            ->latest('last_used_at')
            ->get()
            ->map(fn ($t) => [
                'id' => $t->id,
                // Legacy tokens were all created under one internal label;
                // don't present that as a device name.
                'name' => ($t->name === '' || $t->name === null || $t->name === 'auth_token')
                    ? 'Bilinmeyen cihaz'
                    : $t->name,
                'last_used_at' => $t->last_used_at?->toIso8601String(),
                'created_at' => $t->created_at?->toIso8601String(),
                'is_current' => $t->id === $currentId,
            ]);

        return response()->json(['success' => true, 'data' => $sessions]);
    }

    /**
     * Revoke a specific session by token id (cannot revoke the current one here;
     * use logout for that).
     */
    public function destroy(Request $request, int $id): JsonResponse
    {
        $currentId = $request->user()->currentAccessToken()?->id;
        if ($id === $currentId) {
            return response()->json(['success' => false, 'message' => 'Mevcut oturumu buradan kapatamazsınız; çıkış yapın.'], 422);
        }

        $deleted = $request->user()->tokens()->where('id', $id)->delete();
        if (! $deleted) {
            return response()->json(['success' => false, 'message' => 'Oturum bulunamadı.'], 404);
        }

        return response()->json(['success' => true, 'message' => 'Oturum kapatıldı.']);
    }

    /**
     * Revoke all sessions except the current one.
     */
    public function destroyOthers(Request $request): JsonResponse
    {
        $currentId = $request->user()->currentAccessToken()?->id;
        $request->user()->tokens()->where('id', '!=', $currentId)->delete();

        return response()->json(['success' => true, 'message' => 'Diğer tüm oturumlar kapatıldı.']);
    }
}
