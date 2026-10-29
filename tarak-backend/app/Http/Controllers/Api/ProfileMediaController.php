<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\UserResource;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use App\Support\MediaUrl;

/**
 * Canonical profile-media (avatar) capability shared by ALL authenticated
 * roles (customer, provider, admin). users.avatar_url is the single
 * source of truth. Files live on the PUBLIC disk — never mixed with the
 * private KYC document storage (see ProviderProfileController@uploadDocument).
 */
class ProfileMediaController extends Controller
{
    private const MAX_KB = 4096; // 4MB

    public function uploadAvatar(Request $request): JsonResponse
    {
        $request->validate([
            'avatar' => ['required', 'file', 'mimes:jpg,jpeg,png,webp', 'max:' . self::MAX_KB],
        ], [
            'avatar.required' => 'Lütfen bir görsel seçiniz.',
            'avatar.mimes' => 'Yalnızca JPG, JPEG, PNG veya WEBP formatı kabul edilir.',
            'avatar.max' => 'Görsel boyutu en fazla 4 MB olabilir.',
        ]);

        $user = $request->user();
        $file = $request->file('avatar');
        $extension = strtolower($file->getClientOriginalExtension() ?: $file->extension());
        $filename = (string) Str::uuid() . '.' . $extension;
        $path = $file->storeAs('avatars/' . $user->id, $filename, 'public');
        $url = MediaUrl::fromPublicPath($path);

        $oldPath = self::managedPublicPath($user->avatar_url);
        $user->update(['avatar_url' => $url]);

        if ($oldPath && $oldPath !== $path) {
            Storage::disk('public')->delete($oldPath);
        }

        return response()->json([
            'success' => true,
            'message' => 'Profil fotoğrafınız güncellendi.',
            'data' => [
                'avatar_url' => $url,
                'user' => new UserResource($user->fresh()),
            ],
        ]);
    }

    public function destroyAvatar(Request $request): JsonResponse
    {
        $user = $request->user();
        $oldPath = self::managedPublicPath($user->avatar_url);

        $user->update(['avatar_url' => null]);

        if ($oldPath) {
            Storage::disk('public')->delete($oldPath);
        }

        return response()->json([
            'success' => true,
            'message' => 'Profil fotoğrafınız kaldırıldı.',
            'data' => ['avatar_url' => null],
        ]);
    }

    /**
     * Resolves $url to a disk-relative path IF AND ONLY IF it points into a
     * folder we manage on the public disk. Returns null for any external,
     * legacy, or foreign URL so we never attempt to delete a path we don't
     * own (arbitrary-path safety).
     */
    public static function managedPublicPath(?string $url): ?string
    {
        return MediaUrl::managedPublicPath($url);
    }
}
