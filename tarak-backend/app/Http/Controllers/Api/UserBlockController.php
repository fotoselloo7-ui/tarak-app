<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\UserBlock;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class UserBlockController extends Controller
{
    /**
     * Users the authenticated user has blocked.
     * GET /api/blocks
     */
    public function index(Request $request): JsonResponse
    {
        $blocks = UserBlock::query()
            ->where('blocker_user_id', $request->user()->id)
            ->with('blocked:id,name,role')
            ->latest()
            ->limit(200)
            ->get()
            ->map(fn (UserBlock $block) => [
                'user_id' => $block->blocked_user_id,
                'name' => $block->blocked?->name ?? 'Kullanıcı',
                'role' => $block->blocked?->role,
                'blocked_at' => $block->created_at?->toIso8601String(),
            ]);

        return response()->json(['success' => true, 'data' => $blocks]);
    }

    /**
     * Block a user: chat between the two is closed in both directions.
     * POST /api/blocks
     */
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'user_id' => ['required', 'integer', 'min:1'],
        ]);

        $blockerId = (int) $request->user()->id;
        $targetId = (int) $validated['user_id'];

        if ($targetId === $blockerId) {
            return response()->json(['success' => false, 'message' => 'Kendinizi engelleyemezsiniz.'], 422);
        }

        $target = User::query()->find($targetId);
        if (! $target) {
            return response()->json(['success' => false, 'message' => 'Kullanıcı bulunamadı.'], 404);
        }
        if ($target->role === User::ROLE_ADMIN) {
            return response()->json(['success' => false, 'message' => 'Yönetici hesapları engellenemez.'], 422);
        }

        $block = UserBlock::firstOrCreate([
            'blocker_user_id' => $blockerId,
            'blocked_user_id' => $targetId,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Kullanıcı engellendi. Artık birbirinize mesaj gönderemezsiniz.',
            'data' => ['user_id' => $targetId],
        ], $block->wasRecentlyCreated ? 201 : 200);
    }

    /**
     * Remove a block the authenticated user created.
     * DELETE /api/blocks/{user}
     */
    public function destroy(Request $request, int $user): JsonResponse
    {
        UserBlock::query()
            ->where('blocker_user_id', $request->user()->id)
            ->where('blocked_user_id', $user)
            ->delete();

        return response()->json([
            'success' => true,
            'message' => 'Engel kaldırıldı.',
            'data' => ['user_id' => $user],
        ]);
    }
}
