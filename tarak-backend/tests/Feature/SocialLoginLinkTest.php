<?php

namespace Tests\Feature;

use App\Models\User;
use App\Services\SocialIdentityVerifier;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Mockery;
use Tests\TestCase;

class SocialLoginLinkTest extends TestCase
{
    use RefreshDatabase;

    private function user(string $email, string $status = 'active'): User
    {
        return User::create(['role' => 'CUSTOMER', 'first_name' => 'Test', 'last_name' => 'User',
            'name' => 'Test User', 'email' => $email, 'password' => 'safe-password', 'status' => $status]);
    }

    private function login(string $email, bool $verified = true, string $subject = 'google-subject')
    {
        $verifier = Mockery::mock(SocialIdentityVerifier::class);
        $verifier->shouldReceive('verify')->andReturn(['subject' => $subject, 'email' => $email,
            'email_verified' => $verified, 'first_name' => 'Test', 'last_name' => 'User']);
        $this->app->instance(SocialIdentityVerifier::class, $verifier);
        return $this->postJson('/api/auth/social/google/login', ['id_token' => 'signed-in-verifier', 'nonce' => str_repeat('a', 48)]);
    }

    public function test_verified_matching_email_links_and_issues_token_without_password(): void
    {
        $user = $this->user('owner@example.test');
        $this->login('owner@example.test')->assertOk()->assertJsonPath('data.user.id', $user->id)
            ->assertJsonStructure(['data' => ['token']]);
        $this->assertDatabaseHas('social_identities', ['user_id' => $user->id, 'provider' => 'google', 'subject' => 'google-subject']);
        $this->assertNotNull($user->fresh()->email_verified_at);
        $this->login('owner@example.test')->assertOk();
        $this->assertDatabaseCount('social_identities', 1);
    }

    public function test_social_prefill_verified_email_registers_without_a_second_email_code(): void
    {
        $verifier = Mockery::mock(SocialIdentityVerifier::class);
        $verifier->shouldReceive('verify')->once()->andReturn(['subject' => 'new-google-subject',
            'email' => 'new@example.test', 'email_verified' => true, 'first_name' => 'Ayşe', 'last_name' => 'Test']);
        $this->app->instance(SocialIdentityVerifier::class, $verifier);
        $prefill = $this->postJson('/api/auth/social/google/prefill', ['id_token' => 'verified-token', 'nonce' => str_repeat('a', 48)])
            ->assertOk()->assertJsonPath('data.first_name', 'Ayşe')->assertJsonPath('data.last_name', 'Test')
            ->assertJsonPath('data.email', 'new@example.test')->assertJsonPath('data.email_verified', true);
        $registration = ['role' => 'CUSTOMER', 'first_name' => 'Ayşe', 'last_name' => 'Test',
            'email' => 'new@example.test', 'password' => 'safe-password-123', 'password_confirmation' => 'safe-password-123',
            'accept_terms' => true, 'accept_kvkk' => true, 'social_prefill_token' => $prefill->json('data.social_prefill_token')];
        $this->postJson('/api/auth/register', array_replace($registration, ['email' => 'changed@example.test']))->assertUnprocessable();
        $this->postJson('/api/auth/register', $registration)->assertCreated();
        $this->assertNotNull(User::where('email', 'new@example.test')->firstOrFail()->email_verified_at);
        $this->assertDatabaseHas('social_identities', ['provider' => 'google', 'subject' => 'new-google-subject']);
        $this->assertDatabaseCount('registration_verifications', 0);
    }

    public function test_unverified_email_cannot_link_or_issue_token(): void
    {
        $this->user('owner@example.test');
        $this->login('owner@example.test', false)->assertStatus(409);
        $this->assertDatabaseCount('social_identities', 0);
        $this->assertDatabaseCount('personal_access_tokens', 0);
    }

    public function test_new_email_has_registration_message_and_no_implicit_account(): void
    {
        $this->login('new@example.test')->assertStatus(409)->assertJsonPath('success', false);
        $this->assertDatabaseCount('users', 0);
        $this->assertDatabaseCount('personal_access_tokens', 0);
    }

    public function test_subject_attached_to_a_deleted_account_is_not_reassigned(): void
    {
        $old = $this->user('old@example.test');
        DB::table('social_identities')->insert(['provider' => 'google', 'subject' => 'google-subject', 'user_id' => $old->id]);
        $old->delete();
        $this->user('new@example.test');
        $this->login('new@example.test')->assertStatus(409);
        $this->assertDatabaseHas('social_identities', ['user_id' => $old->id, 'subject' => 'google-subject']);
        $this->assertDatabaseCount('personal_access_tokens', 0);
    }

    public function test_a_subject_cannot_cross_link_two_existing_accounts(): void
    {
        $old = $this->user('old@example.test');
        $this->user('new@example.test');
        DB::table('social_identities')->insert(['provider' => 'google', 'subject' => 'google-subject', 'user_id' => $old->id]);
        $this->login('new@example.test')->assertStatus(409);
        $this->assertDatabaseHas('social_identities', ['user_id' => $old->id]);
        $this->assertDatabaseCount('personal_access_tokens', 0);
    }

    public function test_inactive_account_does_not_gain_an_identity_link_or_token(): void
    {
        $this->user('inactive@example.test', 'suspended');
        $this->login('inactive@example.test')->assertStatus(403);
        $this->assertDatabaseCount('social_identities', 0);
        $this->assertDatabaseCount('personal_access_tokens', 0);
    }
}
