<?php

namespace Tests\Feature;

use App\Events\NotificationCreated;
use App\Jobs\SendPushNotification;
use App\Models\PushDevice;
use App\Models\ServiceRequest;
use App\Models\User;
use App\Models\UserNotification;
use App\Services\FcmPushService;
use App\Services\GoogleGeocodingService;
use App\Services\InstantOpportunityNotifier;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Bus;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Mockery;
use Tests\TestCase;

class SelectedAddressRulesTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Http::preventStrayRequests();
        Bus::fake([SendPushNotification::class]);
        Event::fake([NotificationCreated::class]);
        $this->seed(\Database\Seeders\ServiceCatalogSeeder::class);
    }

    private function user(string $role): User
    {
        static $counter = 0;
        return User::create(['role' => $role, 'name' => 'Test User', 'first_name' => 'Test', 'last_name' => 'User',
            'email' => 'location-' . ++$counter . '@example.test', 'password' => 'safe-password', 'status' => 'active']);
    }

    private function customer(): User
    {
        $user = $this->user('CUSTOMER');
        $profile = $user->customerProfile()->create();
        $profile->addresses()->create(['title' => 'Mahmutlar', 'province' => 'Antalya', 'district' => 'Alanya',
            'latitude' => 36.49, 'longitude' => 32.09, 'is_default' => true]);
        $profile->addresses()->create(['title' => 'Şişli', 'province' => 'İstanbul', 'district' => 'Şişli',
            'latitude' => 41.06, 'longitude' => 28.99, 'is_default' => false]);
        return $user;
    }

    private function provider(?float $lat, ?float $lng, bool $online = true, array $services = [1, 2]): User
    {
        $user = $this->user('PROVIDER');
        $profile = $user->providerProfile()->create(['business_name' => 'Test', 'provider_type' => 'barber',
            'latitude' => $lat, 'longitude' => $lng, 'service_radius_km' => 10,
            'is_approved' => true, 'identity_status' => 'APPROVED', 'is_online' => $online, 'accepts_new_clients' => true]);
        $profile->documents()->create(['document_type' => 'DIPLOMA', 'original_name' => 'test.pdf',
            'storage_path' => 'test.pdf', 'mime_type' => 'application/pdf', 'file_size' => 128, 'status' => 'APPROVED']);
        foreach ($services as $id) $profile->providerServices()->create(['service_id' => $id, 'price' => 100,
            'duration_minutes' => 30, 'is_active' => true]);
        return $user;
    }

    public function test_appointment_discovery_uses_selected_address_ignoring_default_and_spoofed_coordinates(): void
    {
        $customer = $this->customer();
        $near = $this->provider(41.061, 28.991);
        $far = $this->provider(36.491, 32.091);
        $this->provider(null, null);
        $address = $customer->customerProfile->addresses()->where('title', 'Şişli')->first();
        Sanctum::actingAs($customer);
        $response = $this->getJson('/api/customer/providers?service_ids=1&customer_address_id=' . $address->id . '&lat=36.49&lng=32.09')
            ->assertOk()->assertJsonCount(1, 'data')->assertJsonPath('data.0.user_id', (string) $near->id);
        $this->assertLessThan(1, $response->json('data.0.distance_km'));
        $other = $customer->customerProfile->addresses()->where('is_default', true)->first();
        $this->getJson('/api/customer/providers?service_ids=1&customer_address_id=' . $other->id)
            ->assertOk()->assertJsonPath('data.0.user_id', (string) $far->id);
    }

    public function test_other_customers_address_is_rejected_for_discovery_and_instant_creation(): void
    {
        $customer = $this->customer();
        $foreign = $this->customer()->customerProfile->addresses()->first();
        Sanctum::actingAs($customer);
        $this->getJson('/api/customer/providers?customer_address_id=' . $foreign->id)->assertForbidden();
        $this->postJson('/api/customer/service-requests', ['service_ids' => [1], 'customer_address_id' => $foreign->id])->assertForbidden();
        $this->assertDatabaseCount('service_requests', 0);
    }

    public function test_scheduled_booking_cannot_bypass_the_selected_address_radius(): void
    {
        $customer = $this->customer();
        $far = $this->provider(36.49, 32.09);
        Sanctum::actingAs($customer);
        $this->postJson('/api/customer/appointments', [
            'provider_id' => $far->id, 'service_ids' => [1],
            'date' => now()->addDay()->toDateString(), 'time' => '10:00',
            'customer_address_id' => $customer->customerProfile->addresses()->where('title', 'Şişli')->value('id'),
        ])->assertUnprocessable()->assertJsonPath('message', 'Seçilen hizmet veren bu adresin hizmet alanı dışında. Adrese yakın bir hizmet veren seçin.');
        $this->assertDatabaseCount('appointments', 0);
    }

    public function test_profile_address_edit_replaces_old_coordinates_and_nearby_origin(): void
    {
        $customer = $this->customer();
        $near = $this->provider(41.061, 28.991);
        $this->provider(36.491, 32.091);
        $geocoder = Mockery::mock(GoogleGeocodingService::class);
        $geocoder->shouldReceive('search')->once()->with('Şişli, İstanbul, Türkiye')
            ->andReturn(['status' => 'OK', 'data' => ['latitude' => 41.06, 'longitude' => 28.99]]);
        $this->app->instance(GoogleGeocodingService::class, $geocoder);
        Sanctum::actingAs($customer);
        $this->putJson('/api/customer/profile', ['address' => ['province' => 'İstanbul', 'district' => 'Şişli']])->assertOk();
        $this->getJson('/api/customer/providers/nearby')->assertOk()
            ->assertJsonCount(1, 'data')->assertJsonPath('data.0.user_id', (string) $near->id);
        $this->assertSame(41.06, (float) $customer->customerProfile->defaultAddress()->first()->latitude);
    }

    public function test_instant_opportunities_and_marketplace_share_the_selected_address_eligibility(): void
    {
        $customer = $this->customer();
        $near = $this->provider(41.061, 28.991);
        $far = $this->provider(36.49, 32.09);
        $offline = $this->provider(41.062, 28.992, false);
        $partial = $this->provider(41.063, 28.993, true, [1]);
        $unknown = $this->provider(null, null);
        $address = $customer->customerProfile->addresses()->where('title', 'Şişli')->first();
        Sanctum::actingAs($customer);
        $id = $this->postJson('/api/customer/service-requests', ['service_ids' => [1, 2], 'customer_address_id' => $address->id,
            'private_latitude' => 36.49, 'private_longitude' => 32.09])->assertCreated()->json('data.id');
        $request = ServiceRequest::findOrFail($id);
        $this->assertSame(41.06, $request->private_latitude);
        $this->assertDatabaseHas('user_notifications', ['user_id' => $near->id, 'title' => 'Yeni iş fırsatı']);
        foreach ([$far, $offline, $partial, $unknown] as $excluded) {
            $this->assertDatabaseMissing('user_notifications', ['user_id' => $excluded->id, 'type' => UserNotification::TYPE_INSTANT_OPPORTUNITY]);
        }
        $this->assertDatabaseCount('user_notifications', 1);
        Bus::assertDispatched(SendPushNotification::class);
        app(InstantOpportunityNotifier::class)->notifyEligible($request);
        $this->assertDatabaseCount('user_notifications', 1);
        $notification = UserNotification::first();
        $this->assertStringNotContainsString('41.06', $notification->toJson());
        $this->assertStringNotContainsString('customer_address_id', $notification->toJson());
        Sanctum::actingAs($near);
        $this->getJson('/api/provider/service-requests')->assertOk()->assertJsonCount(1, 'data');
        Sanctum::actingAs($far);
        $this->getJson('/api/provider/service-requests')->assertOk()->assertJsonCount(0, 'data');
    }

    public function test_missing_coordinates_cannot_fall_back_to_a_different_saved_address(): void
    {
        $customer = $this->customer();
        $address = $customer->customerProfile->addresses()->where('title', 'Şişli')->first();
        $address->update(['latitude' => null, 'longitude' => null]);
        $geocoder = Mockery::mock(GoogleGeocodingService::class);
        $geocoder->shouldReceive('search')->andReturn(['status' => 'ZERO_RESULTS']);
        $this->app->instance(GoogleGeocodingService::class, $geocoder);
        Sanctum::actingAs($customer);
        $this->getJson('/api/customer/providers?customer_address_id=' . $address->id)->assertUnprocessable();
        $this->postJson('/api/customer/service-requests', ['service_ids' => [1], 'customer_address_id' => $address->id])->assertUnprocessable();
        $this->assertDatabaseCount('service_requests', 0);
        $this->assertDatabaseCount('user_notifications', 0);
    }

    public function test_old_saved_address_can_be_geocoded_and_used_without_changing_the_default(): void
    {
        $customer = $this->customer();
        $address = $customer->customerProfile->addresses()->where('title', 'Şişli')->first();
        $address->update(['latitude' => null, 'longitude' => null]);
        $geocoder = Mockery::mock(GoogleGeocodingService::class);
        $geocoder->shouldReceive('search')->once()->andReturn(['status' => 'OK', 'data' => ['latitude' => 41.06, 'longitude' => 28.99]]);
        $this->app->instance(GoogleGeocodingService::class, $geocoder);
        $near = $this->provider(41.061, 28.991);
        Sanctum::actingAs($customer);
        $this->getJson('/api/customer/providers?customer_address_id=' . $address->id)->assertOk()->assertJsonPath('data.0.user_id', (string) $near->id);
        $this->assertSame(41.06, (float) $address->fresh()->latitude);
        $this->assertFalse($address->fresh()->is_default);
    }

    public function test_eligible_opportunity_reaches_firebase_payload_once_without_private_location(): void
    {
        $customer = $this->customer();
        $provider = $this->provider(41.061, 28.991);
        PushDevice::create(['user_id' => $provider->id, 'platform' => 'ANDROID', 'token_hash' => hash('sha256', 'test-device'),
            'token_encrypted' => 'test-device', 'status' => 'ACTIVE']);
        Sanctum::actingAs($customer);
        $this->postJson('/api/customer/service-requests', ['service_ids' => [1],
            'customer_address_id' => $customer->customerProfile->addresses()->where('title', 'Şişli')->value('id')])->assertCreated();
        config(['fcm.enabled' => true, 'fcm.project_id' => 'test-project']);
        FcmPushService::resolveAccessTokenUsing(fn () => 'test-oauth-token');
        Http::fake(['fcm.googleapis.com/*' => Http::response(['name' => 'projects/test-project/messages/test-message'])]);
        try {
            $job = new SendPushNotification(UserNotification::firstOrFail()->id);
            $job->handle(app(FcmPushService::class));
            $job->handle(app(FcmPushService::class));
            Http::assertSentCount(1);
            Http::assertSent(fn ($request) => $request['message']['notification']['title'] === 'Yeni iş fırsatı'
                && $request['message']['data']['resource_type'] === 'INSTANT_REQUEST'
                && !str_contains(json_encode($request['message']), '41.06'));
            $this->assertDatabaseHas('push_delivery_attempts', ['status' => 'SENT']);
        } finally { FcmPushService::resolveAccessTokenUsing(null); }
    }

    public function test_push_queue_rechecks_closed_requests_before_contacting_firebase(): void
    {
        $customer = $this->customer();
        $provider = $this->provider(41.061, 28.991);
        PushDevice::create(['user_id' => $provider->id, 'platform' => 'ANDROID', 'token_hash' => hash('sha256', 'fake-test-token'),
            'token_encrypted' => 'fake-test-token', 'status' => 'ACTIVE']);
        Sanctum::actingAs($customer);
        $id = $this->postJson('/api/customer/service-requests', ['service_ids' => [1],
            'customer_address_id' => $customer->customerProfile->addresses()->where('title', 'Şişli')->value('id')])->assertCreated()->json('data.id');
        ServiceRequest::findOrFail($id)->update(['status' => ServiceRequest::STATUS_CANCELLED]);
        $fcm = Mockery::mock(FcmPushService::class);
        $fcm->shouldNotReceive('sendToDevice');
        (new SendPushNotification(UserNotification::firstOrFail()->id))->handle($fcm);
        $this->assertDatabaseCount('push_delivery_attempts', 0);
    }
}
