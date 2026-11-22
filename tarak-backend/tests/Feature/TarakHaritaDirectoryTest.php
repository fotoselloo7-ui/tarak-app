<?php

namespace Tests\Feature;

use App\Models\AdminLog;
use App\Models\ProviderDiscount;
use App\Models\ProviderDocument;
use App\Models\ProviderProfile;
use App\Models\ProviderReview;
use App\Models\ProviderServiceArea;
use App\Models\ProviderStaff;
use App\Models\ProviderStaffService;
use App\Models\Service;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class TarakHaritaDirectoryTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(\Database\Seeders\ServiceCatalogSeeder::class);
    }

    private function makeUser(string $role, array $overrides = []): User
    {
        static $seq = 0;
        $seq++;

        return User::create(array_merge([
            'role' => $role,
            'first_name' => 'Test',
            'last_name' => 'Kullanıcı ' . $seq,
            'name' => 'Test Kullanıcı ' . $seq,
            'email' => "harita-{$seq}@example.test",
            'password' => 'safe-password-123',
            'status' => 'active',
        ], $overrides));
    }

    private function makeProvider(array $profileOverrides = [], array $userOverrides = []): ProviderProfile
    {
        $user = $this->makeUser(User::ROLE_PROVIDER, $userOverrides);
        $profile = $user->providerProfile()->create(array_merge([
            'business_name' => 'Makas Berber ' . $user->id,
            'provider_type' => 'barber',
            'work_mode' => ProviderProfile::WORK_MODE_VENUE,
            'is_approved' => false,
            'identity_status' => 'PENDING',
            'is_online' => false,
            'accepts_new_clients' => false,
            'directory_listed' => true,
            'directory_status' => ProviderProfile::DIRECTORY_APPROVED,
            'directory_approved_at' => now(),
            'service_radius_km' => 10,
            'city' => 'İstanbul',
            'district' => 'Kadıköy',
            'neighborhood' => 'Moda',
            'street' => 'Moda Caddesi',
            'building_no' => '18',
            'latitude' => 40.9865,
            'longitude' => 29.0278,
        ], $profileOverrides));
        $profile->setRelation('user', $user);
        $profile->ensureSlug();
        $profile->save();

        return $profile;
    }

    public function test_tarak_harita_migration_is_reversible(): void
    {
        $this->assertTrue(Schema::hasTable('provider_service_areas'));
        $this->assertTrue(Schema::hasColumns('provider_profiles', [
            'slug', 'directory_listed', 'directory_status', 'logo_url',
            'contact_phone', 'whatsapp_phone', 'instagram_handle', 'website_url', 'show_public_contact',
        ]));

        $migration = require database_path('migrations/2026_11_20_100000_add_tarak_harita_directory_fields.php');
        $migration->down();

        $this->assertFalse(Schema::hasTable('provider_service_areas'));
        $this->assertFalse(Schema::hasColumn('provider_profiles', 'directory_listed'));
        $this->assertFalse(Schema::hasColumn('provider_profiles', 'slug'));

        $migration->up();

        $this->assertTrue(Schema::hasTable('provider_service_areas'));
        $this->assertTrue(Schema::hasColumns('provider_profiles', ['slug', 'directory_listed', 'directory_status']));
    }

    public function test_directory_only_registration_and_admin_moderation_never_grant_verified_badge(): void
    {
        $this->withHeader('X-Tarak-Client', 'mobile-secure-v2');
        $admin = $this->makeUser(User::ROLE_ADMIN);

        $email = 'rehber-usta@example.test';
        $this->postJson('/api/auth/verification/email/send', ['email' => $email])->assertOk();
        $mail = app('mailer')->getSymfonyTransport()->messages()->last()->getOriginalMessage();
        preg_match('/\b(\d{6})\b/', $mail->getTextBody(), $match);
        $proof = $this->postJson('/api/auth/verification/email/confirm', [
            'email' => $email,
            'code' => $match[1],
        ])->assertOk()->json('data.verification_token');

        $registerRes = $this->postJson('/api/auth/register', [
            'role' => 'PROVIDER',
            'first_name' => 'Kerem',
            'last_name' => 'Berber',
            'email' => $email,
            'email_verification_token' => $proof,
            'password' => 'safe-password-123',
            'password_confirmation' => 'safe-password-123',
            'business_name' => 'Kerem Berber Salonu',
            'work_mode' => 'venue',
            'directory_listed' => true,
            'accepts_new_clients' => false,
            'city' => 'İstanbul',
            'district' => 'Beşiktaş',
            'accept_terms' => true,
            'accept_kvkk' => true,
        ])->assertCreated();

        $providerId = (int) $registerRes->json('data.user.id');
        $profile = ProviderProfile::where('user_id', $providerId)->firstOrFail();

        // Pending directory status before admin approval
        $this->assertTrue($profile->directory_listed);
        $this->assertSame(ProviderProfile::DIRECTORY_PENDING, $profile->directory_status);
        $this->assertFalse($profile->accepts_new_clients);
        $this->assertFalse($profile->is_approved);
        $this->assertFalse($profile->isVerified());

        // Provider updates coordinates/address
        Sanctum::actingAs($profile->user);
        $this->putJson('/api/provider/profile', [
            'latitude' => 41.043,
            'longitude' => 29.007,
            'city' => 'İstanbul',
            'district' => 'Beşiktaş',
            'street' => 'Barbaros Blv',
            'building_no' => '10',
        ])->assertOk();

        // Still hidden from public map while PENDING
        $this->getJson('/api/map/businesses')->assertOk()->assertJsonCount(0, 'data');

        // Admin approves directory listing (only)
        Sanctum::actingAs($admin);
        $this->postJson("/api/admin/directory/businesses/{$profile->id}/review", [
            'action' => 'APPROVE',
        ])->assertOk()
            ->assertJsonPath('data.directory_status', 'APPROVED')
            ->assertJsonPath('data.is_verified', false)
            ->assertJsonPath('data.is_approved', false);

        $profile->refresh();
        $this->assertFalse($profile->is_approved);
        $this->assertSame('PENDING', $profile->identity_status);
        $this->assertFalse($profile->isVerified());
        $this->assertDatabaseHas('admin_logs', [
            'action' => AdminLog::ACTION_DIRECTORY_APPROVED,
            'target_id' => $profile->id,
        ]);

        // Now visible on Tarak Harita, without verified badge and without Tarak booking
        $this->getJson('/api/map/businesses')->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.business_name', 'Kerem Berber Salonu')
            ->assertJsonPath('data.0.is_verified', false)
            ->assertJsonPath('data.0.accepts_tarak_bookings', false);

        // Directory-only provider cannot be booked via Tarak appointments
        $customer = $this->makeUser(User::ROLE_CUSTOMER);
        $custProfile = $customer->customerProfile()->create();
        $addr = $custProfile->addresses()->create([
            'title' => 'Ev', 'province' => 'İstanbul', 'district' => 'Beşiktaş',
            'latitude' => 41.043, 'longitude' => 29.007, 'is_default' => true,
        ]);
        Sanctum::actingAs($customer);
        $this->postJson('/api/customer/appointments', [
            'provider_id' => $providerId,
            'service_ids' => [1],
            'date' => now()->addDay()->toDateString(),
            'time' => '11:00',
            'customer_address_id' => $addr->id,
        ])->assertUnprocessable();

        // Admin suspends directory listing -> disappears from map and web page, and cannot self-relist
        Sanctum::actingAs($admin);
        $this->postJson("/api/admin/directory/businesses/{$profile->id}/review", [
            'action' => 'SUSPEND',
            'reason' => 'Yanıltıcı adres bilgisi',
        ])->assertOk()->assertJsonPath('data.directory_status', 'SUSPENDED');

        $this->getJson('/api/map/businesses')->assertOk()->assertJsonCount(0, 'data');
        $this->get("/isletme/{$profile->slug}")->assertNotFound();

        Sanctum::actingAs($profile->user);
        $this->putJson('/api/provider/profile', ['directory_listed' => true])->assertUnprocessable();
    }

    public function test_mobile_provider_home_location_is_never_exposed_as_public_pin_or_address(): void
    {
        $venue = $this->makeProvider([
            'business_name' => 'Salon Kadıköy',
            'work_mode' => 'venue',
            'city' => 'İstanbul',
            'district' => 'Kadıköy',
            'latitude' => 40.9865,
            'longitude' => 29.0278,
            'street' => 'Bahariye Cad.',
            'building_no' => '42',
            'address_detail' => 'Kat 2 Daire 4',
        ]);

        $mobile = $this->makeProvider([
            'business_name' => 'Gezici Usta Ahmet',
            'work_mode' => 'mobile',
            'city' => 'İstanbul',
            'district' => 'Kadıköy',
            'neighborhood' => 'Fenerbahçe',
            'street' => 'Gizli Ev Sokağı',
            'building_no' => '99',
            'address_detail' => 'Kendi ev adresi daire 7',
            'latitude' => 40.9712345,
            'longitude' => 29.0398765,
            'service_radius_km' => 15,
        ]);
        $mobile->serviceAreas()->create([
            'province' => 'İstanbul',
            'district' => 'Kadıköy',
            'neighborhood' => null,
            'normalized_key' => ProviderServiceArea::makeNormalizedKey('İstanbul', 'Kadıköy', null),
        ]);

        // Map endpoint: venue is in `data` (pins), mobile is ONLY in `mobile_providers` with coordinates stripped
        $res = $this->getJson('/api/map/businesses?city=İstanbul&district=Kadıköy')->assertOk();
        $res->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.slug', $venue->slug)
            ->assertJsonPath('data.0.can_get_directions', true)
            ->assertJsonCount(1, 'mobile_providers')
            ->assertJsonPath('mobile_providers.0.slug', $mobile->slug)
            ->assertJsonPath('mobile_providers.0.latitude', null)
            ->assertJsonPath('mobile_providers.0.longitude', null)
            ->assertJsonPath('mobile_providers.0.has_public_pin', false)
            ->assertJsonPath('mobile_providers.0.can_get_directions', false)
            ->assertJsonPath('mobile_providers.0.formatted_address', 'Kadıköy, İstanbul');

        $rawContent = $res->getContent();
        $this->assertStringNotContainsString('40.9712345', $rawContent);
        $this->assertStringNotContainsString('29.0398765', $rawContent);
        $this->assertStringNotContainsString('Gizli Ev Sokağı', $rawContent);
        $this->assertStringNotContainsString('Kendi ev adresi', $rawContent);

        // Detail API for mobile provider also strips coordinates & street details
        $detail = $this->getJson("/api/map/businesses/{$mobile->slug}")->assertOk()
            ->assertJsonPath('data.latitude', null)
            ->assertJsonPath('data.longitude', null)
            ->assertJsonPath('data.street', null)
            ->assertJsonPath('data.building_no', null)
            ->assertJsonPath('data.address_detail', null)
            ->assertJsonPath('data.has_public_pin', false)
            ->assertJsonPath('data.can_get_directions', false);
        $this->assertStringNotContainsString('40.9712345', $detail->getContent());

        // Public web HTML page for mobile provider omits coordinates, street, GeoCoordinates & directions
        $web = $this->get("/isletme/{$mobile->slug}")->assertOk();
        $html = $web->getContent();
        $this->assertStringNotContainsString('40.9712345', $html);
        $this->assertStringNotContainsString('29.0398765', $html);
        $this->assertStringNotContainsString('Gizli Ev Sokağı', $html);
        $this->assertStringNotContainsString('GeoCoordinates', $html);
        $this->assertStringNotContainsString('Yol Tarifi Al', $html);
        $this->assertStringContainsString('areaServed', $html);
    }

    public function test_service_areas_multi_district_neighborhood_matching_and_filtering(): void
    {
        $provider = $this->makeProvider([
            'work_mode' => 'both',
            'is_approved' => true,
            'identity_status' => 'APPROVED',
            'is_online' => true,
            'accepts_new_clients' => true,
            'city' => 'İstanbul',
            'district' => 'Kadıköy',
            'latitude' => 40.990,
            'longitude' => 29.028,
            'service_radius_km' => 5,
        ]);
        $provider->documents()->create([
            'document_type' => 'DIPLOMA',
            'original_name' => 'diploma.pdf',
            'storage_path' => 'test/diploma.pdf',
            'mime_type' => 'application/pdf',
            'file_size' => 128,
            'status' => 'APPROVED',
        ]);
        $provider->providerServices()->create(['service_id' => 1, 'is_active' => true]);

        Sanctum::actingAs($provider->user);
        $this->putJson('/api/provider/profile', [
            'service_areas' => [
                ['province' => 'İstanbul', 'district' => 'Üsküdar', 'neighborhood' => 'Kuzguncuk'],
                ['province' => 'İstanbul', 'district' => 'Ataşehir'],
                // Duplicate normalized entry should deduplicate cleanly
                ['province' => 'İSTANBUL', 'district' => 'ataşehir', 'neighborhood' => ''],
            ],
        ])->assertOk()->assertJsonCount(2, 'data.profile.service_areas');

        // Filtering map by neighborhood & Turkish normalization
        $this->getJson('/api/map/businesses?city=istanbul&district=uskudar&neighborhood=kuzguncuk')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.slug', $provider->slug);

        // Filtering by a district NOT covered returns empty
        $this->getJson('/api/map/businesses?city=istanbul&district=bakirkoy')
            ->assertOk()
            ->assertJsonCount(0, 'data');

        // Customer in Ataşehir (outside 5km radius, inside explicit district area) can still book
        $customer = $this->makeUser(User::ROLE_CUSTOMER);
        $custProfile = $customer->customerProfile()->create();
        $addr = $custProfile->addresses()->create([
            'title' => 'İş',
            'province' => 'İstanbul',
            'district' => 'Ataşehir',
            'neighborhood' => 'Barbaros',
            'latitude' => 40.992,
            'longitude' => 29.115, // ~7.3 km away (> 5 km radius, matched via explicit district)
            'is_default' => true,
        ]);
        $provider->weeklySchedules()->create([
            'day_of_week' => strtolower(now()->addDay()->format('l')),
            'is_enabled' => true,
            'start_time' => '09:00',
            'end_time' => '20:00',
        ]);

        Sanctum::actingAs($customer);
        $this->getJson('/api/customer/providers?customer_address_id=' . $addr->id)
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.user_id', (string) $provider->user_id);

        $this->postJson('/api/customer/appointments', [
            'provider_id' => $provider->user_id,
            'service_ids' => [1],
            'date' => now()->addDay()->toDateString(),
            'time' => '11:00',
            'customer_address_id' => $addr->id,
        ])->assertCreated();
    }

    public function test_provider_showcase_logo_contact_privacy_and_seo_web_pages(): void
    {
        Storage::fake('public');

        $admin = $this->makeUser(User::ROLE_ADMIN, ['phone' => '+905550000001']);
        $profile = $this->makeProvider([
            'business_name' => 'Çınar Erkek Kuaförü',
            'provider_type' => 'barber',
            'work_mode' => 'venue',
            'is_approved' => true,
            'identity_status' => 'APPROVED',
            'bio' => 'Şişli merkezde klasik ve modern erkek saç kesimi.',
            'city' => 'İstanbul',
            'district' => 'Şişli',
            'street' => 'Halaskargazi Cad.',
            'building_no' => '105',
            'latitude' => 41.055,
            'longitude' => 28.987,
        ], [
            'phone' => '+905558889900',
        ]);
        // Simulate legacy stored contact fields: data stays intact in DB, NEVER leaks publicly!
        $profile->forceFill([
            'contact_phone' => '+905551112233',
            'whatsapp_phone' => '+905559998877',
            'instagram_handle' => 'cinar_gizli_ig',
            'website_url' => 'https://cinar-gizli.example.com',
            'show_public_contact' => true,
        ])->save();

        $profile->providerServices()->create(['service_id' => 1, 'custom_price' => 450, 'is_active' => true]);
        $profile->weeklySchedules()->create([
            'day_of_week' => 'monday',
            'is_enabled' => true,
            'start_time' => '09:00',
            'end_time' => '21:00',
        ]);
        $customer = $this->makeUser(User::ROLE_CUSTOMER);
        ProviderReview::create([
            'provider_user_id' => $profile->user_id,
            'customer_user_id' => $customer->id,
            'rating' => 5,
            'comment' => 'Çok özenli hizmet.',
        ]);

        Sanctum::actingAs($profile->user);
        $logoFile = UploadedFile::fake()->image('logo.png', 200, 200);
        $uploadRes = $this->post('/api/provider/profile/logo', ['logo' => $logoFile])
            ->assertOk();
        $this->assertNotEmpty($uploadRes->json('data.logo_url'));

        // Attempting to mass-assign contact_phone via profile update does NOT change DB or expose publicly
        $profileRes = $this->putJson('/api/provider/profile', [
            'title' => 'Modern Erkek Berberliği',
            'contact_phone' => '+905550009999',
            'whatsapp_phone' => '+905550008888',
            'instagram_handle' => '@hacker_handle',
            'website_url' => 'https://evil.example',
            'show_public_contact' => true,
        ])->assertOk();
        $profileJson = $profileRes->getContent();
        foreach (['contact_phone', 'whatsapp_phone', 'instagram_handle', 'website_url', 'show_public_contact', '+905551112233'] as $forbidden) {
            $this->assertStringNotContainsString($forbidden, $profileJson);
        }

        // Public web listing, profile page (with Schema.org BarberShop + GeoCoordinates), and sitemap.xml
        $listHtml = $this->get('/isletmeler')->assertOk()->getContent();
        $this->assertStringContainsString('Çınar Erkek Kuaförü', $listHtml);
        $this->assertStringContainsString('Profili Gör', $listHtml);
        $this->assertStringNotContainsString('Vitrini Gör', $listHtml);
        $this->assertStringNotContainsString('★', $listHtml);

        $showHtml = $this->get("/isletme/{$profile->slug}")->assertOk()->getContent();
        $this->assertStringContainsString('BarberShop', $showHtml);
        $this->assertStringContainsString('GeoCoordinates', $showHtml);
        $this->assertStringContainsString('Yol Tarifi Al', $showHtml);
        $this->assertStringContainsString('Tarak Puanı:', $showHtml);
        $this->assertStringNotContainsString('★', $showHtml);
        foreach (['+905551112233', '+905559998877', '+905558889900', 'cinar_gizli_ig', 'cinar-gizli.example.com', 'tel:', 'wa.me', '"telephone"'] as $leaked) {
            $this->assertStringNotContainsString($leaked, $showHtml);
        }

        // Public APIs (map list, map detail, providers list & detail) must NEVER expose contact or user security phone
        foreach ([
            '/api/map/businesses',
            "/api/map/businesses/{$profile->slug}",
            '/api/providers',
            "/api/providers/{$profile->user_id}",
        ] as $publicEndpoint) {
            $raw = $this->getJson($publicEndpoint)->assertOk()->getContent();
            foreach (['contact_phone', 'whatsapp_phone', 'instagram_handle', 'website_url', 'show_public_contact', '+905551112233', '+905559998877', '+905558889900', 'cinar_gizli_ig', 'cinar-gizli.example.com'] as $leaked) {
                $this->assertStringNotContainsString($leaked, $raw, "Leak of '{$leaked}' detected on {$publicEndpoint}");
            }
        }
        $detailPayload = $this->getJson("/api/map/businesses/{$profile->slug}")->assertOk()->json('data');
        $this->assertArrayNotHasKey('contact', $detailPayload);

        $sitemap = $this->get('/sitemap.xml')->assertOk();
        $sitemap->assertHeader('Content-Type', 'application/xml; charset=UTF-8');
        $this->assertStringContainsString("/isletme/{$profile->slug}", $sitemap->getContent());

        // Authorized Admin STILL accesses the security phone (`users.phone`) & non-destructive legacy DB data intact
        Sanctum::actingAs($admin);
        $this->getJson("/api/admin/users/{$profile->user_id}")
            ->assertOk()
            ->assertJsonPath('data.phone', '+905558889900');
        $this->getJson("/api/admin/directory/businesses/{$profile->id}")
            ->assertOk()
            ->assertJsonPath('data.user_phone', '+905558889900');

        // Existing DB rows were NOT wiped
        $this->assertSame('+905551112233', $profile->fresh()->contact_phone);

        // Deleting logo works cleanly for owner
        Sanctum::actingAs($profile->user);
        $this->deleteJson('/api/provider/profile/logo')->assertOk()->assertJsonPath('data.logo_url', null);
    }

    public function test_map_endpoint_returns_5000_demo_providers_with_bbox_and_type_filtering(): void
    {
        $now = now();
        $total = 5000;
        $userRows = [];
        for ($i = 1; $i <= $total; $i++) {
            $userRows[] = [
                'role' => User::ROLE_PROVIDER,
                'first_name' => 'Demo',
                'last_name' => 'Usta ' . $i,
                'name' => 'Demo Usta ' . $i,
                'email' => "demo5k-{$i}@demo.tarak.test",
                'password' => 'hashed-placeholder',
                'status' => 'active',
                'is_demo' => true,
                'created_at' => $now,
                'updated_at' => $now,
            ];
        }
        foreach (array_chunk($userRows, 500) as $chunk) {
            \Illuminate\Support\Facades\DB::table('users')->insert($chunk);
        }
        unset($userRows);

        $userIds = \Illuminate\Support\Facades\DB::table('users')
            ->where('email', 'like', 'demo5k-%@demo.tarak.test')
            ->orderBy('id')
            ->pluck('id')
            ->all();

        $this->assertCount(5000, $userIds);

        $profileRows = [];
        foreach ($userIds as $idx => $userId) {
            $isCoiffeur = ($idx % 2) === 1;
            // Every 25th is mobile (200 mobile), remaining 4800 are venue/both
            $workMode = ($idx % 25) === 0 ? 'mobile' : (($idx % 3) === 0 ? 'both' : 'venue');
            // 200 providers sit in a Kadıköy bounding box; rest distributed in Ankara
            $inKadikoy = $idx < 200;
            $lat = $inKadikoy ? 40.985 + (($idx % 10) * 0.001) : 39.900 + (($idx % 50) * 0.002);
            $lng = $inKadikoy ? 29.020 + (($idx % 10) * 0.001) : 32.800 + (($idx % 50) * 0.002);

            $profileRows[] = [
                'user_id' => $userId,
                'provider_type' => $isCoiffeur ? 'coiffeur' : 'barber',
                'work_mode' => $workMode,
                'business_name' => ($isCoiffeur ? 'Demo Kuaför ' : 'Demo Berber ') . ($idx + 1),
                'slug' => 'demo-5k-' . $userId,
                'is_approved' => true,
                'identity_status' => 'APPROVED',
                'is_online' => true,
                'accepts_new_clients' => true,
                'directory_listed' => false,
                'directory_status' => ProviderProfile::DIRECTORY_NOT_REQUESTED,
                'service_radius_km' => 15,
                'city' => $inKadikoy ? 'İstanbul' : 'Ankara',
                'district' => $inKadikoy ? 'Kadıköy' : 'Çankaya',
                'latitude' => $lat,
                'longitude' => $lng,
                'created_at' => $now,
                'updated_at' => $now,
            ];
            if (count($profileRows) >= 400) {
                \Illuminate\Support\Facades\DB::table('provider_profiles')->insert($profileRows);
                $profileRows = [];
            }
        }
        if ($profileRows !== []) {
            \Illuminate\Support\Facades\DB::table('provider_profiles')->insert($profileRows);
        }
        unset($profileRows, $userIds);

        // Default limit=5000 returns all 4,800 venue/both demo pins and zero mobile pins in `data`
        $all = $this->getJson('/api/map/businesses?include_mobile=0')->assertOk();
        $all->assertJsonPath('meta.total_pins', 4800)
            ->assertJsonPath('meta.demo_pins', 4800)
            ->assertJsonPath('meta.total_eligible_pins', 4800);
        $this->assertFalse((bool) $all->json('data.0.is_verified'));
        $this->assertTrue((bool) $all->json('data.0.is_demo'));
        unset($all);

        // Category filters
        $barbers = $this->getJson('/api/map/businesses?type=barber&include_mobile=0&limit=500')->assertOk();
        $this->assertSame(500, $barbers->json('meta.total_pins'));
        foreach (array_slice($barbers->json('data'), 0, 20) as $item) {
            $this->assertSame('barber', $item['provider_type']);
        }
        unset($barbers);

        $coiffeurs = $this->getJson('/api/map/businesses?type=coiffeur&include_mobile=0&limit=500')->assertOk();
        $this->assertSame(500, $coiffeurs->json('meta.total_pins'));
        foreach (array_slice($coiffeurs->json('data'), 0, 20) as $item) {
            $this->assertSame('coiffeur', $item['provider_type']);
        }
        unset($coiffeurs);

        // Viewport bbox returns only Kadıköy providers
        $bboxRes = $this->getJson('/api/map/businesses?min_lat=40.980&max_lat=41.000&min_lng=29.015&max_lng=29.035&include_mobile=0')
            ->assertOk();
        $this->assertSame(192, $bboxRes->json('meta.total_pins'));
    }

    public function test_map_endpoint_works_gracefully_before_directory_migration_is_applied(): void
    {
        $migration = require database_path('migrations/2026_11_20_100000_add_tarak_harita_directory_fields.php');
        $migration->down();

        try {
            $user = $this->makeUser(User::ROLE_PROVIDER, ['is_demo' => true]);
            \Illuminate\Support\Facades\DB::table('provider_profiles')->insert([
                'user_id' => $user->id,
                'provider_type' => 'barber',
                'work_mode' => 'venue',
                'business_name' => 'Pre-Migration Demo Salon',
                'is_approved' => true,
                'identity_status' => 'APPROVED',
                'is_online' => true,
                'accepts_new_clients' => true,
                'service_radius_km' => 15,
                'city' => 'İstanbul',
                'district' => 'Kadıköy',
                'latitude' => 40.989,
                'longitude' => 29.025,
                'created_at' => now(),
                'updated_at' => now(),
            ]);

            $res = $this->getJson('/api/map/businesses')->assertOk();
            $res->assertJsonCount(1, 'data')
                ->assertJsonPath('data.0.business_name', 'Pre-Migration Demo Salon')
                ->assertJsonPath('data.0.is_verified', false);

            $this->getJson("/api/map/businesses/{$user->id}")
                ->assertOk()
                ->assertJsonPath('data.business_name', 'Pre-Migration Demo Salon');
        } finally {
            $migration->up();
        }
    }

    private function encodePolyline6(array $latLngPairs): string
    {
        $encode = static function (int $v): string {
            $v = $v < 0 ? ~($v << 1) : ($v << 1);
            $out = '';
            while ($v >= 0x20) {
                $out .= chr((0x20 | ($v & 0x1f)) + 63);
                $v >>= 5;
            }

            return $out . chr($v + 63);
        };

        $out = '';
        $prevLat = 0;
        $prevLng = 0;
        foreach ($latLngPairs as [$lat, $lng]) {
            $iLat = (int) round($lat * 1e6);
            $iLng = (int) round($lng * 1e6);
            $out .= $encode($iLat - $prevLat) . $encode($iLng - $prevLng);
            $prevLat = $iLat;
            $prevLng = $iLng;
        }

        return $out;
    }

    public function test_osm_pois_endpoint_is_disabled_and_only_registered_tarak_businesses_are_returned(): void
    {
        $venue = $this->makeProvider([
            'business_name' => 'Sadece Tarak Pin Berber',
            'city' => 'Antalya',
            'district' => 'Muratpaşa',
            'latitude' => 36.889,
            'longitude' => 30.704,
        ]);

        // External OSM POI endpoint removed / disabled
        $this->getJson('/api/map/osm-pois?south=36.86&west=30.68&north=36.92&east=30.74')
            ->assertNotFound();

        // Map API returns ONLY Tarak registered providers
        $res = $this->getJson('/api/map/businesses?city=Antalya')->assertOk();
        $res->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.slug', $venue->slug);
    }

    public function test_anti_bypass_moderation_rejects_external_contact_in_provider_texts_and_protects_cross_owner_edits(): void
    {
        $owner = $this->makeProvider([
            'business_name' => 'Güvenli Salon',
            'is_approved' => true,
            'identity_status' => 'APPROVED',
            'bio' => 'Temiz salon açıklaması',
        ]);
        $other = $this->makeProvider([
            'business_name' => 'Başka Salon',
            'is_approved' => true,
            'identity_status' => 'APPROVED',
        ]);

        Sanctum::actingAs($owner->user);

        // Phone, WhatsApp, @instagram, URL rejected with 422 without silently corrupting existing bio
        foreach ([
            ['bio' => 'Randevu için 0532 111 22 33 arayın.'],
            ['bio' => 'WhatsApp hattımızdan yazabilirsiniz.'],
            ['bio' => 'Instagram: @guvenli_salon bekliyoruz'],
            ['title' => 'Site: https://disrandevu.com'],
        ] as $badPayload) {
            $this->putJson('/api/provider/profile', $badPayload)
                ->assertUnprocessable();
        }
        $this->assertSame('Temiz salon açıklaması', $owner->fresh()->bio);

        // Legitimate bio with opening hours and TRY price passes cleanly
        $this->putJson('/api/provider/profile', [
            'bio' => 'Salı - Cumartesi 09:00 - 21:00 arası 450 TL kesim hizmeti.',
        ])->assertOk();

        // Service, package, staff & birthday custom message anti-bypass enforcement
        $this->putJson('/api/provider/services', [
            'services' => [
                ['service_id' => 1, 'custom_price' => 300, 'description' => 'DM at @berberim'],
            ],
        ])->assertUnprocessable();

        $this->patchJson('/api/provider/services', [
            'service_id' => 1,
            'description' => '05321112233 numaradan ulaşın',
        ])->assertUnprocessable();

        $this->postJson('/api/provider/packages', [
            'title' => 'Damat Paketi',
            'description' => 'Detay için www.salonsite.com adresine bakın',
            'price' => 800,
            'duration_minutes' => 60,
            'service_ids' => [1],
        ])->assertUnprocessable();

        $this->postJson('/api/provider/staff', [
            'first_name' => 'Ali',
            'last_name' => 'Veli',
            'specialty' => 'Instagram: @ali_usta',
        ])->assertUnprocessable();

        $this->putJson('/api/provider/birthday-assistant', [
            'template_key' => 'custom',
            'custom_message' => 'Doğum gününüz kutlu olsun! 0532 111 22 33 arayın.',
        ])->assertUnprocessable();

        // Cross-provider staff edit is blocked (404)
        $staff = ProviderStaff::create([
            'provider_profile_id' => $owner->id,
            'first_name' => 'Mehmet',
            'last_name' => 'Usta',
            'is_active' => true,
        ]);
        Sanctum::actingAs($other->user);
        $this->putJson("/api/provider/staff/{$staff->id}", ['first_name' => 'Hack'])
            ->assertNotFound();
    }

    public function test_map_route_endpoint_decodes_valhalla_road_route_falls_back_to_osrm_and_never_fakes_straight_line(): void
    {
        \Illuminate\Support\Facades\Cache::flush();
        $shape = $this->encodePolyline6([
            [36.8969, 30.7133],
            [36.8920, 30.7100],
            [36.8850, 30.7050],
        ]);
        $mode = 'valhalla_ok';

        \Illuminate\Support\Facades\Http::preventStrayRequests();
        \Illuminate\Support\Facades\Http::fake(function (\Illuminate\Http\Client\Request $request) use (&$mode, $shape) {
            $url = $request->url();
            if ($mode === 'valhalla_ok' && str_contains($url, 'valhalla')) {
                return \Illuminate\Support\Facades\Http::response([
                    'trip' => [
                        'summary' => ['length' => 2.45, 'time' => 420],
                        'legs' => [
                            ['shape' => $shape, 'summary' => ['length' => 2.45, 'time' => 420]],
                        ],
                    ],
                ], 200);
            }
            if ($mode === 'no_route' && str_contains($url, 'valhalla')) {
                return \Illuminate\Support\Facades\Http::response(['error' => 'No path'], 400);
            }

            return \Illuminate\Support\Facades\Http::response('down', 503);
        });

        $res = $this->getJson('/api/map/route?origin_lat=36.8969&origin_lng=30.7133&dest_lat=36.8850&dest_lng=30.7050&profile=driving')
            ->assertOk()
            ->assertJsonPath('data.provider', 'valhalla')
            ->assertJsonPath('data.distance_meters', 2450)
            ->assertJsonPath('data.duration_seconds', 420)
            ->assertJsonPath('data.geometry.type', 'LineString')
            ->assertJsonCount(3, 'data.geometry.coordinates');

        // GeoJSON coordinates are [lng, lat] order
        $coords = $res->json('data.geometry.coordinates');
        $this->assertEqualsWithDelta(30.7133, $coords[0][0], 0.0001);
        $this->assertEqualsWithDelta(36.8969, $coords[0][1], 0.0001);

        // No route returns 422 NO_ROUTE (no fabricated straight line)
        \Illuminate\Support\Facades\Cache::flush();
        $mode = 'no_route';
        $this->getJson('/api/map/route?origin_lat=37.42&origin_lng=-122.08&dest_lat=36.88&dest_lng=30.70')
            ->assertUnprocessable()
            ->assertJsonPath('code', 'NO_ROUTE');

        // Both Valhalla and OSRM unavailable returns 503 UNAVAILABLE
        \Illuminate\Support\Facades\Cache::flush();
        $mode = 'all_down';
        $this->getJson('/api/map/route?origin_lat=36.89&origin_lng=30.71&dest_lat=36.88&dest_lng=30.70')
            ->assertStatus(503)
            ->assertJsonPath('code', 'UNAVAILABLE');
    }

    public function test_map_filters_work_individually_and_together_without_gps_radius_blocking_city(): void
    {
        $antalyaHybrid = $this->makeProvider([
            'business_name' => 'Antalya Karma Salon',
            'provider_type' => 'coiffeur',
            'work_mode' => 'both',
            'city' => 'Antalya',
            'district' => 'Muratpaşa',
            'latitude' => 36.8880,
            'longitude' => 30.7050,
            'is_approved' => true,
            'identity_status' => 'APPROVED',
            'accepts_new_clients' => true,
        ]);
        $antalyaVenue = $this->makeProvider([
            'business_name' => 'Antalya Sadece İşletme Berber',
            'provider_type' => 'barber',
            'work_mode' => 'venue',
            'city' => 'Antalya',
            'district' => 'Konyaaltı',
            'latitude' => 36.8760,
            'longitude' => 30.6350,
            'is_approved' => true,
            'identity_status' => 'APPROVED',
            'accepts_new_clients' => false,
        ]);
        $antalyaMobile = $this->makeProvider([
            'business_name' => 'Antalya Gezici Berber',
            'provider_type' => 'barber',
            'work_mode' => 'mobile',
            'city' => 'Antalya',
            'district' => 'Kepez',
            'latitude' => 36.9123,
            'longitude' => 30.7199,
        ]);

        // Even with California GPS + radius_km=15, filtering city=Antalya returns Antalya pins!
        $antalyaAll = $this->getJson('/api/map/businesses?city=Antalya&lat=37.421998&lng=-122.084&radius_km=15')
            ->assertOk();
        $antalyaAll->assertJsonCount(2, 'data')
            ->assertJsonCount(1, 'mobile_providers')
            ->assertJsonPath('mobile_providers.0.latitude', null);

        // work_mode=venue returns both venue + hybrid pins, and zero mobile_providers
        $this->getJson('/api/map/businesses?city=Antalya&work_mode=venue')
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonCount(0, 'mobile_providers');

        // work_mode=mobile returns hybrid pin + privacy-stripped mobile_providers
        $this->getJson('/api/map/businesses?city=Antalya&work_mode=mobile')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.slug', $antalyaHybrid->slug)
            ->assertJsonCount(1, 'mobile_providers')
            ->assertJsonPath('mobile_providers.0.slug', $antalyaMobile->slug)
            ->assertJsonPath('mobile_providers.0.latitude', null);

        // booking_only + type=coiffeur returns only bookable Antalya coiffeur
        $this->getJson('/api/map/businesses?city=Antalya&type=coiffeur&booking_only=1')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.slug', $antalyaHybrid->slug);

        // q text search narrows accurately
        $this->getJson('/api/map/businesses?city=Antalya&q=Konyaalt%C4%B1')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.slug', $antalyaVenue->slug);

        // Empty result returns HTTP 200 empty data (not error)
        $this->getJson('/api/map/businesses?city=Ardahan')
            ->assertOk()
            ->assertJsonCount(0, 'data')
            ->assertJsonCount(0, 'mobile_providers');
    }

    public function test_map_business_detail_matches_canonical_provider_offerings_reviews_and_staff(): void
    {
        $profile = $this->makeProvider([
            'business_name' => 'Ortak Tasarım Berber',
            'provider_type' => 'barber',
            'work_mode' => 'both',
            'is_approved' => true,
            'identity_status' => 'APPROVED',
            'accepts_new_clients' => true,
            'city' => 'İstanbul',
            'district' => 'Şişli',
            'latitude' => 41.0555,
            'longitude' => 28.9866,
            'cover_url' => 'https://cdn.tarak.test/cover-sisli.jpg',
            'gallery' => ['https://cdn.tarak.test/g1.jpg', 'https://cdn.tarak.test/g2.jpg'],
        ], [
            'avatar_url' => 'https://cdn.tarak.test/avatar-sisli.jpg',
        ]);

        $profile->documents()->create([
            'document_type' => ProviderDocument::TYPE_MASTER_CERTIFICATE,
            'original_name' => 'ustalik.pdf',
            'storage_path' => 'test/ustalik.pdf',
            'mime_type' => 'application/pdf',
            'file_size' => 2048,
            'status' => ProviderDocument::STATUS_APPROVED,
        ]);

        $profile->providerServices()->create([
            'service_id' => 1,
            'custom_price' => 400,
            'custom_duration_minutes' => 45,
            'is_active' => true,
        ]);
        $svc2 = $profile->providerServices()->create([
            'service_id' => 2,
            'custom_price' => 250,
            'custom_duration_minutes' => 30,
            'is_active' => true,
        ]);
        $pkg = $profile->packages()->create([
            'title' => 'Bakım Paketi',
            'price' => 600,
            'duration_minutes' => 75,
            'is_active' => true,
        ]);
        $pkg->services()->attach([1, 2]);

        ProviderDiscount::create([
            'provider_user_id' => $profile->user_id,
            'percent' => 10,
            'starts_at' => now()->subHour(),
            'ends_at' => now()->addDay(),
        ]);

        $c1 = $this->makeUser(User::ROLE_CUSTOMER, ['name' => 'Müşteri Ali']);
        $c2 = $this->makeUser(User::ROLE_CUSTOMER, ['name' => 'Müşteri Veli']);
        ProviderReview::create([
            'provider_user_id' => $profile->user_id,
            'customer_user_id' => $c1->id,
            'rating' => 5,
            'comment' => 'Harika',
        ]);
        ProviderReview::create([
            'provider_user_id' => $profile->user_id,
            'customer_user_id' => $c2->id,
            'rating' => 4,
            'comment' => 'Çok iyi',
        ]);

        $visibleStaff = ProviderStaff::create([
            'provider_profile_id' => $profile->id,
            'first_name' => 'Emre',
            'last_name' => 'Kaya',
            'title' => 'Kıdemli Berber',
            'specialty' => 'Fade',
            'is_active' => true,
            'accepts_appointments' => true,
            'visible_to_customers' => true,
            'sort_order' => 1,
        ]);
        ProviderStaffService::create([
            'provider_staff_id' => $visibleStaff->id,
            'service_id' => 1,
            'is_active' => true,
        ]);

        ProviderStaff::create([
            'provider_profile_id' => $profile->id,
            'first_name' => 'Gizli',
            'last_name' => 'Usta',
            'is_active' => true,
            'accepts_appointments' => true,
            'visible_to_customers' => false,
            'sort_order' => 2,
        ]);
        ProviderStaff::create([
            'provider_profile_id' => $profile->id,
            'first_name' => 'Eski',
            'last_name' => 'Arşiv',
            'is_active' => false,
            'visible_to_customers' => true,
            'archived_at' => now(),
            'sort_order' => 3,
        ]);

        Sanctum::actingAs($c1);

        $reviewsRes = $this->getJson("/api/providers/{$profile->user_id}/reviews")->assertOk();
        $offeringsRes = $this->getJson("/api/customer/providers/{$profile->user_id}/offerings")->assertOk();
        $staffRes = $this->getJson("/api/customer/providers/{$profile->user_id}/staff")->assertOk();
        $mapRes = $this->getJson("/api/map/businesses/{$profile->slug}")->assertOk();

        // Identical business profile, verification, media, ratings & review counts
        $this->assertSame($offeringsRes->json('data.provider.business_name'), $mapRes->json('data.business_name'));
        $this->assertSame($offeringsRes->json('data.provider.provider_type'), $mapRes->json('data.provider_type'));
        $this->assertSame($offeringsRes->json('data.provider.avatar_url'), $mapRes->json('data.avatar_url'));
        $this->assertSame($offeringsRes->json('data.provider.cover_url'), $mapRes->json('data.cover_url'));
        $this->assertSame($offeringsRes->json('data.provider.gallery'), $mapRes->json('data.gallery'));
        $this->assertTrue($mapRes->json('data.is_verified'));
        $this->assertSame($offeringsRes->json('data.provider.is_verified'), $mapRes->json('data.is_verified'));
        $this->assertSame($reviewsRes->json('data.average'), $mapRes->json('data.rating'));
        $this->assertSame($reviewsRes->json('data.count'), $mapRes->json('data.review_count'));
        $this->assertSame($offeringsRes->json('data.provider.review_count'), $mapRes->json('data.review_count'));
        $this->assertEquals($offeringsRes->json('data.provider.rating'), $mapRes->json('data.rating'));

        // Identical discounted service and package prices
        $this->assertEquals(360, $mapRes->json('data.services.0.price'));
        $this->assertEquals($offeringsRes->json('data.services.0.price'), $mapRes->json('data.services.0.price'));
        $this->assertEquals($offeringsRes->json('data.services.0.original_price'), $mapRes->json('data.services.0.original_price'));
        $this->assertEquals(540, $mapRes->json('data.packages.0.price'));
        $this->assertEquals($offeringsRes->json('data.packages.0.price'), $mapRes->json('data.packages.0.price'));
        $this->assertEquals($svc2->effectivePrice() * 0.9, $mapRes->json('data.services.1.price'));

        // Identical visible active staff without verified badge leakage
        $staffRes->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $visibleStaff->id)
            ->assertJsonPath('data.0.full_name', 'Emre Kaya')
            ->assertJsonPath('data.0.accepts_appointments', true)
            ->assertJsonPath('data.0.services.0.service_id', 1);
        $this->assertNotEmpty($staffRes->json('data.0.services.0.service_name'));
        $this->assertArrayNotHasKey('is_verified', $staffRes->json('data.0'));

        $mapRes->assertJsonCount(1, 'data.staff')
            ->assertJsonPath('data.staff.0.id', $visibleStaff->id)
            ->assertJsonPath('data.staff.0.full_name', 'Emre Kaya');
        $this->assertArrayNotHasKey('is_verified', $mapRes->json('data.staff.0'));
    }
}
