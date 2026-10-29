<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\UserResource;
use App\Models\User;
use App\Services\SocialIdentityVerifier;
use Illuminate\Database\QueryException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class SocialAuthController extends Controller
{
    public function __construct(private SocialIdentityVerifier $verifier) {}

    public function config(): JsonResponse
    {
        return response()->json(['success' => true, 'data' => [
            'google_client_id' => config('services.google.web_client_id') ?: null,
            'google_ios_client_id' => config('services.google.ios_client_id') ?: null,
            'apple_client_id' => config('services.apple.service_id') ?: null,
            'apple_redirect_uri' => config('services.apple.redirect_uri') ?: null,
        ]])->header('Cache-Control', 'no-store');
    }

    public function nonce(): JsonResponse
    {
        return response()->json(['success' => true, 'data' => [
            'nonce' => $this->verifier->issueNonce(),
        ]])->header('Cache-Control', 'no-store');
    }

    public function prefill(Request $request, string $provider): JsonResponse
    {
        $identity = $this->verifiedIdentity($request, $provider);
        $proof = bin2hex(random_bytes(32));
        DB::table('social_auth_attempts')->insert([
            'token_hash' => $this->proofHash($proof),
            'provider' => $provider,
            'subject' => $identity['subject'],
            'email' => $identity['email'],
            'email_verified' => $identity['email_verified'],
            'first_name' => mb_substr($identity['first_name'], 0, 100),
            'last_name' => mb_substr($identity['last_name'], 0, 100),
            'expires_at' => now()->addMinutes(10),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        return response()->json(['success' => true, 'data' => [
            'first_name' => $identity['first_name'],
            'last_name' => $identity['last_name'],
            'email' => $identity['email'],
            'email_verified' => $identity['email_verified'],
            'social_prefill_token' => $proof,
        ]])->header('Cache-Control', 'no-store');
    }

    public function login(Request $request, string $provider): JsonResponse
    {
        $identity = $this->verifiedIdentity($request, $provider);
        $user = $this->resolveLoginUser($provider, $identity);
        if ($user instanceof JsonResponse) {
            return $user;
        }

        if (!$user) {
            return response()->json([
                'success' => false,
                'message' => 'Bu e-posta ile kayıtlı bir Tarak hesabı bulunamadı. Önce Müşteri veya Hizmet Veren kaydı oluşturun.',
            ], 409);
        }
        if ($user->status !== 'active') {
            return response()->json(['success' => false, 'message' => 'Hesabınız aktif değil.'], 403);
        }

        $user->update(['last_login_at' => now()]);
        $user->load(['customerProfile', 'providerProfile', 'wallet']);

        return response()->json(['success' => true, 'message' => 'Giriş başarılı.', 'data' => [
            'user' => new UserResource($user),
            'token' => $user->createToken('Sosyal giriş')->plainTextToken,
            'token_type' => 'Bearer',
        ]]);
    }

    /** Never reassign a subject, including when the previous account was soft-deleted. */
    private function resolveLoginUser(string $provider, array $identity): User|JsonResponse|null
    {
        $conflict = fn () => response()->json([
            'success' => false, 'message' => 'Bu sağlayıcı hesabı farklı bir Tarak hesabına bağlı.',
        ], 409);
        try {
            return DB::transaction(function () use ($provider, $identity, $conflict) {
                $link = DB::table('social_identities')->where('provider', $provider)
                    ->where('subject', $identity['subject'])->lockForUpdate()->first();
                if ($link) {
                    $user = User::find($link->user_id);
                    if (!$user) return $conflict();
                    if ($identity['email_verified'] && $identity['email'] && User::query()
                        ->whereRaw('LOWER(email) = ?', [$identity['email']])->where('id', '!=', $user->id)->exists()) {
                        return $conflict();
                    }
                    return $user;
                }
                if (!$identity['email_verified'] || !$identity['email']) return null;
                $user = User::query()->whereRaw('LOWER(email) = ?', [$identity['email']])
                    ->lockForUpdate()->first();
                if (!$user) return null;
                if ($user->status !== 'active') {
                    return response()->json(['success' => false, 'message' => 'Hesabınız aktif değil.'], 403);
                }
                $existing = DB::table('social_identities')->where('provider', $provider)
                    ->where('user_id', $user->id)->lockForUpdate()->first();
                if ($existing && $existing->subject !== $identity['subject']) return $conflict();
                if (!$existing) {
                    // INSERT plus the two unique indexes protects concurrent first logins.
                    // updateOrInsert could overwrite another account's link after a race.
                    DB::table('social_identities')->insert([
                        'provider' => $provider, 'subject' => $identity['subject'], 'user_id' => $user->id,
                        'email_at_link' => $identity['email'], 'created_at' => now(), 'updated_at' => now(),
                    ]);
                }
                if (!$user->email_verified_at) $user->update(['email_verified_at' => now()]);
                return $user;
            });
        } catch (QueryException $exception) {
            if (in_array((string) $exception->getCode(), ['23000', '23505'], true)) return $conflict();
            throw $exception;
        }
    }

    public function link(Request $request, string $provider): JsonResponse
    {
        $request->validate(['current_password' => ['required', 'string']]);
        if (!Hash::check((string) $request->input('current_password'), $request->user()->password)) {
            throw ValidationException::withMessages(['current_password' => 'Mevcut şifreniz hatalı.']);
        }

        $identity = $this->verifiedIdentity($request, $provider);
        $existing = DB::table('social_identities')->where('provider', $provider)
            ->where('subject', $identity['subject'])->first();
        if ($existing && (int) $existing->user_id !== (int) $request->user()->id) {
            return response()->json(['success' => false, 'message' => 'Bu sağlayıcı hesabı başka bir kullanıcıya bağlı.'], 409);
        }

        try {
            DB::table('social_identities')->updateOrInsert(
                ['user_id' => $request->user()->id, 'provider' => $provider],
                ['subject' => $identity['subject'], 'email_at_link' => $identity['email'], 'updated_at' => now(), 'created_at' => now()],
            );
        } catch (QueryException $exception) {
            return response()->json(['success' => false, 'message' => 'Bu sağlayıcı hesabı başka bir kullanıcıya bağlı.'], 409);
        }

        return response()->json(['success' => true, 'message' => 'Sağlayıcı hesabı bağlandı.']);
    }

    private function verifiedIdentity(Request $request, string $provider): array
    {
        $validated = $request->validate([
            'id_token' => ['required', 'string', 'max:10000'],
            'nonce' => ['required', 'string', 'size:48', 'regex:/^[a-f0-9]+$/'],
            'authorization_code' => ['nullable', 'string', 'max:3000'],
        ]);

        return $this->verifier->verify(
            $provider,
            $validated['id_token'],
            $validated['nonce'],
            $validated['authorization_code'] ?? null,
        );
    }

    private function proofHash(string $proof): string
    {
        return hash_hmac('sha256', $proof, (string) config('app.key'));
    }
}
