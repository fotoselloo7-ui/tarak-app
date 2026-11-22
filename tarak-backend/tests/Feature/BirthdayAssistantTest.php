<?php

namespace Tests\Feature;

use App\Jobs\SendPushNotification;
use App\Models\Appointment;
use App\Models\BirthdayGreetingDelivery;
use App\Models\CustomerProfile;
use App\Models\ProviderBirthdaySetting;
use App\Models\ProviderProfile;
use App\Models\PushDevice;
use App\Models\ServiceRequest;
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

class BirthdayAssistantTest extends TestCase
{
    use RefreshDatabase;

    protected function tearDown(): void
    {
        Carbon::setTestNow();
        parent::tearDown();
    }

    private function makeSalon(string $email, string $bizName): array
    {
        $user = User::create([
            'role' => User::ROLE_PROVIDER,
            'first_name' => 'Salon',
            'last_name' => 'Sahibi',
            'name' => $bizName,
            'email' => $email,
            'password' => 'password123',
            'status' => 'active',
        ]);
        $profile = ProviderProfile::create([
            'user_id' => $user->id,
            'business_name' => $bizName,
            'provider_type' => 'barber',
            'work_mode' => 'venue',
            'is_approved' => true,
            'identity_status' => 'APPROVED',
        ]);
        return ['user' => $user, 'profile' => $profile];
    }

    private function makeCustomer(string $email, string $firstName, ?string $birthDate, bool $birthdayOptIn = true): User
    {
        $user = User::create([
            'role' => User::ROLE_CUSTOMER,
            'first_name' => $firstName,
            'last_name' => 'Test',
            'name' => "{$firstName} Test",
            'email' => $email,
            'password' => 'password123',
            'status' => 'active',
        ]);
        CustomerProfile::create([
            'user_id' => $user->id,
            'profile_completed' => true,
            'birth_date' => $birthDate,
        ]);
        // Explicitly enable push + campaign to verify birthday_greeting_enabled stays INDEPENDENT!
        UserPushPreference::create([
            'user_id' => $user->id,
            'push_enabled' => true,
            'campaign_enabled' => true,
            'birthday_greeting_enabled' => $birthdayOptIn,
        ]);
        return $user;
    }

    public function test_birthday_opt_in_is_separate_from_push_and_campaign_and_birth_dates_are_not_leaked(): void
    {
        $salon = $this->makeSalon('bday-salon@test.local', 'Mehmet Erkek Kuaförü');
        $cust = $this->makeCustomer('ayse@test.local', 'Ayşe', '1995-05-10', false);

        Appointment::create([
            'customer_user_id' => $cust->id,
            'provider_user_id' => $salon['user']->id,
            'status' => Appointment::STATUS_COMPLETED,
            'appointment_date' => '2026-04-01',
            'start_time' => '11:00:00',
            'end_time' => '11:30:00',
            'payment_method' => 'CASH',
            'total_price' => 250,
            'total_duration_minutes' => 30,
        ]);

        // Even with push_enabled & campaign_enabled true, birthday_greeting_enabled defaults/stays false
        Sanctum::actingAs($cust);
        $this->getJson('/api/push/preferences')
            ->assertOk()
            ->assertJsonPath('push_enabled', true)
            ->assertJsonPath('campaign_enabled', true)
            ->assertJsonPath('birthday_greeting_enabled', false);

        // Provider response MUST NOT contain customer birth dates or individual customer names
        Sanctum::actingAs($salon['user']);
        $resp = $this->getJson('/api/provider/birthday-assistant')
            ->assertOk()
            ->assertJsonPath('data.eligible_customer_count', 0);

        $json = json_encode($resp->json());
        $this->assertStringNotContainsString('1995-05-10', $json);
        $this->assertStringNotContainsString('Ayşe', $json);

        // Customer opts in -> eligible_customer_count increments to 1, still no birth_date leak
        Sanctum::actingAs($cust);
        $this->putJson('/api/push/preferences', ['birthday_greeting_enabled' => true])
            ->assertOk()
            ->assertJsonPath('birthday_greeting_enabled', true);

        Sanctum::actingAs($salon['user']);
        $resp2 = $this->getJson('/api/provider/birthday-assistant')
            ->assertOk()
            ->assertJsonPath('data.eligible_customer_count', 1);
        $this->assertStringNotContainsString('1995-05-10', json_encode($resp2->json()));
    }

    public function test_birthday_delivery_offsets_idempotency_audience_isolation_leap_year_and_rollover(): void
    {
        Queue::fake();
        $tz = (string) config('app.timezone', 'Europe/Istanbul');

        $salonA = $this->makeSalon('salon-a@test.local', 'Mehmet Erkek Kuaförü');
        $salonB = $this->makeSalon('salon-b@test.local', 'Başka Kuaför');

        // Opted-in customer of Salon A (birthday Nov 25)
        $ayse = $this->makeCustomer('ayse2@test.local', 'Ayşe', '1994-11-25', true);
        // Opted-out customer of Salon A (birthday Nov 25, push & campaign true!)
        $noOpt = $this->makeCustomer('noopt@test.local', 'Can', '1994-11-25', false);
        // Opted-in customer ONLY of Salon B (must NOT be targeted by Salon A!)
        $otherSalonCust = $this->makeCustomer('other@test.local', 'Deniz', '1994-11-25', true);
        // Pending-only customer of Salon A (not completed -> must NOT be targeted)
        $pendingOnly = $this->makeCustomer('pending@test.local', 'Bora', '1994-11-25', true);
        // Leap day customer (Feb 29) & New Year rollover customer (Jan 1)
        $leapCust = $this->makeCustomer('leap@test.local', 'Ece', '2000-02-29', true);
        $janCust = $this->makeCustomer('jan@test.local', 'Kaan', '1992-01-01', true);

        foreach ([$ayse, $noOpt, $leapCust, $janCust] as $cust) {
            Appointment::create([
                'customer_user_id' => $cust->id,
                'provider_user_id' => $salonA['user']->id,
                'status' => Appointment::STATUS_COMPLETED,
                'appointment_date' => '2026-10-10',
                'start_time' => '10:00:00',
                'end_time' => '10:30:00',
                'payment_method' => 'CASH',
                'total_price' => 200,
                'total_duration_minutes' => 30,
            ]);
        }

        // Completed instant service request also establishes Salon B relationship cleanly
        ServiceRequest::create([
            'customer_user_id' => $otherSalonCust->id,
            'category_id' => 1,
            'status' => ServiceRequest::STATUS_COMPLETED,
            'assigned_provider_user_id' => $salonB['user']->id,
        ]);

        // Pending appointment must NOT make Bora eligible for Salon A
        Appointment::create([
            'customer_user_id' => $pendingOnly->id,
            'provider_user_id' => $salonA['user']->id,
            'status' => Appointment::STATUS_PENDING,
            'appointment_date' => '2026-11-28',
            'start_time' => '10:00:00',
            'end_time' => '10:30:00',
            'payment_method' => 'CASH',
            'total_price' => 200,
            'total_duration_minutes' => 30,
        ]);

        ProviderBirthdaySetting::create([
            'provider_profile_id' => $salonA['profile']->id,
            'is_enabled' => true,
            'send_on_birthday' => true,
            'send_one_day_before' => true,
            'send_two_days_before' => false,
            'send_time' => '10:00',
            'template_key' => 'classic',
        ]);

        // Before send_time (09:59 on 2026-11-24 = 1 day before): nothing sent yet
        Carbon::setTestNow(Carbon::parse('2026-11-24 09:59:00', $tz));
        Artisan::call('birthdays:send-greetings');
        $this->assertSame(0, BirthdayGreetingDelivery::count());

        // At 10:00 on 2026-11-24 (1 day before Ayşe's birthday): ONLY Ayşe gets 1 notification
        Carbon::setTestNow(Carbon::parse('2026-11-24 10:00:00', $tz));
        Artisan::call('birthdays:send-greetings');

        $this->assertSame(1, UserNotification::where('type', UserNotification::TYPE_BIRTHDAY_GREETING)->count());
        $ayseNotif = UserNotification::where('user_id', $ayse->id)->firstOrFail();
        $this->assertStringContainsString('Ayşe', $ayseNotif->title);
        $this->assertStringContainsString('Mehmet Erkek Kuaförü', $ayseNotif->message);
        $this->assertSame(0, UserNotification::where('user_id', $noOpt->id)->count());
        $this->assertSame(0, UserNotification::where('user_id', $otherSalonCust->id)->count());
        $this->assertSame(0, UserNotification::where('user_id', $pendingOnly->id)->count());

        // On exact birthday (2026-11-25 10:00): idempotent -> NO duplicate greeting for 2026!
        Carbon::setTestNow(Carbon::parse('2026-11-25 10:00:00', $tz));
        Artisan::call('birthdays:send-greetings');
        $this->assertSame(1, UserNotification::where('user_id', $ayse->id)->where('type', UserNotification::TYPE_BIRTHDAY_GREETING)->count());

        // Year rollover test: 2026-12-31 -> 1 day before Jan 1 (2027) -> Kaan receives greeting!
        Carbon::setTestNow(Carbon::parse('2026-12-31 10:05:00', $tz));
        Artisan::call('birthdays:send-greetings');
        $this->assertSame(1, UserNotification::where('user_id', $kaan = $janCust->id)->where('type', UserNotification::TYPE_BIRTHDAY_GREETING)->count());

        // Non-leap year (2027) Feb 28: Ece (Feb 29) celebrates on Feb 28; leap year (2028) Feb 29: celebrates on Feb 29
        Carbon::setTestNow(Carbon::parse('2027-02-28 10:00:00', $tz));
        Artisan::call('birthdays:send-greetings');
        $this->assertSame(1, BirthdayGreetingDelivery::where('customer_user_id', $leapCust->id)->where('birthday_year', 2027)->count());

        // Switch 1-day-before OFF for 2028 check so Ece celebrates strictly on Feb 29 in leap year 2028
        ProviderBirthdaySetting::where('provider_profile_id', $salonA['profile']->id)
            ->update(['send_one_day_before' => false]);
        Carbon::setTestNow(Carbon::parse('2028-02-28 10:00:00', $tz));
        Artisan::call('birthdays:send-greetings');
        $this->assertSame(0, BirthdayGreetingDelivery::where('customer_user_id', $leapCust->id)->where('birthday_year', 2028)->count());

        Carbon::setTestNow(Carbon::parse('2028-02-29 10:00:00', $tz));
        Artisan::call('birthdays:send-greetings');
        $this->assertSame(1, BirthdayGreetingDelivery::where('customer_user_id', $leapCust->id)->where('birthday_year', 2028)->count());

        // Disabling birthday opt-in before queued push execution suppresses FCM call
        UserPushPreference::where('user_id', $ayse->id)->update(['birthday_greeting_enabled' => false]);
        PushDevice::create([
            'user_id' => $ayse->id,
            'platform' => 'ANDROID',
            'token_hash' => hash('sha256', 'tok2'),
            'token_encrypted' => 'tok2',
            'status' => PushDevice::STATUS_ACTIVE,
            'last_registered_at' => now(),
        ]);
        Http::fake();
        config(['services.fcm.project_id' => 'demo', 'services.fcm.client_email' => 'a@b.c', 'services.fcm.private_key' => 'k']);
        (new SendPushNotification($ayseNotif->id))->handle(app(\App\Services\FcmPushService::class));
        Http::assertNothingSent();
    }
}
