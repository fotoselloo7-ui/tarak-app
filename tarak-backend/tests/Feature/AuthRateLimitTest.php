<?php

namespace Tests\Feature;

use App\Models\User;
use App\Services\Sms\SmsManager;
use Firebase\JWT\JWT;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Mail;
use Mockery;
use Tests\TestCase;

class AuthRateLimitTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        config(['app.debug' => false]);
        Http::preventStrayRequests();
        $this->withHeader('X-Tarak-Client', 'mobile-secure-v2');
    }

    private function user(): User
    {
        return User::create(['role' => 'CUSTOMER', 'first_name' => 'Test', 'last_name' => 'User',
            'name' => 'Test User', 'email' => 'owner@example.test', 'phone' => '+905321234567',
            'password' => 'safe-password-123', 'status' => 'active']);
    }

    public function test_bootstrap_requests_do_not_block_social_login(): void
    {
        for ($i = 0; $i < 130; $i++) {
            $this->getJson('/api/auth/social/config')->assertOk();
            $this->getJson('/api/auth/verification/config')->assertOk();
            $this->getJson('/api/auth/social/nonce')->assertOk();
        }
    }

    public function test_thirty_wrong_passwords_and_validation_errors_do_not_block_next_login(): void
    {
        $user = $this->user();
        for ($i = 0; $i < 30; $i++) {
            $this->postJson('/api/auth/login', ['login' => $user->email, 'password' => 'wrong-password'])
                ->assertUnauthorized()->assertJsonPath('message', 'Giriş bilgileri hatalı.');
            $this->postJson('/api/auth/login', [])->assertUnprocessable();
        }
        $this->postJson('/api/auth/login', ['login' => $user->email, 'password' => 'safe-password-123'])
            ->assertOk()->assertJsonPath('data.user.id', $user->id);
    }

    public function test_duplicate_email_and_normalized_phone_are_turkish_422_even_in_production(): void
    {
        $this->user();
        $payload = ['role' => 'CUSTOMER', 'first_name' => 'Test', 'last_name' => 'User',
            'password' => 'safe-password-123', 'password_confirmation' => 'safe-password-123',
            'accept_terms' => true, 'accept_kvkk' => true];
        for ($i = 0; $i < 30; $i++) {
            $this->postJson('/api/auth/register', $payload + ['email' => ' OWNER@EXAMPLE.TEST '])
                ->assertUnprocessable()->assertJsonPath('message', 'Bu e-posta adresi zaten kullanımda.')
                ->assertJsonValidationErrors('email');
            $this->postJson('/api/auth/register', $payload + ['phone' => '0532 123 45 67'])
                ->assertUnprocessable()->assertJsonPath('message', 'Bu telefon numarası zaten kullanımda.')
                ->assertJsonValidationErrors('phone');
        }
        $this->assertDatabaseCount('users', 1);
        $this->assertDatabaseCount('personal_access_tokens', 0);
    }

    public function test_email_and_sms_resend_wait_exactly_three_minutes_without_blocking_code_confirmation(): void
    {
        $sms = Mockery::mock(SmsManager::class);
        $sms->shouldReceive('isEnabled')->andReturn(true);
        $sms->shouldReceive('isEventEnabled')->with('otp')->andReturn(true);
        $sms->shouldReceive('sendTemplate')->with('otp', '+905321234567', Mockery::type('array'))
            ->twice()->andReturn(['sent' => true]);
        $this->app->instance(SmsManager::class, $sms);
        $this->freezeTime();

        foreach (['email' => ['email' => 'new@example.test'], 'sms' => ['phone' => '0532 123 45 67']] as $channel => $payload) {
            $this->postJson("/api/auth/verification/{$channel}/send", $payload)
                ->assertOk()->assertJsonPath('data.resend_after_seconds', 180)
                ->assertJsonPath('data.expires_in_seconds', 600);
            $this->postJson("/api/auth/verification/{$channel}/send", $payload)
                ->assertUnprocessable()->assertJsonPath('errors.destination.0', 'Yeni kod istemek için 180 saniye bekleyiniz.');
            if ($channel === 'email') {
                $message = Mail::mailer()->getSymfonyTransport()->messages()->last()->getOriginalMessage();
                preg_match('/\b(\d{6})\b/', $message->getTextBody(), $match);
                $this->postJson('/api/auth/verification/email/confirm', $payload + ['code' => $match[1]])
                    ->assertOk()->assertJsonStructure(['data' => ['verification_token']]);
            }
            $this->travel(179)->seconds();
            $this->postJson("/api/auth/verification/{$channel}/send", $payload)
                ->assertUnprocessable()->assertJsonPath('errors.destination.0', 'Yeni kod istemek için 1 saniye bekleyiniz.');
            $this->travel(1)->seconds();
            $this->postJson("/api/auth/verification/{$channel}/send", $payload)
                ->assertOk()->assertJsonPath('data.resend_after_seconds', 180);
        }
        $this->assertCount(2, Mail::mailer()->getSymfonyTransport()->messages());
    }

    public function test_send_endpoints_keep_429_json_and_do_not_consume_login_attempts(): void
    {
        foreach (['verification/email/send', 'verification/sms/send', 'password/forgot'] as $index => $path) {
            $this->withServerVariables(['REMOTE_ADDR' => '127.0.0.' . ($index + 1)]);
            for ($i = 0; $i < 5; $i++) {
                $this->postJson('/api/auth/' . $path, [])->assertUnprocessable();
            }
            $response = $this->postJson('/api/auth/' . $path, [])->assertStatus(429)
                ->assertHeader('Retry-After')->assertJsonPath('success', false);
            $this->assertGreaterThan(0, $response->json('retry_after_seconds'));
            $this->assertStringContainsString('saniye sonra', $response->json('message'));
        }
        $this->postJson('/api/auth/login', [])->assertUnprocessable();
    }

    public function test_password_reset_email_also_waits_three_minutes_between_messages(): void
    {
        $user = $this->user();
        $this->freezeTime();
        $payload = ['email' => $user->email];
        $this->postJson('/api/auth/password/forgot', $payload)->assertOk()
            ->assertJsonPath('data.resend_after_seconds', 180);
        $this->travel(179)->seconds();
        $this->postJson('/api/auth/password/forgot', $payload)->assertOk()
            ->assertJsonPath('data.resend_after_seconds', 1);
        $this->assertCount(1, Mail::mailer()->getSymfonyTransport()->messages());
        $this->travel(1)->seconds();
        $this->postJson('/api/auth/password/forgot', $payload)->assertOk()
            ->assertJsonPath('data.resend_after_seconds', 180);
        $this->assertCount(2, Mail::mailer()->getSymfonyTransport()->messages());
    }

    public function test_real_signed_google_and_apple_requests_can_repeat_and_new_google_user_can_register(): void
    {
        $file = tempnam(sys_get_temp_dir(), 'tarak-auth-key-');
        file_put_contents($file, "[req]\ndistinguished_name = dn\n[dn]\n");
        try {
            $key = openssl_pkey_new(['config' => $file, 'private_key_bits' => 2048, 'private_key_type' => OPENSSL_KEYTYPE_RSA]);
            openssl_pkey_export($key, $pem, null, ['config' => $file]);
        } finally {
            unlink($file);
        }
        $rsa = openssl_pkey_get_details($key)['rsa'];
        $encode = fn ($bytes) => rtrim(strtr(base64_encode($bytes), '+/', '-_'), '=');
        $keys = ['keys' => [['kty' => 'RSA', 'kid' => 'auth-test', 'alg' => 'RS256', 'use' => 'sig',
            'n' => $encode($rsa['n']), 'e' => $encode($rsa['e'])]]];
        Http::fake(['www.googleapis.com/oauth2/v3/certs' => Http::response($keys),
            'appleid.apple.com/auth/keys' => Http::response($keys)]);
        config(['services.google.client_ids' => ['test.google'], 'services.apple.bundle_id' => 'test.apple',
            'services.apple.client_ids' => ['test.apple']]);
        $user = $this->user();

        foreach (['google', 'apple'] as $provider) {
            DB::table('social_identities')->insert(['provider' => $provider, 'subject' => $provider . '-owner',
                'user_id' => $user->id, 'created_at' => now(), 'updated_at' => now()]);
            $claims = ['iss' => $provider === 'google' ? 'https://accounts.google.com' : 'https://appleid.apple.com',
                'aud' => 'test.' . $provider, 'sub' => $provider . '-owner', 'email' => $user->email,
                'email_verified' => true, 'iat' => time() - 1, 'exp' => time() + 600];
            // Google's native SDK can return the very same ID token on every attempt.
            $googleToken = JWT::encode($claims, $pem, 'RS256', 'auth-test');
            for ($i = 0; $i < 30; $i++) {
                foreach (['prefill', 'login'] as $action) {
                    $nonce = $this->getJson('/api/auth/social/nonce')->assertOk()->json('data.nonce');
                    $token = $provider === 'google' ? $googleToken
                        : JWT::encode($claims + ['nonce' => hash('sha256', $nonce)], $pem, 'RS256', 'auth-test');
                    $response = $this->postJson("/api/auth/social/{$provider}/{$action}", ['id_token' => $token, 'nonce' => $nonce])->assertOk();
                    if ($action === 'login') $response->assertJsonPath('data.user.id', $user->id);
                }
            }
        }

        $nonce = $this->getJson('/api/auth/social/nonce')->assertOk()->json('data.nonce');
        $newToken = JWT::encode(['iss' => 'https://accounts.google.com', 'aud' => 'test.google',
            'sub' => 'new-google-user', 'email' => 'new@example.test', 'email_verified' => true,
            'given_name' => 'Ayşe', 'family_name' => 'Test', 'iat' => time() - 1, 'exp' => time() + 600], $pem, 'RS256', 'auth-test');
        $proof = $this->postJson('/api/auth/social/google/prefill', ['id_token' => $newToken, 'nonce' => $nonce])
            ->assertOk()->json('data.social_prefill_token');
        $this->postJson('/api/auth/register', ['role' => 'CUSTOMER', 'first_name' => 'Ayşe', 'last_name' => 'Test',
            'email' => 'new@example.test', 'password' => 'safe-password-123', 'password_confirmation' => 'safe-password-123',
            'accept_terms' => true, 'accept_kvkk' => true, 'social_prefill_token' => $proof])->assertCreated();
        $this->assertDatabaseHas('social_identities', ['provider' => 'google', 'subject' => 'new-google-user']);
    }
}
