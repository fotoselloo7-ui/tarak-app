<?php

namespace Tests\Feature;

use App\Models\User;
use App\Services\SocialIdentityVerifier;
use Firebase\JWT\JWT;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Mockery;
use Tests\TestCase;

class RegistrationSecurityTest extends TestCase
{
    use RefreshDatabase;

    public function test_email_code_attempts_are_counted_and_registration_needs_proof_and_consent(): void
    {
        $email = 'new@example.test';
        $code = '123456';
        DB::table('registration_verifications')->insert([
            'channel' => 'email',
            'destination_hash' => $this->digest('email:' . $email),
            'code_hash' => $this->digest($code),
            'attempts' => 0,
            'expires_at' => now()->addMinutes(10),
            'resend_after' => now()->addMinute(),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $this->postJson('/api/auth/verification/email/confirm', ['email' => $email, 'code' => '999999'])
            ->assertUnprocessable();
        $this->assertDatabaseHas('registration_verifications', ['attempts' => 1]);

        $proof = $this->postJson('/api/auth/verification/email/confirm', ['email' => $email, 'code' => $code])
            ->assertOk()->json('data.verification_token');

        $registration = [
            'role' => 'CUSTOMER',
            'first_name' => 'Ayşe',
            'last_name' => 'Test',
            'email' => $email,
            'password' => 'safe-password-123',
            'password_confirmation' => 'safe-password-123',
            'email_verification_token' => $proof,
        ];
        $this->postJson('/api/auth/register', $registration)->assertUnprocessable();
        $this->postJson('/api/auth/register', $registration + [
            'accept_terms' => true,
            'accept_kvkk' => true,
            'marketing_consent' => false,
        ])->assertCreated();

        $this->assertDatabaseHas('users', ['email' => $email]);
        $this->assertNotNull(User::where('email', $email)->firstOrFail()->email_verified_at);
        $this->assertDatabaseHas('registration_consents', ['marketing_consented_at' => null]);
    }

    public function test_social_login_does_not_select_an_account_by_matching_email(): void
    {
        $user = User::create([
            'role' => 'CUSTOMER', 'first_name' => 'Test', 'last_name' => 'User',
            'name' => 'Test User', 'email' => 'shared@example.test',
            'password' => 'safe-password-123', 'status' => 'active',
        ]);
        DB::table('social_identities')->insert([
            'user_id' => $user->id, 'provider' => 'google', 'subject' => 'other-subject',
            'created_at' => now(), 'updated_at' => now(),
        ]);

        $verifier = Mockery::mock(SocialIdentityVerifier::class);
        $verifier->shouldReceive('verify')->once()->andReturn([
            'subject' => 'unlinked-subject', 'email' => 'shared@example.test',
            'email_verified' => true, 'first_name' => 'Test', 'last_name' => 'User',
        ]);
        $this->app->instance(SocialIdentityVerifier::class, $verifier);

        $this->postJson('/api/auth/social/google/login', [
            'id_token' => 'test-token',
            'nonce' => str_repeat('a', 48),
        ])->assertStatus(409)->assertJsonPath('success', false);
        $this->assertDatabaseCount('personal_access_tokens', 0);
    }

    public function test_google_identity_requires_valid_signature_audience_and_one_time_nonce(): void
    {
        $opensslConfig = tempnam(sys_get_temp_dir(), 'tarak-openssl-');
        file_put_contents($opensslConfig, "[req]\ndistinguished_name = req_distinguished_name\n[req_distinguished_name]\n");
        $privateKey = openssl_pkey_new([
            'config' => $opensslConfig,
            'private_key_bits' => 2048,
            'private_key_type' => OPENSSL_KEYTYPE_RSA,
        ]);
        $exported = $privateKey && openssl_pkey_export($privateKey, $privatePem, null, ['config' => $opensslConfig]);
        unlink($opensslConfig);
        $this->assertNotFalse($privateKey);
        $this->assertTrue($exported);
        $public = openssl_pkey_get_details($privateKey)['rsa'];
        $encode = fn (string $binary): string => rtrim(strtr(base64_encode($binary), '+/', '-_'), '=');
        Http::fake(['https://www.googleapis.com/oauth2/v3/certs' => Http::response(['keys' => [[
            'kty' => 'RSA', 'kid' => 'test-key', 'alg' => 'RS256', 'use' => 'sig',
            'n' => $encode($public['n']), 'e' => $encode($public['e']),
        ]]])]);
        config(['services.google.client_ids' => ['expected.apps.googleusercontent.com']]);

        $verifier = app(SocialIdentityVerifier::class);
        $nonce = $verifier->issueNonce();
        $claims = [
            'iss' => 'https://accounts.google.com',
            'sub' => 'provider-subject',
            'aud' => 'expected.apps.googleusercontent.com',
            'iat' => time(), 'exp' => time() + 600, 'nonce' => $nonce,
            'email' => 'person@example.test', 'email_verified' => true,
        ];
        $token = JWT::encode($claims, $privatePem, 'RS256', 'test-key');

        $badNonce = $verifier->issueNonce();
        $badClaims = $claims;
        $badClaims['aud'] = 'attacker.apps.googleusercontent.com';
        $badClaims['nonce'] = $badNonce;
        $badToken = JWT::encode($badClaims, $privatePem, 'RS256', 'test-key');
        try {
            $verifier->verify('google', $badToken, $badNonce);
            $this->fail('A different OAuth audience must be rejected.');
        } catch (\Illuminate\Validation\ValidationException $exception) {
            $this->assertArrayHasKey('id_token', $exception->errors());
        }

        $identity = $verifier->verify('google', $token, $nonce);
        $this->assertSame('provider-subject', $identity['subject']);
        $this->assertSame('person@example.test', $identity['email']);

        $this->expectException(\Illuminate\Validation\ValidationException::class);
        $verifier->verify('google', $token, $nonce);
    }

    private function digest(string $value): string
    {
        return hash_hmac('sha256', $value, (string) config('app.key'));
    }
}
