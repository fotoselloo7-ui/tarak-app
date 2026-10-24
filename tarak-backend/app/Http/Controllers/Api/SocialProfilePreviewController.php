<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Google\Auth\AccessToken;
use Firebase\JWT\JWT;
use Firebase\JWT\JWK;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;

class SocialProfilePreviewController extends Controller
{
    /**
     * No User and no auth token is issued. Social identity is used ONLY
     * to prefill an editable registration form. Actual account creation
     * requires explicit user submit and mailbox verification.
     */
    public function preview(Request $request): JsonResponse
    {
        $input = $request->validate([
            'provider' => ['required', 'in:google,apple'],
            'identity_token' => ['required', 'string', 'max:12000'],
            'first_name' => ['nullable', 'string', 'max:50'],
            'last_name' => ['nullable', 'string', 'max:50'],
        ]);

        try {
            if ($input['provider'] === 'google') {
                $client = (string) config('services.google_oauth.web_client_id', '');
                if ($client === '') {
                    return response()->json(['success' => false, 'message' => 'Google ile bağlantı henüz yapılandırılmadı.'], 503);
                }
                $claims = (new AccessToken())->verify($input['identity_token']);
                if (!is_array($claims)
                    || !hash_equals($client, (string) ($claims['aud'] ?? ''))
                    || !in_array($claims['iss'] ?? null, ['accounts.google.com','https://accounts.google.com'], true)
                    || !in_array($claims['email_verified'] ?? false, [true, 'true', 1, '1'], true)) {
                    throw new \RuntimeException('invalid google identity');
                }
                $first = (string) ($claims['given_name'] ?? '');
                $last = (string) ($claims['family_name'] ?? '');
            } else {
                $client = (string) config('services.apple_oauth.bundle_id', 'app.tarak.mobile');
                $jwks = Cache::remember('social:apple-public-jwks', 3600, static function () {
                    $resp = Http::timeout(8)->get('https://appleid.apple.com/auth/keys');
                    $resp->throw();
                    return $resp->json();
                });
                if (!is_array($jwks) || empty($jwks['keys'])) {
                    throw new \RuntimeException('apple keys unavailable');
                }
                $claims = (array) JWT::decode($input['identity_token'], JWK::parseKeySet($jwks, 'RS256'));
                if (!hash_equals($client, (string) ($claims['aud'] ?? ''))
                    || ($claims['iss'] ?? null) !== 'https://appleid.apple.com'
                    || !in_array($claims['email_verified'] ?? false, [true, 'true', 1, '1'], true)) {
                    throw new \RuntimeException('invalid apple identity');
                }
                // Apple supplies names only on first sign-in, so client-provided
                // names are untrusted suggestions editable before registration.
                $first = (string) ($input['first_name'] ?? '');
                $last = (string) ($input['last_name'] ?? '');
            }
        } catch (\Throwable $e) {
            return response()->json(['success' => false, 'message' => 'Sağlayıcı kimliği doğrulanamadı. Tekrar deneyin.'], 422);
        }

        $email = strtolower(trim((string) ($claims['email'] ?? '')));
        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            return response()->json(['success' => false, 'message' => 'E-posta bilgisi alınamadı. Lütfen manuel kayıt olun.'], 422);
        }

        return response()->json([
            'success' => true,
            'message' => 'Bilgilerinizi kontrol edin; henüz hesap oluşturulmadı.',
            'data' => [
                'provider' => $input['provider'],
                'first_name' => mb_substr($first, 0, 50),
                'last_name' => mb_substr($last, 0, 50),
                'email' => $email,
                'account_created' => false,
            ],
        ]);
    }
}
