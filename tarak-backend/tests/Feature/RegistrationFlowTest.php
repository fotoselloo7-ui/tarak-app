<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Mail;
use Tests\TestCase;

class RegistrationFlowTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        config(['app.debug' => false]);
        $this->withHeader('X-Tarak-Client', 'mobile-secure-v2');
    }

    private function payload(array $replace = []): array
    {
        return array_replace(['role' => 'CUSTOMER', 'first_name' => 'Ayşe', 'last_name' => 'Test',
            'email' => 'new@example.test', 'password' => 'safe-password-123',
            'password_confirmation' => 'safe-password-123', 'accept_terms' => true, 'accept_kvkk' => true], $replace);
    }

    private function emailProof(string $email = 'new@example.test'): string
    {
        $this->postJson('/api/auth/verification/email/send', ['email' => $email])->assertOk();
        $message = Mail::mailer()->getSymfonyTransport()->messages()->last()->getOriginalMessage();
        $this->assertSame($email, $message->getTo()[0]->getAddress());
        $this->assertSame(1, preg_match('/\b(\d{6})\b/', $message->getTextBody(), $match));
        return $this->postJson('/api/auth/verification/email/confirm', ['email' => $email, 'code' => $match[1]])
            ->assertOk()->json('data.verification_token');
    }

    private function socialProof(bool $verified = true, bool $expired = false): string
    {
        $proof = str_repeat('a', 64);
        DB::table('social_auth_attempts')->insert(['token_hash' => hash_hmac('sha256', $proof, (string) config('app.key')),
            'provider' => 'google', 'subject' => 'new-google-user', 'email' => 'new@example.test',
            'email_verified' => $verified, 'first_name' => 'Ayşe', 'last_name' => 'Test',
            'expires_at' => $expired ? now()->subMinute() : now()->addMinutes(10),
            'created_at' => now(), 'updated_at' => now()]);
        return $proof;
    }

    public function test_email_code_send_confirm_registration_and_next_session_use_the_same_user(): void
    {
        $proof = $this->emailProof();
        $response = $this->postJson('/api/auth/register', $this->payload(['email_verification_token' => $proof]))
            ->assertCreated()->assertJsonPath('data.user.email', 'new@example.test');
        $user = User::where('email', 'new@example.test')->firstOrFail();
        $this->assertNotNull($user->email_verified_at);
        $this->assertNotNull(DB::table('registration_verifications')->first()->consumed_at);
        $this->withToken($response->json('data.token'))->getJson('/api/auth/me')->assertOk()->assertJsonPath('data.user.id', $user->id);
    }

    public function test_provider_social_registration_starts_pending_with_zero_balance_and_no_email_otp(): void
    {
        $proof = $this->socialProof();
        $response = $this->postJson('/api/auth/register', $this->payload(['role' => 'PROVIDER',
            'business_name' => 'Test Salon', 'social_prefill_token' => $proof]))->assertCreated()
            ->assertJsonPath('data.user.provider_profile.is_approved', false)
            ->assertJsonPath('data.user.provider_profile.identity_status', 'PENDING');
        $this->assertSame(0.0, (float) $response->json('data.user.wallet.balance'));
        $this->assertDatabaseCount('registration_verifications', 0);
        $this->assertDatabaseCount('social_identities', 1);
        $this->assertNotNull(DB::table('social_auth_attempts')->first()->consumed_at);
    }

    public function test_provider_email_registration_creates_verified_account_pending_profile_zero_wallet_and_consent(): void
    {
        $proof = $this->emailProof();
        $response = $this->postJson('/api/auth/register', $this->payload([
            'role' => 'PROVIDER', 'business_name' => 'Test Salon', 'email_verification_token' => $proof,
        ]))->assertCreated()->assertJsonPath('data.user.role', 'PROVIDER')
            ->assertJsonPath('data.user.provider_profile.is_approved', false)
            ->assertJsonPath('data.user.provider_profile.identity_status', 'PENDING');
        $id = $response->json('data.user.id');
        $this->assertNotNull(User::findOrFail($id)->email_verified_at);
        $this->assertDatabaseHas('provider_profiles', ['user_id' => $id, 'business_name' => 'Test Salon']);
        $this->assertDatabaseHas('wallets', ['user_id' => $id, 'balance' => 0, 'currency' => 'TRY']);
        $this->assertDatabaseHas('registration_consents', ['user_id' => $id]);
        $this->assertDatabaseCount('customer_profiles', 0);
        $this->assertDatabaseCount('personal_access_tokens', 1);
    }

    public function test_google_prefill_endpoint_then_provider_registration_creates_the_same_verified_identity(): void
    {
        $this->mock(\App\Services\SocialIdentityVerifier::class, function ($mock) {
            $mock->shouldReceive('verify')->once()->andReturn([
                'subject' => 'new-google-provider', 'email' => 'new@example.test',
                'email_verified' => true, 'first_name' => 'Ayşe', 'last_name' => 'Test',
            ]);
        });
        $proof = $this->postJson('/api/auth/social/google/prefill', [
            'id_token' => 'verified-by-test-provider', 'nonce' => str_repeat('c', 48),
        ])->assertOk()->json('data.social_prefill_token');
        $response = $this->postJson('/api/auth/register', $this->payload([
            'role' => 'PROVIDER', 'business_name' => 'Test Salon', 'social_prefill_token' => $proof,
        ]))->assertCreated()->assertJsonPath('data.user.role', 'PROVIDER');
        $this->assertDatabaseHas('social_identities', [
            'provider' => 'google', 'subject' => 'new-google-provider', 'user_id' => $response->json('data.user.id'),
        ]);
        $this->assertNotNull(User::findOrFail($response->json('data.user.id'))->email_verified_at);
        $this->assertDatabaseCount('registration_verifications', 0);
    }

    public function test_missing_invalid_and_expired_email_proofs_return_422_without_partial_accounts(): void
    {
        $this->postJson('/api/auth/register', $this->payload())
            ->assertUnprocessable()->assertJsonValidationErrors('email');
        $this->postJson('/api/auth/register', $this->payload(['email_verification_token' => str_repeat('b', 64)]))
            ->assertUnprocessable()->assertJsonValidationErrors('email');
        $proof = $this->emailProof();
        DB::table('registration_verifications')->update(['expires_at' => now()->subMinute()]);
        $this->postJson('/api/auth/register', $this->payload(['email_verification_token' => $proof]))
            ->assertUnprocessable()->assertJsonValidationErrors('email');
        $this->assertDatabaseCount('users', 0);
        $this->assertDatabaseCount('customer_profiles', 0);
        $this->assertDatabaseCount('registration_consents', 0);
        $this->assertDatabaseCount('personal_access_tokens', 0);
        $this->assertNull(DB::table('registration_verifications')->first()->consumed_at);
    }

    public function test_modern_ios_headers_or_consent_fields_cannot_enter_legacy_registration(): void
    {
        // Current client: explicit marker remains secure even without consent fields.
        $this->withHeader('User-Agent', 'Dart/3.13 (dart:io)');
        $payload = $this->payload();
        unset($payload['accept_terms'], $payload['accept_kvkk']);
        $this->postJson('/api/auth/register', $payload)->assertUnprocessable()
            ->assertJsonValidationErrors(['accept_terms', 'accept_kvkk']);

        // Even if a proxy stripped the marker, the consent payload selects
        // the secure flow for both Dart and native iOS-style User-Agents.
        $this->withoutHeader('X-Tarak-Client');
        foreach (['Dart/3.13 (dart:io)', 'Tarak/10 CFNetwork Darwin'] as $agent) {
            $this->withHeader('User-Agent', $agent);
            $this->postJson('/api/auth/register', $this->payload())
                ->assertUnprocessable()->assertJsonValidationErrors('email');
        }
        $this->assertDatabaseCount('users', 0);
    }

    public function test_expired_or_unverified_social_proof_cannot_replace_email_verification(): void
    {
        $proof = $this->socialProof(false);
        $this->postJson('/api/auth/register', $this->payload(['social_prefill_token' => $proof]))->assertUnprocessable();
        DB::table('social_auth_attempts')->update(['email_verified' => true, 'expires_at' => now()->subMinute()]);
        $this->postJson('/api/auth/register', $this->payload(['social_prefill_token' => $proof]))->assertUnprocessable();
        $this->assertDatabaseCount('users', 0);
        $this->assertDatabaseCount('personal_access_tokens', 0);
    }

    public function test_social_proof_cannot_be_reused_or_switched_to_another_email(): void
    {
        $proof = $this->socialProof();
        $this->postJson('/api/auth/register', $this->payload(['email' => 'other@example.test', 'social_prefill_token' => $proof]))->assertUnprocessable();
        $this->postJson('/api/auth/register', $this->payload(['social_prefill_token' => $proof]))->assertCreated();
        $this->postJson('/api/auth/register', $this->payload(['email' => 'other@example.test', 'social_prefill_token' => $proof]))->assertUnprocessable();
        $this->assertDatabaseCount('users', 1);
        $this->assertDatabaseCount('social_identities', 1);
    }

    public function test_required_consents_and_password_confirmation_are_not_bypassed_by_social_proof(): void
    {
        $proof = $this->socialProof();
        foreach ([['accept_terms' => false], ['accept_kvkk' => false], ['password_confirmation' => 'different-password']] as $invalid) {
            $this->postJson('/api/auth/register', $this->payload($invalid + ['social_prefill_token' => $proof]))->assertUnprocessable();
        }
        $this->assertDatabaseCount('users', 0);
        $this->assertNull(DB::table('social_auth_attempts')->first()->consumed_at);
    }

    public function test_phone_only_registration_preserves_optional_sms_configuration_and_normalizes_number(): void
    {
        config(['services.registration.sms_verification_enabled' => false]);
        $this->postJson('/api/auth/register', $this->payload(['email' => null, 'phone' => '0532 123 45 67']))
            ->assertCreated()->assertJsonPath('data.user.phone', '+905321234567')
            ->assertJsonPath('data.user.phone_verified_at', null);
    }

    public function test_failed_or_duplicate_registration_does_not_create_partial_profiles_or_extra_tokens(): void
    {
        $this->postJson('/api/auth/register', $this->payload())->assertUnprocessable();
        $this->assertDatabaseCount('users', 0);
        $proof = $this->emailProof();
        $this->postJson('/api/auth/register', $this->payload(['email_verification_token' => $proof]))->assertCreated();
        $this->postJson('/api/auth/register', $this->payload(['email_verification_token' => $proof]))->assertUnprocessable();
        $this->assertDatabaseCount('users', 1);
        $this->assertDatabaseCount('customer_profiles', 1);
        $this->assertDatabaseCount('personal_access_tokens', 1);
    }

    public function test_resend_cooldown_prevents_a_second_message(): void
    {
        $this->postJson('/api/auth/verification/email/send', ['email' => 'new@example.test'])->assertOk();
        $this->postJson('/api/auth/verification/email/send', ['email' => 'new@example.test'])->assertUnprocessable();
        $this->assertCount(1, Mail::mailer()->getSymfonyTransport()->messages());
    }
}
