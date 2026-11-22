<?php

namespace Tests\Feature;

use App\Models\Appointment;
use App\Models\CustomerAddress;
use App\Models\CustomerProfile;
use App\Models\NotificationDispatch;
use App\Models\ProviderClosedDate;
use App\Models\ProviderDocument;
use App\Models\ProviderNotificationControl;
use App\Models\ProviderProfile;
use App\Models\ProviderService;
use App\Models\ProviderStaff;
use App\Models\ProviderWeeklySchedule;
use App\Models\Service;
use App\Models\ServiceCategory;
use App\Models\User;
use App\Models\Wallet;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class WebParityAndSecurityTest extends TestCase
{
    use RefreshDatabase;

    private function seedCatalog(): Service
    {
        $cat = ServiceCategory::create([
            'id' => 'cat-1',
            'name' => 'Erkek Bakımı',
            'slug' => 'erkek-bakimi',
            'is_active' => true,
        ]);

        return Service::create([
            'category_id' => $cat->id,
            'name' => 'Saç Kesimi',
            'slug' => 'sac-kesimi',
            'base_price' => 300,
            'duration_minutes' => 30,
            'is_active' => true,
        ]);
    }

    private function createVerifiedProvider(Service $svc, string $workMode = 'venue', array $overrides = []): array
    {
        static $seq = 0;
        $seq++;

        $user = User::create([
            'role' => User::ROLE_PROVIDER,
            'first_name' => 'Usta',
            'last_name' => 'Test' . $seq,
            'name' => 'Usta Test ' . $seq,
            'email' => "web-parity-prov-{$seq}@test.local",
            'password' => 'safe-password-123',
            'status' => 'active',
        ]);

        $profile = ProviderProfile::create(array_merge([
            'user_id' => $user->id,
            'business_name' => 'Salon Parity ' . $seq,
            'provider_type' => 'barber',
            'work_mode' => $workMode,
            'is_approved' => true,
            'identity_status' => 'APPROVED',
            'is_online' => true,
            'accepts_new_clients' => true,
            'directory_listed' => true,
            'directory_status' => ProviderProfile::DIRECTORY_APPROVED,
            'city' => 'İstanbul',
            'district' => 'Şişli',
            'latitude' => 41.0602,
            'longitude' => 28.9877,
            'service_radius_km' => 10,
        ], $overrides));

        ProviderDocument::create([
            'provider_profile_id' => $profile->id,
            'document_type' => ProviderDocument::TYPE_MASTER_CERTIFICATE,
            'original_name' => 'ustalik.pdf',
            'storage_path' => 'kyc/ustalik.pdf',
            'mime_type' => 'application/pdf',
            'file_size' => 1024,
            'status' => ProviderDocument::STATUS_APPROVED,
        ]);

        ProviderService::create([
            'provider_profile_id' => $profile->id,
            'service_id' => $svc->id,
            'custom_price' => 350,
            'custom_duration_minutes' => 30,
            'is_active' => true,
        ]);

        foreach (['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'] as $day) {
            ProviderWeeklySchedule::create([
                'provider_profile_id' => $profile->id,
                'day_of_week' => $day,
                'is_enabled' => true,
                'start_time' => '09:00',
                'end_time' => '21:00',
            ]);
        }

        Wallet::create([
            'user_id' => $user->id,
            'balance' => 100,
            'promo_balance' => 500,
            'currency' => 'TRY',
        ]);

        return [$user, $profile];
    }

    private function createCustomer(bool $withAddress = false): User
    {
        static $cSeq = 0;
        $cSeq++;

        $user = User::create([
            'role' => User::ROLE_CUSTOMER,
            'first_name' => 'Müşteri',
            'last_name' => 'Test' . $cSeq,
            'name' => 'Müşteri Test ' . $cSeq,
            'email' => "web-parity-cust-{$cSeq}@test.local",
            'password' => 'safe-password-123',
            'status' => 'active',
        ]);

        $cp = CustomerProfile::create([
            'user_id' => $user->id,
            'birth_date' => '1993-05-14',
        ]);

        if ($withAddress) {
            CustomerAddress::create([
                'customer_profile_id' => $cp->id,
                'title' => 'Ev',
                'province' => 'İstanbul',
                'district' => 'Kadıköy',
                'latitude' => 40.9910,
                'longitude' => 29.0270,
                'is_default' => true,
            ]);
        }

        return $user;
    }

    public function test_map_detail_includes_closed_dates_and_hides_mobile_only_coordinates(): void
    {
        $svc = $this->seedCatalog();
        [$venueUser, $venueProfile] = $this->createVerifiedProvider($svc, 'venue');
        $closedDate = now()->addDays(3)->format('Y-m-d');
        ProviderClosedDate::create([
            'provider_profile_id' => $venueProfile->id,
            'date' => $closedDate,
            'reason' => 'Resmi Tatil',
        ]);

        [$mobileUser] = $this->createVerifiedProvider($svc, 'mobile', [
            'neighborhood' => 'Gizli Mahalle',
            'street' => 'Gizli Sokak',
            'latitude' => 41.09,
            'longitude' => 29.05,
        ]);

        $this->getJson("/api/map/businesses/{$venueUser->id}")
            ->assertOk()
            ->assertJsonPath('data.work_mode', 'venue')
            ->assertJsonPath('data.closed_dates.0.date', $closedDate)
            ->assertJsonPath('data.closed_dates.0.reason', 'Resmi Tatil');

        $this->getJson("/api/map/businesses/{$mobileUser->id}")
            ->assertOk()
            ->assertJsonPath('data.work_mode', 'mobile')
            ->assertJsonPath('data.has_public_pin', false)
            ->assertJsonPath('data.can_get_directions', false)
            ->assertJsonPath('data.latitude', null)
            ->assertJsonPath('data.longitude', null)
            ->assertJsonPath('data.neighborhood', null);
    }

    public function test_venue_scheduled_appointment_succeeds_without_address_and_rejects_mobile_only_without_address(): void
    {
        $svc = $this->seedCatalog();
        [$venueUser, $venueProfile] = $this->createVerifiedProvider($svc, 'venue');
        [$mobileUser] = $this->createVerifiedProvider($svc, 'mobile');
        $staff = ProviderStaff::create([
            'provider_profile_id' => $venueProfile->id,
            'first_name' => 'Emre',
            'last_name' => 'Kaya',
            'is_active' => true,
            'accepts_appointments' => true,
            'visible_to_customers' => true,
        ]);
        $staff->staffServices()->create(['service_id' => $svc->id, 'is_active' => true]);

        $customer = $this->createCustomer(withAddress: false);
        Sanctum::actingAs($customer);

        $tomorrow = now()->addDay()->format('Y-m-d');

        // Offerings clearly mark scheduled booking available even without address on venue provider
        $this->getJson("/api/customer/providers/{$venueUser->id}/offerings")
            ->assertOk()
            ->assertJsonPath('data.work_mode', 'venue')
            ->assertJsonPath('data.scheduled_booking_available', true)
            ->assertJsonPath('data.services.0.availability.available', false);

        // Customer without saved address can book venue appointment at a venue provider
        $this->postJson('/api/customer/appointments', [
            'provider_id' => $venueUser->id,
            'staff_id' => $staff->id,
            'service_ids' => [$svc->id],
            'date' => $tomorrow,
            'time' => '11:00',
            'service_location_type' => 'venue',
        ])->assertCreated()
            ->assertJsonPath('data.staff_id', (string) $staff->id);

        // Mobile-only provider rejects venue location mode
        $this->postJson('/api/customer/appointments', [
            'provider_id' => $mobileUser->id,
            'service_ids' => [$svc->id],
            'date' => $tomorrow,
            'time' => '11:00',
            'service_location_type' => 'venue',
        ])->assertUnprocessable();

        // Mobile mode requires saved customer address
        $this->postJson('/api/customer/appointments', [
            'provider_id' => $mobileUser->id,
            'service_ids' => [$svc->id],
            'date' => $tomorrow,
            'time' => '11:00',
            'service_location_type' => 'mobile',
        ])->assertUnprocessable();
    }

    public function test_provider_can_update_manual_appointment_with_conflict_and_ownership_protection(): void
    {
        $svc = $this->seedCatalog();
        [$provUser, $profile] = $this->createVerifiedProvider($svc, 'venue');
        [$otherProv] = $this->createVerifiedProvider($svc, 'venue');

        $staff1 = ProviderStaff::create([
            'provider_profile_id' => $profile->id,
            'first_name' => 'Emre',
            'last_name' => 'Kaya',
            'is_active' => true,
            'accepts_appointments' => true,
            'visible_to_customers' => true,
        ]);
        $staff2 = ProviderStaff::create([
            'provider_profile_id' => $profile->id,
            'first_name' => 'Burak',
            'last_name' => 'Demir',
            'is_active' => true,
            'accepts_appointments' => true,
            'visible_to_customers' => true,
        ]);
        $staff1->staffServices()->create(['service_id' => $svc->id, 'is_active' => true]);
        $staff2->staffServices()->create(['service_id' => $svc->id, 'is_active' => true]);

        $date = now()->addDay()->format('Y-m-d');
        Sanctum::actingAs($provUser);

        $appt1 = $this->postJson('/api/provider/appointments', [
            'customer_mode' => 'guest',
            'guest_customer_name' => 'Ali Misafir',
            'guest_customer_consent' => true,
            'service_ids' => [$svc->id],
            'staff_id' => $staff1->id,
            'date' => $date,
            'time' => '10:00',
        ])->assertCreated()->json('data.id');

        $appt2 = $this->postJson('/api/provider/appointments', [
            'customer_mode' => 'guest',
            'guest_customer_name' => 'Veli Misafir',
            'guest_customer_consent' => true,
            'service_ids' => [$svc->id],
            'staff_id' => $staff2->id,
            'date' => $date,
            'time' => '14:00',
        ])->assertCreated()->json('data.id');

        // Conflict when moving appt2 onto staff1 at 10:00
        $this->putJson("/api/provider/appointments/{$appt2}", [
            'staff_id' => $staff1->id,
            'date' => $date,
            'time' => '10:00',
        ])->assertStatus(409);

        // Moving appt2 onto staff2 at 15:00 succeeds
        $this->putJson("/api/provider/appointments/{$appt2}", [
            'staff_id' => $staff2->id,
            'date' => $date,
            'time' => '15:00',
            'note' => 'Saç yıkama dahil',
        ])->assertOk()
            ->assertJsonPath('data.start_time', '15:00')
            ->assertJsonPath('data.customer_note', 'Saç yıkama dahil');

        // Cross-provider update blocked with 404
        Sanctum::actingAs($otherProv);
        $this->putJson("/api/provider/appointments/{$appt1}", [
            'date' => $date,
            'time' => '16:00',
        ])->assertNotFound();
    }

    public function test_security_boundaries_across_customer_provider_and_admin_endpoints(): void
    {
        $svc = $this->seedCatalog();
        [$provA, $profileA] = $this->createVerifiedProvider($svc, 'venue');
        [$provB] = $this->createVerifiedProvider($svc, 'venue');
        $customer = $this->createCustomer(true);

        $staffA = ProviderStaff::create([
            'provider_profile_id' => $profileA->id,
            'first_name' => 'Caner',
            'last_name' => 'Yılmaz',
            'is_active' => true,
            'accepts_appointments' => true,
            'visible_to_customers' => true,
        ]);

        // Past appointment links customer -> provA
        Appointment::create([
            'customer_user_id' => $customer->id,
            'provider_user_id' => $provA->id,
            'status' => Appointment::STATUS_COMPLETED,
            'appointment_date' => now()->subDays(2)->format('Y-m-d'),
            'start_time' => '12:00:00',
            'end_time' => '12:30:00',
            'payment_method' => 'CASH',
            'total_price' => 350,
            'total_duration_minutes' => 30,
        ]);

        $dispatchA = NotificationDispatch::create([
            'reference_code' => 'DSP-PARITY-A',
            'provider_user_id' => $provA->id,
            'provider_profile_id' => $profileA->id,
            'notification_type' => NotificationDispatch::TYPE_NOTIFICATION_AD,
            'source_type' => 'NOTIFICATION_AD',
            'source_id' => 1,
            'title' => 'Kampanya A',
            'body' => 'Kampanya A metni',
            'pricing_mode' => NotificationDispatch::PRICING_PER_RECIPIENT,
            'unit_price' => 1.0,
            'total_cost' => 1.0,
            'targeted_count' => 1,
            'eligible_count' => 1,
            'attempted_count' => 1,
            'fcm_accepted_count' => 1,
            'failed_count' => 0,
            'skipped_count' => 0,
            'balance_source' => NotificationDispatch::SOURCE_PROMO,
            'captured_promo_amount' => 1.0,
            'captured_cash_amount' => 0.0,
            'status' => NotificationDispatch::STATUS_COMPLETED,
        ]);

        // 1. Customer cannot access Admin endpoints
        Sanctum::actingAs($customer);
        $this->getJson('/api/admin/notification-center/overview')->assertForbidden();

        // 2. Provider cannot see birth_date in customers or birthday-assistant
        Sanctum::actingAs($provA);
        $custJson = $this->getJson('/api/provider/customers')->assertOk()->getContent();
        $this->assertStringNotContainsString('birth_date', $custJson);
        $this->assertStringNotContainsString('1993-05-14', $custJson);
        $bdayJson = $this->getJson('/api/provider/birthday-assistant')->assertOk()->getContent();
        $this->assertStringNotContainsString('1993-05-14', $bdayJson);

        // 3. Provider B cannot modify Provider A's staff or read Provider A's dispatch
        Sanctum::actingAs($provB);
        $this->putJson("/api/provider/staff/{$staffA->id}", ['title' => 'Hack'])->assertNotFound();
        $this->getJson("/api/provider/notification-report/dispatches/{$dispatchA->id}")->assertForbidden();

        // 4. Restricted provider cannot send notification ads without permission
        ProviderNotificationControl::create([
            'provider_user_id' => $provB->id,
            'notification_ads_blocked' => true,
        ]);
        $this->postJson('/api/provider/notification-ads', [
            'audience' => 'past_customers',
            'title' => 'İndirim',
            'body' => 'Yüzde yirmi indirim fırsatı',
            'discount_percent' => 20,
            'discount_days' => 3,
        ])->assertUnprocessable();
    }
}
