<?php

namespace Tests\Feature;

use App\Models\Conversation;
use App\Models\User;
use App\Services\ConversationService;
use App\Support\MediaUrl;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AvatarConsistencyTest extends TestCase
{
    use RefreshDatabase;

    private function user(string $role, string $email): User
    {
        return User::create(['role' => $role, 'first_name' => 'Test', 'last_name' => 'User',
            'name' => 'Test User', 'email' => $email, 'password' => 'safe-password', 'status' => 'active']);
    }

    public function test_uploaded_provider_photo_is_the_same_in_session_profile_public_card_and_media(): void
    {
        Storage::fake('public');
        $user = $this->user('PROVIDER', 'provider@example.test');
        $profile = $user->providerProfile()->create(['business_name' => 'Test', 'provider_type' => 'barber',
            'is_approved' => true, 'identity_status' => 'APPROVED', 'latitude' => 41.06, 'longitude' => 28.99]);
        $profile->documents()->create(['document_type' => 'DIPLOMA', 'original_name' => 'test.pdf',
            'storage_path' => 'test.pdf', 'mime_type' => 'application/pdf', 'file_size' => 123, 'status' => 'APPROVED']);
        Sanctum::actingAs($user);
        $png = base64_decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=');
        $upload = $this->post('/api/profile/avatar', ['avatar' => UploadedFile::fake()->createWithContent('photo.png', $png)], ['Accept' => 'application/json'])->assertOk();
        $url = $upload->json('data.avatar_url');
        $this->assertStringContainsString('/api/media/avatars/', $url);
        $this->assertSame($url, $user->fresh()->avatar_url);
        $this->getJson('/api/auth/me')->assertOk()->assertJsonPath('data.user.avatar_url', $url);
        $this->getJson('/api/providers/' . $user->id)->assertOk()->assertJsonPath('data.avatar_url', $url);
        $this->get(parse_url($url, PHP_URL_PATH))->assertOk()->assertHeader('Content-Type', 'image/png');
        $customer = $this->user('CUSTOMER', 'nearby-avatar@example.test');
        Sanctum::actingAs($customer);
        $this->getJson('/api/customer/providers/nearby?lat=41.06&lng=28.99&radius_km=10')
            ->assertOk()->assertJsonPath('data.0.avatar_url', $url);
    }

    public function test_favorites_return_the_canonical_avatar_not_an_unselected_or_legacy_field(): void
    {
        $customer = $this->user('CUSTOMER', 'favorite-customer@example.test');
        $provider = $this->user('PROVIDER', 'favorite-provider@example.test');
        $provider->update(['avatar_url' => 'avatars/provider.png']);
        $provider->providerProfile()->create(['business_name' => 'Test']);
        Sanctum::actingAs($customer);
        $this->postJson('/api/customer/favorites', ['provider_user_id' => $provider->id])->assertOk();
        $this->getJson('/api/customer/favorites')->assertOk()
            ->assertJsonPath('data.0.avatar_url', $provider->fresh()->avatar_url);
    }

    public function test_chat_uses_both_users_canonical_avatar_never_a_cover_or_legacy_customer_photo(): void
    {
        $customer = $this->user('CUSTOMER', 'customer@example.test');
        $customer->update(['avatar_url' => 'avatars/customer.png']);
        $customer->customerProfile()->create(['avatar_url' => 'https://example.test/stale-customer.png']);
        $provider = $this->user('PROVIDER', 'provider@example.test');
        $provider->update(['avatar_url' => '/storage/avatars/provider.png']);
        $provider->providerProfile()->create(['cover_url' => 'https://example.test/cover.png']);
        Conversation::create(['resource_type' => Conversation::RESOURCE_INSTANT_REQUEST, 'resource_id' => 1,
            'customer_user_id' => $customer->id, 'provider_user_id' => $provider->id, 'status' => Conversation::STATUS_ACTIVE]);
        $service = app(ConversationService::class);
        $this->assertSame(MediaUrl::fromPublicPath('avatars/provider.png'), $service->getConversationsForUser($customer)[0]['other_party']['avatar_url']);
        $this->assertSame(MediaUrl::fromPublicPath('avatars/customer.png'), $service->getConversationsForUser($provider)[0]['other_party']['avatar_url']);
    }
}
