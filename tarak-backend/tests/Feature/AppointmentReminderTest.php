<?php

namespace Tests\Feature;

use App\Models\Appointment;
use App\Models\User;
use App\Models\UserNotification;
use App\Models\UserPushPreference;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Queue;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AppointmentReminderTest extends TestCase
{
    use RefreshDatabase;

    protected function tearDown(): void
    {
        Carbon::setTestNow();
        parent::tearDown();
    }

    public function test_push_preferences_endpoint_supports_reminder_minutes_and_start_alert(): void
    {
        $provider = $this->makeUser(User::ROLE_PROVIDER, 'berber@example.test', 'Usta Berberoğlu');

        Sanctum::actingAs($provider);

        // 1. Defaults when no preference row exists yet
        $this->getJson('/api/push/preferences')
            ->assertOk()
            ->assertJson([
                'push_enabled' => true,
                'campaign_enabled' => true,
                'appointment_reminder_enabled' => true,
                'appointment_reminder_minutes' => 30,
                'appointment_start_alert_enabled' => true,
            ]);

        // 2. Partial update of custom reminder minutes & start alert
        $this->putJson('/api/push/preferences', [
            'appointment_reminder_minutes' => 45,
            'appointment_start_alert_enabled' => false,
        ])
            ->assertOk()
            ->assertJson([
                'push_enabled' => true,
                'campaign_enabled' => true,
                'appointment_reminder_enabled' => true,
                'appointment_reminder_minutes' => 45,
                'appointment_start_alert_enabled' => false,
            ]);

        // 3. Partial single-field update remains valid and preserves reminder config
        $this->putJson('/api/push/preferences', ['push_enabled' => false])
            ->assertOk()
            ->assertJson([
                'push_enabled' => false,
                'appointment_reminder_minutes' => 45,
                'appointment_start_alert_enabled' => false,
            ]);

        // 4. Out-of-range minutes and empty payloads are rejected cleanly
        $this->putJson('/api/push/preferences', ['appointment_reminder_minutes' => 3])
            ->assertStatus(422);
        $this->putJson('/api/push/preferences', ['appointment_reminder_minutes' => 1500])
            ->assertStatus(422);
        $this->putJson('/api/push/preferences', [])
            ->assertStatus(422);
    }

    public function test_command_sends_custom_minute_reminders_to_provider_and_customer_and_exact_start_alert(): void
    {
        Queue::fake();

        $tz = (string) config('app.timezone', 'Europe/Istanbul');
        $provider = $this->makeUser(User::ROLE_PROVIDER, 'provider@example.test', 'Ahmet Usta');
        $provider->providerProfile()->create([
            'business_name' => 'Altın Makas Berber',
            'provider_type' => 'barber',
            'work_mode' => 'venue',
            'is_approved' => true,
            'identity_status' => 'APPROVED',
        ]);
        $customer = $this->makeUser(User::ROLE_CUSTOMER, 'musteri@example.test', 'Mehmet Demir');

        UserPushPreference::create([
            'user_id' => $provider->id,
            'push_enabled' => true,
            'appointment_reminder_enabled' => true,
            'appointment_reminder_minutes' => 45,
            'appointment_start_alert_enabled' => false,
        ]);
        UserPushPreference::create([
            'user_id' => $customer->id,
            'push_enabled' => true,
            'appointment_reminder_enabled' => true,
            'appointment_reminder_minutes' => 20,
            'appointment_start_alert_enabled' => true,
        ]);

        // Confirmed appointment today at 14:30
        $dateStr = '2026-11-22';
        $confirmed = Appointment::create([
            'customer_user_id' => $customer->id,
            'provider_user_id' => $provider->id,
            'status' => Appointment::STATUS_CONFIRMED,
            'appointment_date' => $dateStr,
            'start_time' => '14:30:00',
            'end_time' => '15:15:00',
            'payment_method' => 'cash',
            'total_price' => 350,
            'total_duration_minutes' => 45,
        ]);

        // Pending appointment must never trigger reminders
        Appointment::create([
            'customer_user_id' => $customer->id,
            'provider_user_id' => $provider->id,
            'status' => Appointment::STATUS_PENDING,
            'appointment_date' => $dateStr,
            'start_time' => '14:30:00',
            'end_time' => '15:15:00',
            'payment_method' => 'cash',
            'total_price' => 350,
            'total_duration_minutes' => 45,
        ]);

        // T = 13:40 (50 minutes before): neither provider (45 dk) nor customer (20 dk) should notify yet
        Carbon::setTestNow(Carbon::parse("{$dateStr} 13:40:00", $tz));
        Artisan::call('appointments:send-reminders');
        $this->assertSame(0, UserNotification::count());

        // T = 13:45 (45 minutes before): provider gets reminder, customer waits until 20 min before
        Carbon::setTestNow(Carbon::parse("{$dateStr} 13:45:00", $tz));
        Artisan::call('appointments:send-reminders');
        $this->assertSame(1, UserNotification::where('user_id', $provider->id)->count());
        $this->assertSame(0, UserNotification::where('user_id', $customer->id)->count());

        $providerNotif = UserNotification::where('user_id', $provider->id)->firstOrFail();
        $this->assertSame(UserNotification::TYPE_APPOINTMENT_REMINDER, $providerNotif->type);
        $this->assertStringContainsString('14:30', $providerNotif->message);
        $this->assertStringContainsString('45 dakika', $providerNotif->message);

        // Running again must remain idempotent for provider
        Artisan::call('appointments:send-reminders');
        $this->assertSame(1, UserNotification::where('user_id', $provider->id)->count());

        // T = 14:10 (20 minutes before): customer receives approaching reminder with business name & time
        Carbon::setTestNow(Carbon::parse("{$dateStr} 14:10:00", $tz));
        Artisan::call('appointments:send-reminders');
        $this->assertSame(1, UserNotification::where('user_id', $customer->id)->count());
        $custApproaching = UserNotification::where('user_id', $customer->id)->firstOrFail();
        $this->assertStringContainsString('Altın Makas Berber', $custApproaching->message);
        $this->assertStringContainsString('14:30', $custApproaching->message);

        // T = 14:30 (exact appointment time): customer receives exact-time notification naming business & time
        Carbon::setTestNow(Carbon::parse("{$dateStr} 14:30:00", $tz));
        Artisan::call('appointments:send-reminders');
        $custNotifs = UserNotification::where('user_id', $customer->id)->orderBy('id')->get();
        $this->assertCount(2, $custNotifs);
        $startNotif = $custNotifs->last();
        $this->assertSame('Randevu Saatiniz Geldi', $startNotif->title);
        $this->assertStringContainsString('Altın Makas Berber', $startNotif->message);
        $this->assertStringContainsString('14:30', $startNotif->message);
        $this->assertSame((string) $confirmed->id, $startNotif->resource_id);
    }

    public function test_disabled_reminder_or_start_alert_flags_suppress_notifications(): void
    {
        Queue::fake();

        $tz = (string) config('app.timezone', 'Europe/Istanbul');
        $provider = $this->makeUser(User::ROLE_PROVIDER, 'p2@example.test', 'Berber Can');
        $provider->providerProfile()->create([
            'business_name' => 'Can Kuaför',
            'provider_type' => 'barber',
            'work_mode' => 'venue',
            'is_approved' => true,
            'identity_status' => 'APPROVED',
        ]);
        $customer = $this->makeUser(User::ROLE_CUSTOMER, 'c2@example.test', 'Ayşe Yılmaz');

        UserPushPreference::create([
            'user_id' => $provider->id,
            'push_enabled' => true,
            'appointment_reminder_enabled' => false,
            'appointment_reminder_minutes' => 30,
            'appointment_start_alert_enabled' => false,
        ]);
        UserPushPreference::create([
            'user_id' => $customer->id,
            'push_enabled' => true,
            'appointment_reminder_enabled' => true,
            'appointment_reminder_minutes' => 30,
            'appointment_start_alert_enabled' => false,
        ]);

        Appointment::create([
            'customer_user_id' => $customer->id,
            'provider_user_id' => $provider->id,
            'status' => Appointment::STATUS_CONFIRMED,
            'appointment_date' => '2026-11-22',
            'start_time' => '16:00:00',
            'end_time' => '16:45:00',
            'payment_method' => 'cash',
            'total_price' => 300,
            'total_duration_minutes' => 45,
        ]);

        Carbon::setTestNow(Carbon::parse('2026-11-22 15:40:00', $tz));
        Artisan::call('appointments:send-reminders');
        $this->assertSame(0, UserNotification::where('user_id', $provider->id)->count());
        $this->assertSame(1, UserNotification::where('user_id', $customer->id)->count());

        Carbon::setTestNow(Carbon::parse('2026-11-22 16:00:00', $tz));
        Artisan::call('appointments:send-reminders');
        // Exact-time alert suppressed because appointment_start_alert_enabled is false
        $this->assertSame(1, UserNotification::where('user_id', $customer->id)->count());
    }

    private function makeUser(string $role, string $email, string $name): User
    {
        return User::create([
            'role' => $role,
            'first_name' => $name,
            'last_name' => 'Test',
            'name' => $name,
            'email' => $email,
            'password' => 'password123',
            'status' => 'active',
        ]);
    }
}
