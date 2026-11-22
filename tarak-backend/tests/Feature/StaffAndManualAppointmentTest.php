<?php

namespace Tests\Feature;

use App\Jobs\SendPushNotification;
use App\Models\Appointment;
use App\Models\CustomerAddress;
use App\Models\CustomerProfile;
use App\Models\ProviderClosedDate;
use App\Models\ProviderDocument;
use App\Models\ProviderProfile;
use App\Models\ProviderService;
use App\Models\ProviderStaff;
use App\Models\ProviderWeeklySchedule;
use App\Models\PushDevice;
use App\Models\Service;
use App\Models\ServiceCategory;
use App\Models\ServicePayment;
use App\Models\User;
use App\Models\UserNotification;
use App\Models\UserPushPreference;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Queue;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class StaffAndManualAppointmentTest extends TestCase
{
    use RefreshDatabase;

    protected function tearDown(): void
    {
        Carbon::setTestNow();
        parent::tearDown();
    }

    private function seedVerifiedSalon(): array
    {
        $cat = ServiceCategory::create([
            'id' => 'cat-sac-bakimi',
            'name' => 'Saç Bakımı',
            'slug' => 'sac-bakimi',
            'is_active' => true,
        ]);

        $cut = Service::create([
            'category_id' => $cat->id,
            'name' => 'Saç Kesimi',
            'slug' => 'sac-kesimi',
            'base_price' => 250,
            'duration_minutes' => 30,
            'is_active' => true,
        ]);

        $shave = Service::create([
            'category_id' => $cat->id,
            'name' => 'Sakal Tıraşı',
            'slug' => 'sakal-tirasi',
            'base_price' => 150,
            'duration_minutes' => 30,
            'is_active' => true,
        ]);

        $provider = User::create([
            'role' => User::ROLE_PROVIDER,
            'first_name' => 'Mehmet',
            'last_name' => 'Kuaför',
            'name' => 'Mehmet Kuaför',
            'email' => 'salon@test.local',
            'password' => 'password123',
            'status' => 'active',
        ]);

        $profile = ProviderProfile::create([
            'user_id' => $provider->id,
            'business_name' => 'Mehmet Erkek Kuaförü',
            'provider_type' => 'barber',
            'work_mode' => 'venue',
            'is_approved' => true,
            'identity_status' => 'APPROVED',
            'accepts_new_clients' => true,
            'city' => 'İstanbul',
            'district' => 'Şişli',
            'latitude' => 41.0637,
            'longitude' => 28.9831,
            'service_radius_km' => 20,
        ]);

        ProviderDocument::create([
            'provider_profile_id' => $profile->id,
            'document_type' => ProviderDocument::TYPE_MASTER_CERTIFICATE,
            'original_name' => 'master.pdf',
            'storage_path' => 'kyc/master.pdf',
            'mime_type' => 'application/pdf',
            'file_size' => 1024,
            'status' => ProviderDocument::STATUS_APPROVED,
        ]);

        foreach ([$cut, $shave] as $svc) {
            ProviderService::create([
                'provider_profile_id' => $profile->id,
                'service_id' => $svc->id,
                'custom_price' => $svc->base_price,
                'custom_duration_minutes' => $svc->duration_minutes,
                'is_active' => true,
            ]);
        }

        foreach (['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'] as $day) {
            $sched = ProviderWeeklySchedule::create([
                'provider_profile_id' => $profile->id,
                'day_of_week' => $day,
                'is_enabled' => true,
                'start_time' => '09:00',
                'end_time' => '18:00',
            ]);
            $sched->breaks()->create(['start_time' => '12:30', 'end_time' => '13:30']);
        }

        $c1 = $this->makeCustomer('cust1@test.local', 'Ali', 'Yılmaz');
        $c2 = $this->makeCustomer('cust2@test.local', 'Veli', 'Kaya');

        return compact('provider', 'profile', 'cut', 'shave', 'c1', 'c2');
    }

    private function makeCustomer(string $email, string $first, string $last): array
    {
        $user = User::create([
            'role' => User::ROLE_CUSTOMER,
            'first_name' => $first,
            'last_name' => $last,
            'name' => "{$first} {$last}",
            'email' => $email,
            'password' => 'password123',
            'status' => 'active',
        ]);
        $cp = CustomerProfile::create([
            'user_id' => $user->id,
            'profile_completed' => true,
        ]);
        $addr = CustomerAddress::create([
            'customer_profile_id' => $cp->id,
            'title' => 'Ev',
            'province' => 'İstanbul',
            'district' => 'Şişli',
            'latitude' => 41.0637,
            'longitude' => 28.9831,
            'is_default' => true,
        ]);
        return ['user' => $user, 'address' => $addr];
    }

    public function test_staff_crud_service_matching_conflicts_and_archive_preserve_history(): void
    {
        Queue::fake();
        $env = $this->seedVerifiedSalon();
        /** @var User $provider */
        $provider = $env['provider'];
        /** @var ProviderProfile $profile */
        $profile = $env['profile'];
        $cut = $env['cut'];
        $shave = $env['shave'];
        $c1 = $env['c1'];
        $c2 = $env['c2'];

        $targetDate = Carbon::tomorrow((string) config('app.timezone', 'Europe/Istanbul'))->format('Y-m-d');

        // 1. Provider creates Staff A (Ahmet, offers Cut=60m & Shave=30m) and Staff B (Burak, offers Cut only, off on breaks)
        Sanctum::actingAs($provider);

        $staffAResp = $this->postJson('/api/provider/staff', [
            'first_name' => 'Ahmet',
            'last_name' => 'Usta',
            'title' => 'Baş Berber',
            'specialty' => 'Klasik & Modern Kesim',
            'services' => [
                ['service_id' => $cut->id, 'custom_duration_minutes' => 60],
                ['service_id' => $shave->id, 'custom_duration_minutes' => 30],
            ],
        ])->assertCreated();
        $staffAId = $staffAResp->json('data.id');

        $staffBResp = $this->postJson('/api/provider/staff', [
            'first_name' => 'Burak',
            'last_name' => 'Stilist',
            'title' => 'Sakal Uzmanı',
            'services' => [
                ['service_id' => $cut->id, 'custom_duration_minutes' => 30],
            ],
        ])->assertCreated();
        $staffBId = $staffBResp->json('data.id');

        // Customer discovery filters staff strictly by service capability
        Sanctum::actingAs($c1['user']);
        $this->getJson("/api/customer/providers/{$provider->id}/staff?service_ids={$shave->id}")
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $staffAId);

        // 2. Booking same staff (Ahmet) at 10:00 (60 min duration) -> OK, then booking 10:30 for Ahmet -> 409 Conflict!
        $firstBook = $this->postJson('/api/customer/appointments', [
            'provider_id' => $provider->id,
            'staff_id' => $staffAId,
            'service_ids' => [$cut->id],
            'date' => $targetDate,
            'time' => '10:00',
            'customer_address_id' => $c1['address']->id,
        ])->assertCreated()
            ->assertJsonPath('data.staff_name', 'Ahmet Usta')
            ->assertJsonPath('data.staff_selection_mode', 'SPECIFIC');
        $firstApptId = (int) $firstBook->json('data.id');

        // Lunch break 12:30-13:30 blocked for 60m cut starting 12:00
        Sanctum::actingAs($c2['user']);
        $this->postJson('/api/customer/appointments', [
            'provider_id' => $provider->id,
            'staff_id' => $staffAId,
            'service_ids' => [$cut->id],
            'date' => $targetDate,
            'time' => '12:00',
            'customer_address_id' => $c2['address']->id,
        ])->assertStatus(409);

        // Same staff overlapping at 10:30 blocked (60m custom duration ends at 11:00)
        $this->postJson('/api/customer/appointments', [
            'provider_id' => $provider->id,
            'staff_id' => $staffAId,
            'service_ids' => [$cut->id],
            'date' => $targetDate,
            'time' => '10:30',
            'customer_address_id' => $c2['address']->id,
        ])->assertStatus(409);

        // Different staff (Burak) at exact same time 10:00 succeeds!
        $this->postJson('/api/customer/appointments', [
            'provider_id' => $provider->id,
            'staff_id' => $staffBId,
            'service_ids' => [$cut->id],
            'date' => $targetDate,
            'time' => '10:00',
            'customer_address_id' => $c2['address']->id,
        ])->assertCreated()
            ->assertJsonPath('data.staff_name', 'Burak Stilist');

        // 3. "Fark Etmez" (staff_id omitted) at 11:00 picks Ahmet (since Ahmet is free at 11:00 too) or Burak
        Sanctum::actingAs($c1['user']);
        $anyResp = $this->postJson('/api/customer/appointments', [
            'provider_id' => $provider->id,
            'service_ids' => [$cut->id],
            'date' => $targetDate,
            'time' => '15:00',
            'customer_address_id' => $c1['address']->id,
        ])->assertCreated()
            ->assertJsonPath('data.staff_selection_mode', 'ANY_AVAILABLE');
        $this->assertNotNull($anyResp->json('data.staff_id'));

        // Staff leave blocks that staff member on leave dates while shop remains open for others
        Sanctum::actingAs($provider);
        $leaveDate = Carbon::parse($targetDate)->addDays(2)->format('Y-m-d');
        $this->postJson("/api/provider/staff/{$staffAId}/time-offs", [
            'start_date' => $leaveDate,
            'end_date' => $leaveDate,
            'reason' => 'izin',
        ])->assertCreated();

        Sanctum::actingAs($c1['user']);
        $this->getJson("/api/customer/providers/{$provider->id}/availability?date={$leaveDate}&service_ids={$cut->id}&staff_id={$staffAId}")
            ->assertOk()
            ->assertJsonCount(0, 'data.available_slots');
        $this->getJson("/api/customer/providers/{$provider->id}/availability?date={$leaveDate}&service_ids={$cut->id}&staff_id={$staffBId}")
            ->assertOk()
            ->assertJsonStructure(['data' => ['available_slots' => [0 => ['start_time', 'end_time']]]]);

        // Shop closed date blocks everyone
        ProviderClosedDate::create([
            'provider_profile_id' => $profile->id,
            'date' => $leaveDate,
            'reason' => 'tatil',
        ]);
        $this->getJson("/api/customer/providers/{$provider->id}/availability?date={$leaveDate}&service_ids={$cut->id}&staff_id={$staffBId}")
            ->assertOk()
            ->assertJsonCount(0, 'data.available_slots');

        // 4. Archive Staff A -> hidden from new customers, past appointment preserves snapshot!
        Sanctum::actingAs($provider);
        $this->deleteJson("/api/provider/staff/{$staffAId}")->assertOk();

        $this->assertDatabaseHas('provider_staff', [
            'id' => $staffAId,
            'is_active' => false,
        ]);

        Sanctum::actingAs($c1['user']);
        $this->getJson("/api/customer/appointments/{$firstApptId}")
            ->assertOk()
            ->assertJsonPath('data.staff_name', 'Ahmet Usta');
    }

    public function test_manual_appointments_guest_no_push_staff_change_and_cancelled_reminders_suppressed(): void
    {
        Queue::fake();
        $env = $this->seedVerifiedSalon();
        /** @var User $provider */
        $provider = $env['provider'];
        $cut = $env['cut'];
        $c1 = $env['c1'];
        $stranger = $this->makeCustomer('stranger@test.local', 'Yabancı', 'Müşteri');

        $tz = (string) config('app.timezone', 'Europe/Istanbul');
        $tomorrow = Carbon::tomorrow($tz)->format('Y-m-d');

        Sanctum::actingAs($provider);
        $s1 = $this->postJson('/api/provider/staff', [
            'first_name' => 'Kemal',
            'last_name' => 'Usta',
            'services' => [['service_id' => $cut->id]],
        ])->assertCreated()->json('data.id');

        $s2 = $this->postJson('/api/provider/staff', [
            'first_name' => 'Emre',
            'last_name' => 'Berber',
            'services' => [['service_id' => $cut->id]],
        ])->assertCreated()->json('data.id');

        // Create an existing relationship between c1 and provider
        Appointment::create([
            'customer_user_id' => $c1['user']->id,
            'provider_user_id' => $provider->id,
            'status' => Appointment::STATUS_COMPLETED,
            'appointment_date' => Carbon::yesterday($tz)->format('Y-m-d'),
            'start_time' => '10:00:00',
            'end_time' => '10:30:00',
            'payment_method' => 'CASH',
            'total_price' => 250,
            'total_duration_minutes' => 30,
        ]);

        // Authorized customer list returns c1 ONLY (never stranger)
        $this->getJson('/api/provider/customers')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $c1['user']->id);

        // Unauthorized stranger rejected for manual booking
        $this->postJson('/api/provider/appointments', [
            'customer_mode' => 'registered',
            'customer_user_id' => $stranger['user']->id,
            'service_ids' => [$cut->id],
            'staff_id' => $s1,
            'date' => $tomorrow,
            'time' => '14:00',
        ])->assertStatus(403);

        // Authorized registered customer manual appointment -> CONFIRMED, NOT completed/paid, notifies customer
        $manualReg = $this->postJson('/api/provider/appointments', [
            'customer_mode' => 'registered',
            'customer_user_id' => $c1['user']->id,
            'service_ids' => [$cut->id],
            'staff_id' => $s1,
            'date' => $tomorrow,
            'time' => '15:00',
        ])->assertCreated()
            ->assertJsonPath('notification_sent', true)
            ->assertJsonPath('data.status', 'CONFIRMED')
            ->assertJsonPath('data.booking_source', 'PROVIDER_MANUAL')
            ->assertJsonPath('data.completed_at', null);

        $manualApptId = (int) $manualReg->json('data.id');
        $this->assertSame(0, ServicePayment::where('resource_id', $manualApptId)->count());
        $this->assertTrue(
            UserNotification::where('user_id', $c1['user']->id)
                ->where('type', UserNotification::TYPE_APPOINTMENT_CREATED_BY_PROVIDER)
                ->where('message', 'like', '%Kemal Usta%')
                ->exists()
        );

        // Double booking same staff at 15:00 fails with 409
        $this->postJson('/api/provider/appointments', [
            'customer_mode' => 'guest',
            'guest_customer_name' => 'Ahmet Misafir',
            'guest_customer_consent' => true,
            'service_ids' => [$cut->id],
            'staff_id' => $s1,
            'date' => $tomorrow,
            'time' => '15:00',
        ])->assertStatus(409);

        // Guest customer without consent rejected (422)
        $this->postJson('/api/provider/appointments', [
            'customer_mode' => 'guest',
            'guest_customer_name' => 'Ahmet Misafir',
            'guest_customer_consent' => false,
            'service_ids' => [$cut->id],
            'staff_id' => $s2,
            'date' => $tomorrow,
            'time' => '15:00',
        ])->assertStatus(422);

        $userCountBeforeGuest = User::count();
        $notifCountBeforeGuest = UserNotification::count();

        // Guest customer with consent succeeds WITHOUT creating User row or notification
        $guestResp = $this->postJson('/api/provider/appointments', [
            'customer_mode' => 'guest',
            'guest_customer_name' => 'Telefon Misafiri',
            'guest_customer_phone' => '+905551112233',
            'guest_customer_consent' => true,
            'service_ids' => [$cut->id],
            'staff_id' => $s2,
            'date' => $tomorrow,
            'time' => '15:00',
        ])->assertCreated()
            ->assertJsonPath('notification_sent', false)
            ->assertJsonPath('data.is_guest_customer', true)
            ->assertJsonPath('data.guest_customer_name', 'Telefon Misafiri');

        $this->assertSame($userCountBeforeGuest, User::count());
        $this->assertSame($notifCountBeforeGuest, UserNotification::count());
        $guestApptId = (int) $guestResp->json('data.id');

        // Reassigning manualAppt from Kemal (s1) to Emre (s2) at 15:00 fails (Emre has guest appt!) -> 409
        $this->postJson("/api/provider/appointments/{$manualApptId}/change-staff", [
            'staff_id' => $s2,
        ])->assertStatus(409);

        // Book s2 after guest cancels, or book another slot: cancel guest appt first then reassign
        $this->postJson("/api/provider/appointments/{$guestApptId}/cancel")->assertOk();
        $this->postJson("/api/provider/appointments/{$manualApptId}/change-staff", [
            'staff_id' => $s2,
        ])->assertOk()->assertJsonPath('data.staff_name', 'Emre Berber');

        $this->assertTrue(
            UserNotification::where('user_id', $c1['user']->id)
                ->where('type', UserNotification::TYPE_APPOINTMENT_STAFF_CHANGED)
                ->where('message', 'like', '%Emre Berber%')
                ->exists()
        );

        // Staff name included in customer reminder
        Carbon::setTestNow(Carbon::parse("{$tomorrow} 14:35:00", $tz));
        Artisan::call('appointments:send-reminders');
        $rem = UserNotification::where('user_id', $c1['user']->id)
            ->where('type', UserNotification::TYPE_APPOINTMENT_REMINDER)
            ->firstOrFail();
        $this->assertStringContainsString('Emre Berber', $rem->message);
        $this->assertStringContainsString('Mehmet Erkek Kuaförü', $rem->message);

        // Cancel manualAppt after reminder was already queued: SendPushNotification MUST skip FCM!
        Appointment::whereKey($manualApptId)->update(['status' => Appointment::STATUS_CANCELLED]);
        PushDevice::create([
            'user_id' => $c1['user']->id,
            'platform' => 'ANDROID',
            'token_hash' => hash('sha256', 'tok'),
            'token_encrypted' => 'tok',
            'status' => PushDevice::STATUS_ACTIVE,
            'last_registered_at' => now(),
        ]);
        Http::fake();
        config(['services.fcm.project_id' => 'demo', 'services.fcm.client_email' => 'a@b.c', 'services.fcm.private_key' => 'k']);
        (new SendPushNotification($rem->id))->handle(app(\App\Services\FcmPushService::class));
        Http::assertNothingSent();
    }

    public function test_legacy_salon_without_staff_remains_backward_compatible(): void
    {
        Queue::fake();
        $env = $this->seedVerifiedSalon();
        $provider = $env['provider'];
        $cut = $env['cut'];
        $c1 = $env['c1'];
        $c2 = $env['c2'];
        $tomorrow = Carbon::tomorrow((string) config('app.timezone', 'Europe/Istanbul'))->format('Y-m-d');

        Sanctum::actingAs($c1['user']);
        $this->getJson("/api/customer/providers/{$provider->id}/staff")
            ->assertOk()
            ->assertJsonCount(0, 'data');

        $this->postJson('/api/customer/appointments', [
            'provider_id' => $provider->id,
            'service_ids' => [$cut->id],
            'date' => $tomorrow,
            'time' => '11:00',
            'customer_address_id' => $c1['address']->id,
        ])->assertCreated()
            ->assertJsonPath('data.staff_selection_mode', 'LEGACY')
            ->assertJsonPath('data.staff_id', null);

        // Legacy single-calendar salon blocks second booking at 11:00
        Sanctum::actingAs($c2['user']);
        $this->postJson('/api/customer/appointments', [
            'provider_id' => $provider->id,
            'service_ids' => [$cut->id],
            'date' => $tomorrow,
            'time' => '11:00',
            'customer_address_id' => $c2['address']->id,
        ])->assertStatus(409);
    }
}
