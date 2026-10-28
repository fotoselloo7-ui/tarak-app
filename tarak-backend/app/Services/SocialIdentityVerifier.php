<?php

namespace App\Services;

use Firebase\JWT\JWK;
use Firebase\JWT\JWT;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Validation\ValidationException;

class SocialIdentityVerifier
{
    public function issueNonce(): string
    {
        $nonce = bin2hex(random_bytes(24));
        Cache::put($this->nonceKey($nonce), true, now()->addMinutes(10));

        return $nonce;
    }

    /** @return array{subject:string,email:?string,email_verified:bool,first_name:string,last_name:string} */
    public function verify(string $provider, string $idToken, string $nonce, ?string $authorizationCode = null): array
    {
        $config = $provider === 'google' ? config('services.google') : config('services.apple');
        $clientIds = array_values(array_filter(array_map('trim', $config['client_ids'] ?? [])));
        if ($clientIds === []) {
            throw ValidationException::withMessages(['provider' => 'Sosyal giriş yapılandırılmadı.']);
        }

        $exchangedToken = null;
        if ($provider === 'apple') {
            if (!$authorizationCode || empty($config['client_secret'])) {
                throw ValidationException::withMessages(['provider' => 'Apple giriş kodu veya sunucu yapılandırması eksik.']);
            }
            $untrusted = $this->untrustedPayload($idToken);
            $audience = $untrusted['aud'] ?? null;
            if (!is_string($audience) || !in_array($audience, $clientIds, true)) {
                throw ValidationException::withMessages(['id_token' => 'Apple uygulama kimliği geçersiz.']);
            }
            $body = [
                'client_id' => $audience,
                'client_secret' => $config['client_secret'],
                'code' => $authorizationCode,
                'grant_type' => 'authorization_code',
            ];
            if ($audience === ($config['service_id'] ?? null) && !empty($config['redirect_uri'])) {
                $body['redirect_uri'] = $config['redirect_uri'];
            }
            try {
                $response = Http::timeout(10)->asForm()->post('https://appleid.apple.com/auth/token', $body);
                if (!$response->successful() || !is_string($response->json('id_token'))) {
                    throw new \RuntimeException('Apple authorization code exchange failed');
                }
                $exchangedToken = $response->json('id_token');
            } catch (\Throwable $exception) {
                throw ValidationException::withMessages(['authorization_code' => 'Apple yetkilendirmesi doğrulanamadı. Yeniden deneyiniz.']);
            }
        }

        try {
            $jwks = $this->keys($provider);
            $claims = (array) JWT::decode($idToken, JWK::parseKeySet($jwks, 'RS256'));
        } catch (\Throwable $exception) {
            // A rotated signing key may have replaced a cached key.
            Cache::forget('social_jwks:' . $provider);
            try {
                $claims = (array) JWT::decode($idToken, JWK::parseKeySet($this->keys($provider), 'RS256'));
            } catch (\Throwable $retryException) {
                throw ValidationException::withMessages(['id_token' => 'Sağlayıcı kimlik bilgisi doğrulanamadı.']);
            }
        }

        $issuer = $provider === 'google'
            ? ['https://accounts.google.com', 'accounts.google.com']
            : ['https://appleid.apple.com'];
        $audience = $claims['aud'] ?? null;
        if (!in_array($claims['iss'] ?? null, $issuer, true)
            || !is_string($audience) || !in_array($audience, $clientIds, true)
            || !isset($claims['exp']) || !is_numeric($claims['exp']) || (int) $claims['exp'] <= time()
            || !is_string($claims['sub'] ?? null) || $claims['sub'] === '') {
            throw ValidationException::withMessages(['id_token' => 'Sağlayıcı kimlik bilgisi bu uygulamaya ait değil.']);
        }

        if ($exchangedToken !== null) {
            try {
                $exchangedClaims = (array) JWT::decode($exchangedToken, JWK::parseKeySet($this->keys($provider), 'RS256'));
            } catch (\Throwable $exception) {
                throw ValidationException::withMessages(['authorization_code' => 'Apple yetkilendirme yanıtı doğrulanamadı.']);
            }
            if (($exchangedClaims['iss'] ?? null) !== 'https://appleid.apple.com'
                || ($exchangedClaims['aud'] ?? null) !== $audience
                || ($exchangedClaims['sub'] ?? null) !== $claims['sub']) {
                throw ValidationException::withMessages(['authorization_code' => 'Apple yetkilendirme yanıtı kimlikle eşleşmiyor.']);
            }
        }

        $tokenNonce = $claims['nonce'] ?? null;
        $expectedNonce = $provider === 'apple' ? hash('sha256', $nonce) : $nonce;
        if (($provider === 'apple' && !is_string($tokenNonce))
            || ($tokenNonce !== null && !hash_equals($expectedNonce, (string) $tokenNonce)
                && !hash_equals($nonce, (string) $tokenNonce))) {
            throw ValidationException::withMessages(['nonce' => 'Sağlayıcı oturum doğrulaması geçersiz.']);
        }

        if (!Cache::pull($this->nonceKey($nonce))) {
            throw ValidationException::withMessages(['nonce' => 'Oturum isteğinin süresi doldu veya tekrar kullanıldı.']);
        }
        $tokenTtl = max(1, (int) ($claims['exp'] ?? 0) - time());
        if (!Cache::add('social_token_used:' . hash('sha256', $idToken), true, $tokenTtl)) {
            throw ValidationException::withMessages(['id_token' => 'Bu sağlayıcı oturumu zaten kullanıldı. Yeniden giriş yapınız.']);
        }

        $email = $claims['email'] ?? null;
        $email = is_string($email) && filter_var($email, FILTER_VALIDATE_EMAIL)
            ? strtolower(trim($email)) : null;

        return [
            'subject' => $claims['sub'],
            'email' => $email,
            'email_verified' => in_array($claims['email_verified'] ?? false, [true, 'true', '1', 1], true),
            'first_name' => $provider === 'google' ? (string) ($claims['given_name'] ?? '') : '',
            'last_name' => $provider === 'google' ? (string) ($claims['family_name'] ?? '') : '',
        ];
    }

    private function keys(string $provider): array
    {
        return Cache::remember('social_jwks:' . $provider, now()->addHour(), function () use ($provider): array {
            $url = $provider === 'google'
                ? 'https://www.googleapis.com/oauth2/v3/certs'
                : 'https://appleid.apple.com/auth/keys';
            $response = Http::timeout(7)->acceptJson()->get($url);
            if (!$response->successful() || !is_array($response->json('keys'))) {
                throw new \RuntimeException('Provider signing keys unavailable');
            }

            return $response->json();
        });
    }

    private function nonceKey(string $nonce): string
    {
        return 'social_nonce:' . hash('sha256', $nonce);
    }

    private function untrustedPayload(string $jwt): array
    {
        $parts = explode('.', $jwt);
        if (count($parts) !== 3) {
            return [];
        }
        $decoded = base64_decode(strtr($parts[1], '-_', '+/'), true);

        return is_string($decoded) ? (json_decode($decoded, true) ?: []) : [];
    }
}
