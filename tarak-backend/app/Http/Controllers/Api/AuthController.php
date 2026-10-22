<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\LoginRequest;
use App\Http\Requests\RegisterRequest;
use App\Http\Resources\UserResource;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

class AuthController extends Controller
{
    /**
     * Register new customer or provider.
     */
    public function register(RegisterRequest $request): JsonResponse
    {
        $validated = $request->validated();

        // Extra guard: ADMIN cannot be registered publicly
        if ($validated['role'] === User::ROLE_ADMIN) {
            return response()->json([
                'success' => false,
                'message' => 'Admin hesabı bu yöntemle oluşturulamaz.',
            ], 403);
        }

        $user = DB::transaction(function () use ($validated) {
            $user = User::create([
                'role' => $validated['role'],
                'first_name' => $validated['first_name'],
                'last_name' => $validated['last_name'],
                'name' => trim($validated['first_name'] . ' ' . $validated['last_name']),
                'email' => $validated['email'] ?? null,
                'phone' => $validated['phone'] ?? null,
                'password' => Hash::make($validated['password']),
                'gender' => $validated['gender'] ?? 'unspecified',
                'status' => 'active',
            ]);

            if ($user->role === User::ROLE_CUSTOMER) {
                $user->customerProfile()->create([
                    'profile_completed' => false,
                ]);
            } elseif ($user->role === User::ROLE_PROVIDER) {
                $user->providerProfile()->create([
                    'provider_type' => $validated['provider_type'] ?? 'barber',
                    'business_name' => $validated['business_name'] ?? null,
                    'is_approved' => false,
                    'identity_status' => 'PENDING',
                    'is_online' => false,
                    'accepts_new_clients' => true,
                    'service_radius_km' => 10,
                    'experience_years' => 1,
                ]);

                // Wallet initial balance is 0. Welcome promo is NOT granted on registration!
                $user->wallet()->create([
                    'balance' => 0.00,
                    'currency' => 'TRY',
                    'is_frozen' => false,
                ]);
            }

            return $user;
        });

        $user->load(['customerProfile', 'providerProfile', 'wallet']);
        $token = $user->createToken($this->deviceTokenName($request))->plainTextToken;

        return response()->json([
            'success' => true,
            'message' => 'Kayıt başarıyla tamamlandı.',
            'data' => [
                'user' => new UserResource($user),
                'token' => $token,
                'token_type' => 'Bearer',
            ],
        ], 201);
    }

    /**
     * Authenticate user and issue Sanctum token.
     */
    public function login(LoginRequest $request): JsonResponse
    {
        $identifier = $request->input('login')
            ?? $request->input('email')
            ?? $request->input('phone');

        if (empty($identifier)) {
            return response()->json([
                'success' => false,
                'message' => 'Giriş bilgileri hatalı.',
            ], 401);
        }

        $user = User::where(function ($query) use ($identifier) {
            $normEmail = User::normalizeEmail($identifier);
            $normPhone = User::normalizePhone($identifier);

            if ($normEmail) {
                $query->orWhere('email', $normEmail);
            }
            if ($normPhone) {
                $query->orWhere('phone', $normPhone);
            }

            $query->orWhere('email', strtolower(trim($identifier)))
                  ->orWhere('phone', $identifier);
        })->first();

        if (!$user || !Hash::check($request->password, $user->password)) {
            return response()->json([
                'success' => false,
                'message' => 'Giriş bilgileri hatalı.',
            ], 401);
        }

        if ($user->status !== 'active') {
            return response()->json([
                'success' => false,
                'message' => 'Hesabınız aktif değil.',
            ], 403);
        }

        $user->update(['last_login_at' => now()]);
        $user->load(['customerProfile', 'providerProfile', 'wallet']);

        $token = $user->createToken($this->deviceTokenName($request))->plainTextToken;

        return response()->json([
            'success' => true,
            'message' => 'Giriş başarılı.',
            'data' => [
                'user' => new UserResource($user),
                'token' => $token,
                'token_type' => 'Bearer',
            ],
        ]);
    }

    /**
     * Revoke current access token.
     */
    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()?->delete();

        return response()->json([
            'success' => true,
            'message' => 'Çıkış yapıldı.',
        ]);
    }

    /**
     * Return authenticated user.
     */
    public function me(Request $request): JsonResponse
    {
        $user = $request->user()->load(['customerProfile', 'providerProfile', 'wallet']);

        return response()->json([
            'success' => true,
            'data' => [
                'user' => new UserResource($user),
            ],
        ]);
    }

    /**
     * Change the authenticated user's password. Requires the current password.
     * Revokes all other tokens so other sessions are signed out.
     */
    public function changePassword(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'current_password' => ['required', 'string'],
            'new_password' => ['required', 'string', 'min:8', 'confirmed', 'different:current_password'],
        ], [
            'current_password.required' => 'Mevcut şifrenizi giriniz.',
            'new_password.required' => 'Yeni şifrenizi giriniz.',
            'new_password.min' => 'Yeni şifre en az 8 karakter olmalıdır.',
            'new_password.confirmed' => 'Yeni şifre tekrarı eşleşmiyor.',
            'new_password.different' => 'Yeni şifre mevcut şifreden farklı olmalıdır.',
        ]);

        $user = $request->user();

        if (!Hash::check($validated['current_password'], $user->password)) {
            return response()->json([
                'success' => false,
                'message' => 'Mevcut şifreniz hatalı.',
                'errors' => ['current_password' => ['Mevcut şifreniz hatalı.']],
            ], 422);
        }

        $user->password = $validated['new_password'];
        $user->save();

        // Keep the current token, revoke all others.
        $currentId = $user->currentAccessToken()?->id;
        $user->tokens()->when($currentId, fn ($q) => $q->where('id', '!=', $currentId))->delete();

        return response()->json([
            'success' => true,
            'message' => 'Şifreniz başarıyla güncellendi.',
        ]);
    }

    /**
     * Deactivate the authenticated user's own account (self-service).
     *
     * Safety rules:
     * - Requires current password confirmation.
     * - Blocked while the user has open service requests, appointments, or
     *   disputes (as customer OR provider), or an outstanding wallet balance —
     *   these must be resolved first so no financial/audit record is orphaned.
     * - Never hard-deletes: ServicePayment, PaymentRefund, WalletTransaction,
     *   AdminLog and ProviderReview rows are left completely untouched.
     * - The User row itself is soft-deleted (SoftDeletes) AND its personal
     *   data is anonymized in place, so it stops appearing in any normal
     *   query (including login) while financial/audit foreign keys pointing
     *   at user_id remain valid.
     * - All Sanctum tokens are revoked immediately; re-login is blocked both
     *   by the soft-delete global scope and by status !== 'active'.
     */
    public function deleteAccount(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'current_password' => ['required', 'string'],
        ], [
            'current_password.required' => 'Hesabınızı silmek için mevcut şifrenizi giriniz.',
        ]);

        $user = $request->user();

        if (!Hash::check($validated['current_password'], $user->password)) {
            return response()->json([
                'success' => false,
                'message' => 'Şifreniz hatalı.',
                'errors' => ['current_password' => ['Şifreniz hatalı.']],
            ], 422);
        }

        $blockingReason = $this->accountDeletionBlockingReason($user);
        if ($blockingReason) {
            return response()->json([
                'success' => false,
                'message' => $blockingReason,
            ], 409);
        }

        app(\App\Services\AccountDeletionService::class)->anonymizeAndDelete($user);

        return response()->json([
            'success' => true,
            'message' => 'Hesabınız kapatıldı.',
        ]);
    }

    /**
     * Returns a human-readable Turkish reason the account cannot be deleted
     * yet, or null if deletion may proceed.
     */
    /**
     * Human-readable name for the personal access token, so "Cihaz Oturumları"
     * can show the user which device a session belongs to instead of an
     * internal token label. Derived from the request's own User-Agent only.
     */
    private function deviceTokenName(Request $request): string
    {
        $agent = (string) $request->userAgent();

        if ($agent === '') {
            return 'Bilinmeyen cihaz';
        }

        $platform = match (true) {
            str_contains($agent, 'Android') => 'Android',
            (bool) preg_match('/iPhone|iPad|iOS/i', $agent) => 'iOS',
            str_contains($agent, 'Windows') => 'Windows',
            (bool) preg_match('/Mac OS X|Macintosh/i', $agent) => 'macOS',
            str_contains($agent, 'Linux') => 'Linux',
            default => 'Bilinmeyen cihaz',
        };

        $client = match (true) {
            str_contains($agent, 'Dart') || str_contains($agent, 'okhttp') => 'Mobil uygulama',
            str_contains($agent, 'Edg/') => 'Edge',
            str_contains($agent, 'OPR/') => 'Opera',
            str_contains($agent, 'Chrome') => 'Chrome',
            str_contains($agent, 'Firefox') => 'Firefox',
            str_contains($agent, 'Safari') => 'Safari',
            default => null,
        };

        return $client === null ? $platform : $platform . ' · ' . $client;
    }

    private function accountDeletionBlockingReason(User $user): ?string
    {
        return app(\App\Services\AccountDeletionService::class)->blockingReason($user);
    }
}
