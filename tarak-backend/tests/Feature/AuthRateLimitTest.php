<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AuthRateLimitTest extends TestCase
{
    use RefreshDatabase;

    public function test_bootstrap_requests_do_not_consume_login_attempts(): void
    {
        for ($i = 0; $i < 25; $i++) $this->getJson('/api/auth/social/config')->assertOk();
        $this->postJson('/api/auth/login', [])->assertStatus(422);
        $this->getJson('/api/auth/social/nonce')->assertOk();
    }

    public function test_login_limit_stays_enabled_and_preserves_retry_after_in_turkish(): void
    {
        for ($i = 0; $i < 20; $i++) $this->postJson('/api/auth/login', [])->assertStatus(422);
        $response = $this->postJson('/api/auth/login', [])->assertStatus(429)
            ->assertHeader('Retry-After')->assertJsonPath('success', false);
        $this->assertGreaterThan(0, $response->json('retry_after_seconds'));
        $this->assertStringContainsString('saniye sonra', $response->json('message'));
        $this->assertStringNotContainsString('Too Many Attempts', $response->getContent());
        $this->getJson('/api/auth/social/config')->assertOk();
    }
}
