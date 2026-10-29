<?php

namespace Tests\Feature;

use App\Services\SocialIdentityVerifier;
use Firebase\JWT\JWT;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Validation\ValidationException;
use Tests\TestCase;

class AppleIdentityTest extends TestCase
{
    private string $privatePem = '';

    protected function setUp(): void
    {
        parent::setUp();
        Cache::flush();
        $file = tempnam(sys_get_temp_dir(), 'tarak-openssl-');
        file_put_contents($file, "[req]\ndistinguished_name = dn\n[dn]\n");
        try {
            $key = openssl_pkey_new(['config' => $file, 'private_key_bits' => 2048, 'private_key_type' => OPENSSL_KEYTYPE_RSA]);
            openssl_pkey_export($key, $this->privatePem, null, ['config' => $file]);
        } finally { unlink($file); }
        $rsa = openssl_pkey_get_details($key)['rsa'];
        $encode = fn ($bytes) => rtrim(strtr(base64_encode($bytes), '+/', '-_'), '=');
        Http::preventStrayRequests();
        Http::fake(['appleid.apple.com/auth/keys' => Http::response(['keys' => [[
            'kty' => 'RSA', 'kid' => 'apple-test', 'alg' => 'RS256', 'use' => 'sig',
            'n' => $encode($rsa['n']), 'e' => $encode($rsa['e']),
        ]]])]);
        config(['services.apple' => ['service_id' => 'app.tarak.web',
            'client_ids' => ['app.tarak.mobile', 'app.tarak.web'], 'client_secret' => '', 'redirect_uri' => '']]);
    }

    private function token(string $nonce, array $replace = []): string
    {
        return JWT::encode(array_replace(['iss' => 'https://appleid.apple.com', 'aud' => 'app.tarak.mobile',
            'sub' => 'apple-user', 'iat' => time() - 1, 'exp' => time() + 600,
            'nonce' => hash('sha256', $nonce), 'email' => 'owner@example.test', 'email_verified' => 'true'], $replace),
            $this->privatePem, 'RS256', 'apple-test');
    }

    public function test_native_token_succeeds_without_web_secret_or_code_exchange_and_cannot_replay(): void
    {
        $verifier = app(SocialIdentityVerifier::class);
        $nonce = $verifier->issueNonce();
        $token = $this->token($nonce);
        $identity = $verifier->verify('apple', $token, $nonce);
        $this->assertSame('apple-user', $identity['subject']);
        $this->assertTrue($identity['email_verified']);
        Http::assertNotSent(fn ($request) => str_contains($request->url(), '/auth/token'));
        $this->expectException(ValidationException::class);
        $verifier->verify('apple', $token, $nonce);
    }

    public function test_native_rejects_wrong_audience_issuer_expiry_nonce_and_tampered_signature(): void
    {
        $verifier = app(SocialIdentityVerifier::class);
        foreach ([['aud' => 'attacker.app'], ['iss' => 'https://attacker.test'],
            ['exp' => time() - 60], ['exp' => null], ['nonce' => 'wrong'], ['nonce' => null]] as $claims) {
            $nonce = $verifier->issueNonce();
            try { $verifier->verify('apple', $this->token($nonce, $claims), $nonce); $this->fail('Invalid claims accepted'); }
            catch (ValidationException $exception) { $this->assertNotEmpty($exception->errors()); }
        }
        $nonce = $verifier->issueNonce();
        $parts = explode('.', $this->token($nonce));
        $parts[2][0] = $parts[2][0] === 'a' ? 'b' : 'a';
        $this->expectException(ValidationException::class);
        $verifier->verify('apple', implode('.', $parts), $nonce);
    }

    public function test_web_still_requires_authorization_code_and_checks_exchanged_identity(): void
    {
        config(['services.apple.client_secret' => 'test-web-secret']);
        $verifier = app(SocialIdentityVerifier::class);
        $nonce = $verifier->issueNonce();
        $token = $this->token($nonce, ['aud' => 'app.tarak.web']);
        try { $verifier->verify('apple', $token, $nonce); $this->fail('Web code was not required'); }
        catch (ValidationException $exception) { $this->assertArrayHasKey('provider', $exception->errors()); }
        Http::fake(['appleid.apple.com/auth/token' => Http::response(['id_token' => $token])]);
        $this->assertSame('apple-user', $verifier->verify('apple', $token, $nonce, 'one-use-web-code')['subject']);
        Http::assertSent(fn ($request) => str_contains($request->url(), '/auth/token')
            && $request['client_id'] === 'app.tarak.web' && $request['code'] === 'one-use-web-code');
    }

    public function test_web_exchange_cannot_substitute_a_different_subject(): void
    {
        config(['services.apple.client_secret' => 'test-web-secret']);
        $verifier = app(SocialIdentityVerifier::class);
        $nonce = $verifier->issueNonce();
        Http::fake(['appleid.apple.com/auth/token' => Http::response(['id_token' => $this->token($nonce,
            ['aud' => 'app.tarak.web', 'sub' => 'other-user'])])]);
        $this->expectException(ValidationException::class);
        $verifier->verify('apple', $this->token($nonce, ['aud' => 'app.tarak.web']), $nonce, 'web-code');
    }
}
