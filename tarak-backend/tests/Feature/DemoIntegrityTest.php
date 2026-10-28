<?php

namespace Tests\Feature;

use App\Models\ProviderReview;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class DemoIntegrityTest extends TestCase
{
    use RefreshDatabase;

    public function test_demo_provider_never_receives_a_real_verified_badge_or_public_review_rating(): void
    {
        $provider = $this->provider('demo-provider@example.test', true);
        $demoCustomer = $this->user(User::ROLE_CUSTOMER, 'demo-customer@example.test', true);
        ProviderReview::create([
            'provider_user_id' => $provider->id,
            'customer_user_id' => $demoCustomer->id,
            'rating' => 5,
            'comment' => 'Sentetik örnek yorum',
        ]);

        $this->assertFalse($provider->providerProfile->isVerified());
        $this->getJson('/api/providers/' . $provider->id)
            ->assertOk()
            ->assertJsonPath('data.is_demo', true)
            ->assertJsonPath('data.is_verified', false)
            ->assertJsonPath('data.rating', null)
            ->assertJsonPath('data.review_count', 0);
        $this->getJson('/api/providers/' . $provider->id . '/reviews')
            ->assertOk()
            ->assertJsonPath('data.is_demo', true)
            ->assertJsonPath('data.count', 0)
            ->assertJsonCount(0, 'data.reviews');

        // The rows remain available to the existing admin demo inventory/purge.
        $this->assertDatabaseCount('provider_reviews', 1);
        $this->assertDatabaseHas('users', ['id' => $provider->id, 'is_demo' => true]);
    }

    public function test_real_provider_shows_only_real_customer_reviews(): void
    {
        $provider = $this->provider('real-provider@example.test', false);
        $realCustomer = $this->user(User::ROLE_CUSTOMER, 'real-customer@example.test', false);
        $demoCustomer = $this->user(User::ROLE_CUSTOMER, 'sample-customer@example.test', true);
        foreach ([$realCustomer->id => 4, $demoCustomer->id => 5] as $customerId => $rating) {
            ProviderReview::create([
                'provider_user_id' => $provider->id,
                'customer_user_id' => $customerId,
                'rating' => $rating,
            ]);
        }

        $this->getJson('/api/providers/' . $provider->id)
            ->assertOk()
            ->assertJsonPath('data.is_demo', false)
            ->assertJsonPath('data.is_verified', true)
            ->assertJsonPath('data.rating', 4)
            ->assertJsonPath('data.review_count', 1);
        $this->getJson('/api/providers/' . $provider->id . '/reviews')
            ->assertOk()
            ->assertJsonPath('data.average', 4)
            ->assertJsonPath('data.count', 1)
            ->assertJsonCount(1, 'data.reviews');
    }

    public function test_customer_can_open_a_demo_card_as_a_preview_without_call_availability(): void
    {
        $this->seed(\Database\Seeders\ServiceCatalogSeeder::class);
        $provider = $this->provider('preview-provider@example.test', true);
        $provider->providerProfile->providerServices()->create(['service_id' => 1, 'is_active' => true]);
        $customer = $this->user(User::ROLE_CUSTOMER, 'viewer@example.test', false);
        $customer->customerProfile()->create(['profile_completed' => true]);
        $this->actingAs($customer, 'sanctum')->getJson('/api/customer/providers/' . $provider->id . '/offerings')
            ->assertOk()
            ->assertJsonPath('data.preview_only', true)
            ->assertJsonPath('data.provider.is_demo', true)
            ->assertJsonPath('data.provider.is_verified', false)
            ->assertJsonPath('data.services.0.availability.available', false);
    }

    private function user(string $role, string $email, bool $isDemo): User
    {
        return User::create([
            'role' => $role,
            'first_name' => 'Test',
            'last_name' => 'User',
            'name' => 'Test User',
            'email' => $email,
            'password' => 'password123',
            'status' => 'active',
            'is_demo' => $isDemo,
        ]);
    }

    private function provider(string $email, bool $isDemo): User
    {
        $provider = $this->user(User::ROLE_PROVIDER, $email, $isDemo);
        $profile = $provider->providerProfile()->create([
            'business_name' => 'Test Salon',
            'provider_type' => 'barber',
            'is_approved' => true,
            'identity_status' => 'APPROVED',
        ]);
        $profile->documents()->create([
            'document_type' => 'DIPLOMA',
            'original_name' => 'demo-belge.png',
            'storage_path' => 'test/demo-belge.png',
            'mime_type' => 'image/png',
            'file_size' => 100,
            'status' => 'APPROVED',
        ]);

        return $provider;
    }
}
