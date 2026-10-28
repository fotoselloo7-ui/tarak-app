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
        $link = DB::table('social_identities')->where('provider', $provider)
            ->where('subject', $identity['subject'])->first();
        $user = $link ? User::find($link->user_id) : null;

        if (!$user) {
            return response()->json([
                'success' => false,
                'message' => 'Bu sağlayıcı hesabı mevcut bir Tarak hesabına bağlı değil. Önce kayıt olun veya şifrenizle giriş yapıp hesabınızı bağlayın.',
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
