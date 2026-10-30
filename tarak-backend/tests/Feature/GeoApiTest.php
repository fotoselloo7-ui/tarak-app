<?php

namespace Tests\Feature;

use App\Models\ProviderProfile;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class GeoApiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Cache::flush();
        Http::preventStrayRequests();
    }

    public function test_geocoding_reports_upstream_unavailability_without_a_key_requirement(): void
    {
        Http::fake(['*' => Http::response([], 503)]);
        $this->getJson('/api/geo/search?q=Istanbul%20Kadikoy')
            ->assertStatus(503)->assertJsonPath('success', false);
    }

    public function test_browser_map_config_preserves_existing_openfreemap_without_exposing_keys(): void
    {
        config()->set('services.google_maps.server_key', 'private-server-secret');
        $response = $this->getJson('/api/geo/config')->assertOk()
            ->assertJsonPath('data.provider', 'openfreemap')
            ->assertJsonPath('data.style_url', 'https://tiles.openfreemap.org/styles/liberty');
        $this->assertStringNotContainsString('private-server-secret', $response->getContent());
    }

    public function test_reverse_geocoding_preserves_pin_and_maps_photon_address_fields(): void
    {
        Http::fake(['photon.komoot.io/reverse*' => Http::response(['features' => [[
            'geometry' => ['coordinates' => [29.02, 41.01]],
            'properties' => ['state' => 'İstanbul', 'county' => 'Kadıköy', 'suburb' => 'Moda',
                'street' => 'Moda Caddesi', 'housenumber' => '12', 'osm_id' => 'test-place'],
        ]]])]);
        $this->getJson('/api/geo/reverse?lat=41.009&lng=29.019')->assertOk()
            ->assertJsonPath('data.latitude', 41.009)->assertJsonPath('data.longitude', 29.019)
            ->assertJsonPath('data.province', 'İstanbul')->assertJsonPath('data.district', 'Kadıköy')
            ->assertJsonPath('data.neighborhood', 'Moda')->assertJsonPath('data.street', 'Moda Caddesi')
            ->assertJsonPath('data.building_no', '12');
    }

    public function test_nearby_uses_saved_address_and_orders_real_distances(): void
    {
        $customer = $this->user(User::ROLE_CUSTOMER, 'customer@example.test');
        $profile = $customer->customerProfile()->create();
        $profile->addresses()->create([
            'title' => 'Ev', 'province' => 'İstanbul', 'district' => 'Kadıköy',
            'latitude' => 41.0082, 'longitude' => 28.9784, 'is_default' => true,
        ]);

        $near = $this->provider('near@example.test', 41.0090, 28.9800);
        $far = $this->provider('far@example.test', 41.2000, 28.9784);

        Sanctum::actingAs($customer);
        $this->getJson('/api/customer/providers/nearby?radius_km=50')
            ->assertOk()
            ->assertJsonPath('meta.origin_source', 'saved_address')
            ->assertJsonPath('data.0.user_id', (string) $near->id)
            ->assertJsonPath('data.1.user_id', (string) $far->id)
            ->assertJsonStructure(['data' => [['distance_km']]]);

        $this->getJson('/api/customer/providers/nearby?radius_km=1')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.user_id', (string) $near->id);
    }

    public function test_nearby_requires_a_saved_address_or_explicit_device_position(): void
    {
        $customer = $this->user(User::ROLE_CUSTOMER, 'empty@example.test');
        $customer->customerProfile()->create();
        Sanctum::actingAs($customer);

        $this->getJson('/api/customer/providers/nearby')->assertStatus(422);
        $this->getJson('/api/customer/providers/nearby?radius_km=51&lat=41&lng=29')->assertStatus(422);
    }

    public function test_provider_profile_persists_structured_location_and_coordinate_pair(): void
    {
        $provider = $this->user(User::ROLE_PROVIDER, 'edit@example.test');
        $provider->providerProfile()->create();
        Sanctum::actingAs($provider);

        $this->putJson('/api/provider/profile', [
            'city' => 'İstanbul', 'district' => 'Kadıköy', 'neighborhood' => 'Moda',
            'street' => 'Moda Caddesi', 'building_no' => '12',
            'latitude' => 41.009, 'longitude' => 29.019,
        ])->assertOk()->assertJsonPath('data.profile.neighborhood', 'Moda');

        $this->assertDatabaseHas('provider_profiles', [
            'user_id' => $provider->id, 'street' => 'Moda Caddesi',
            'building_no' => '12', 'latitude' => 41.009, 'longitude' => 29.019,
        ]);

        $this->putJson('/api/provider/profile', ['latitude' => 42])->assertStatus(422);
    }

    public function test_coordinate_less_default_never_falls_back_to_an_old_city(): void
    {
        $customer = $this->user(User::ROLE_CUSTOMER, 'default@example.test');
        $profile = $customer->customerProfile()->create();
        $profile->addresses()->create(['province' => 'Antalya', 'district' => 'Mahmutlar',
            'latitude' => 36.485, 'longitude' => 32.100, 'is_default' => false]);
        $profile->addresses()->create(['province' => 'İstanbul', 'district' => 'Şişli', 'is_default' => true]);
        Sanctum::actingAs($customer);
        $this->getJson('/api/customer/providers/nearby')->assertStatus(422);
    }

    public function test_editing_default_address_changes_nearby_origin_and_distances(): void
    {
        $customer = $this->user(User::ROLE_CUSTOMER, 'move@example.test');
        $profile = $customer->customerProfile()->create();
        $address = $profile->addresses()->create(['province' => 'Antalya', 'district' => 'Mahmutlar',
            'latitude' => 36.485, 'longitude' => 32.100, 'is_default' => true]);
        $old = $this->provider('old-city@example.test', 36.485, 32.100);
        $new = $this->provider('new-city@example.test', 41.060, 28.987);
        $unknown = $this->provider('unknown@example.test', 41.060, 28.987);
        $unknown->providerProfile->update(['latitude' => null, 'longitude' => null]);
        Sanctum::actingAs($customer);
        $this->getJson('/api/customer/providers/nearby?radius_km=10')->assertOk()
            ->assertJsonCount(1, 'data')->assertJsonPath('data.0.user_id', (string) $old->id);
        $this->putJson('/api/customer/addresses/' . $address->id, ['province' => 'İstanbul', 'district' => 'Şişli',
            'latitude' => 41.060, 'longitude' => 28.987])->assertOk();
        $response = $this->getJson('/api/customer/providers/nearby?radius_km=10')->assertOk()
            ->assertJsonCount(1, 'data')->assertJsonPath('data.0.user_id', (string) $new->id);
        $this->assertLessThan(0.01, $response->json('data.0.distance_km'));
    }

    private function user(string $role, string $email): User
    {
        return User::create([
            'role' => $role,
            'first_name' => 'Test',
            'last_name' => 'User',
            'name' => 'Test User',
            'email' => $email,
            'password' => 'password123',
            'status' => 'active',
        ]);
    }

    private function provider(string $email, float $latitude, float $longitude): User
    {
        $user = $this->user(User::ROLE_PROVIDER, $email);
        $profile = $user->providerProfile()->create([
            'business_name' => $email,
            'provider_type' => 'barber',
            'is_approved' => true,
            'identity_status' => 'APPROVED',
            'latitude' => $latitude,
            'longitude' => $longitude,
        ]);
        $profile->documents()->create([
            'document_type' => 'DIPLOMA',
            'original_name' => 'diploma.pdf',
            'storage_path' => 'test/diploma.pdf',
            'mime_type' => 'application/pdf',
            'file_size' => 128,
            'status' => 'APPROVED',
        ]);

        return $user;
    }
}
