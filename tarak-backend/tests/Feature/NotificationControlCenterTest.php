<?php

namespace Tests\Feature;

use App\Jobs\DeliverNotificationAd;
use App\Jobs\SendPushNotification;
use App\Models\AdminLog;
use App\Models\Appointment;
use App\Models\BirthdayGreetingDelivery;
use App\Models\CustomerProfile;
use App\Models\FinanceSetting;
use App\Models\NotificationAbuseAlert;
use App\Models\NotificationAd;
use App\Models\NotificationAdSetting;
use App\Models\NotificationDispatch;
use App\Models\NotificationDispatchRecipient;
use App\Models\ProviderBirthdaySetting;
use App\Models\ProviderNotificationControl;
use App\Models\ProviderProfile;
use App\Models\PushDeliveryAttempt;
use App\Models\PushDevice;
use App\Models\User;
use App\Models\UserNotification;
use App\Models\UserPushPreference;
use App\Models\Wallet;
use App\Models\WalletTransaction;
use App\Services\FcmPushService;
use App\Services\FinancialService;
use App\Services\NotificationAdService;
use App\Services\NotificationBillingService;
use App\Services\NotificationService;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Queue;
use Illuminate\Validation\ValidationException;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class NotificationControlCenterTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        config(['fcm.enabled' => true, 'fcm.project_id' => 'tarak-test-fcm']);
        FcmPushService::resolveAccessTokenUsing(fn () => 'test-access-token');
    }

    protected function tearDown(): void
    {
        Carbon::setTestNow();
        FcmPushService::resolveAccessTokenUsing(null);
        parent::tearDown();
    }

    private function makeAdmin(string $email = 'admin-ctrl@test.local'): User
    {
        return User::create([
            'role' => User::ROLE_ADMIN,
            'first_name' => 'Admin',
            'last_name' => 'Tarak',
            'name' => 'Admin Tarak',
            'email' => $email,
            'password' => 'password123',
            'status' => 'active',
        ]);
    }

    private function makeApprovedProvider(string $email, string $bizName, float $promo = 500.00, float $cash = 0.00): array
    {
        $user = User::create([
            'role' => User::ROLE_PROVIDER,
            'first_name' => 'Usta',
            'last_name' => 'Berber',
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
            'city' => 'İstanbul',
            'district' => 'Şişli',
            'is_approved' => true,
            'identity_status' => 'APPROVED',
            'accepts_new_clients' => true,
        ]);
        \App\Models\ProviderDocument::create([
            'provider_profile_id' => $profile->id,
            'document_type' => \App\Models\ProviderDocument::TYPE_MASTER_CERTIFICATE,
            'original_name' => 'ustalik.pdf',
            'storage_path' => 'provider-docs/test.pdf',
            'mime_type' => 'application/pdf',
            'file_size' => 1024,
            'status' => \App\Models\ProviderDocument::STATUS_APPROVED,
        ]);
        $wallet = Wallet::create([
            'user_id' => $user->id,
            'balance' => $cash,
            'promo_balance' => $promo,
            'reserved_cash_balance' => 0,
            'reserved_promo_balance' => 0,
            'currency' => 'TRY',
            'is_frozen' => false,
        ]);
        if ($promo > 0) {
            WalletTransaction::create([
                'wallet_id' => $wallet->id,
                'user_id' => $user->id,
                'type' => WalletTransaction::TYPE_WELCOME_PROMO_CREDIT,
                'direction' => WalletTransaction::DIRECTION_CREDIT,
                'bucket' => WalletTransaction::BUCKET_PROMO,
                'amount' => FinancialService::formatFromCents(FinancialService::parseToCents($promo)),
                'reference_type' => 'USER',
                'reference_id' => $user->id,
                'idempotency_key' => "WELCOME_BONUS:{$user->id}",
                'description' => 'Hoş geldin promosyon bakiyesi',
            ]);
        }

        return ['user' => $user, 'profile' => $profile, 'wallet' => $wallet];
    }

    private function makeCustomerWithCompletedVisit(
        User $providerUser,
        string $email,
        string $firstName,
        string $birthDate = '1994-11-22',
        bool $birthdayOptIn = true,
        bool $campaignOptIn = true,
        int $devices = 1
    ): User {
        $cust = User::create([
            'role' => User::ROLE_CUSTOMER,
            'first_name' => $firstName,
            'last_name' => 'Müşteri',
            'name' => "{$firstName} Müşteri",
            'email' => $email,
            'password' => 'password123',
            'status' => 'active',
        ]);
        CustomerProfile::create([
            'user_id' => $cust->id,
            'profile_completed' => true,
            'birth_date' => $birthDate,
        ]);
        UserPushPreference::create([
            'user_id' => $cust->id,
            'push_enabled' => true,
            'campaign_enabled' => $campaignOptIn,
            'birthday_greeting_enabled' => $birthdayOptIn,
        ]);
        Appointment::create([
            'customer_user_id' => $cust->id,
            'provider_user_id' => $providerUser->id,
            'status' => Appointment::STATUS_COMPLETED,
            'appointment_date' => '2026-10-15',
            'start_time' => '11:00:00',
            'end_time' => '11:30:00',
            'payment_method' => 'CASH',
            'total_price' => 300,
            'total_duration_minutes' => 30,
        ]);
        for ($i = 1; $i <= $devices; $i++) {
            PushDevice::create([
                'user_id' => $cust->id,
                'platform' => $i === 1 ? 'ANDROID' : 'IOS',
                'token_hash' => hash('sha256', "{$email}-tok-{$i}"),
                'token_encrypted' => "{$email}-raw-fcm-secret-token-{$i}",
                'status' => PushDevice::STATUS_ACTIVE,
                'last_registered_at' => now(),
            ]);
        }

        return $cust;
    }

    public function test_welcome_promo_pays_birthday_notifications_commission_free_stays_independent_and_multi_device_charges_once(): void
    {
        Http::fake(['fcm.googleapis.com/*' => Http::response(['name' => 'projects/p/messages/1'], 200)]);
        $tz = (string) config('app.timezone', 'Europe/Istanbul');
        Carbon::setTestNow(Carbon::parse('2026-11-22 10:05:00', $tz));

        $admin = $this->makeAdmin();
        // Zero commission does NOT make notifications free
        $salon = $this->makeApprovedProvider('zero-comm@test.local', 'Sıfır Komisyon Berber', 500.00, 0.00);
        $salon['profile']->update(['commission_rate_override' => 0.00]);

        ProviderBirthdaySetting::create([
            'provider_profile_id' => $salon['profile']->id,
            'is_enabled' => true,
            'send_on_birthday' => true,
            'send_time' => '10:00',
            'template_key' => 'classic',
        ]);

        // Admin configures 1.50 TL per birthday recipient
        Sanctum::actingAs($admin);
        $this->putJson('/api/admin/notification-center/settings', [
            'birthday_unit_price' => 1.50,
            'allow_promo_for_birthday' => true,
            'fallback_to_cash_when_promo_insufficient' => true,
        ])->assertOk()->assertJsonPath('data.birthday_unit_price', 1.5);

        // Customer has TWO active devices (Android + iOS) -> must only charge ONCE (1.50 TL total)!
        $cust = $this->makeCustomerWithCompletedVisit($salon['user'], 'dual@test.local', 'Merve', '1994-11-22', true, true, 2);

        Artisan::call('birthdays:send-greetings');

        $wallet = Wallet::where('user_id', $salon['user']->id)->firstOrFail();
        $this->assertSame('498.50', $wallet->promo_balance);
        $this->assertSame('0.00', $wallet->reserved_promo_balance);
        $this->assertSame('0.00', $wallet->balance);
        $this->assertSame(2, PushDeliveryAttempt::where('status', PushDeliveryAttempt::STATUS_SENT)->count());

        // Calling artisan + SendPushNotification + capture again never double-charges!
        Artisan::call('birthdays:send-greetings');
        $recipient = NotificationDispatchRecipient::firstOrFail();
        (new SendPushNotification($recipient->user_notification_id))->handle(app(FcmPushService::class));
        $this->assertFalse(app(NotificationBillingService::class)->captureRecipientReservation($recipient));

        $wallet->refresh();
        $this->assertSame('498.50', $wallet->promo_balance);
        $this->assertSame(1, WalletTransaction::where('user_id', $salon['user']->id)
            ->where('type', WalletTransaction::TYPE_BIRTHDAY_NOTIFICATION_PURCHASE)
            ->count());
    }

    public function test_promo_fallback_to_cash_promo_disabled_price_snapshot_isolation_and_failure_refund(): void
    {
        $tz = (string) config('app.timezone', 'Europe/Istanbul');
        Carbon::setTestNow(Carbon::parse('2026-11-22 10:05:00', $tz));

        $admin = $this->makeAdmin();
        // Provider starts with 0.50 promo + 20.00 cash
        $salon = $this->makeApprovedProvider('mixed@test.local', 'Karma Bakiye Kuaför', 0.50, 20.00);
        ProviderBirthdaySetting::create([
            'provider_profile_id' => $salon['profile']->id,
            'is_enabled' => true,
            'send_on_birthday' => true,
            'send_time' => '10:00',
        ]);

        // 1. Price = 1.00 TL, fallback = false -> insufficient promo (0.50 < 1.00), so skipped without cash spend
        Sanctum::actingAs($admin);
        $this->putJson('/api/admin/notification-center/settings', [
            'birthday_unit_price' => 1.00,
            'allow_promo_for_birthday' => true,
            'fallback_to_cash_when_promo_insufficient' => false,
        ])->assertOk();

        $cust1 = $this->makeCustomerWithCompletedVisit($salon['user'], 'c1@test.local', 'Ali', '1990-11-22');
        Artisan::call('birthdays:send-greetings');
        $this->assertSame(0, BirthdayGreetingDelivery::where('customer_user_id', $cust1->id)->count());

        // 2. Enable fallback to cash -> sends and splits 0.50 promo + 0.50 cash
        $fcmMode = 'ok';
        Http::fake([
            'fcm.googleapis.com/*' => function () use (&$fcmMode) {
                return $fcmMode === 'unregistered'
                    ? Http::response(['error' => ['status' => 'UNREGISTERED', 'message' => 'Requested entity was not found.']], 404)
                    : Http::response(['name' => 'projects/p/messages/2'], 200);
            },
        ]);
        Sanctum::actingAs($admin);
        $this->putJson('/api/admin/notification-center/settings', [
            'fallback_to_cash_when_promo_insufficient' => true,
        ])->assertOk();

        Artisan::call('birthdays:send-greetings');
        $wallet = Wallet::where('user_id', $salon['user']->id)->firstOrFail();
        $this->assertSame('0.00', $wallet->promo_balance);
        $this->assertSame('19.50', $wallet->balance);
        $delivery1 = BirthdayGreetingDelivery::where('customer_user_id', $cust1->id)->firstOrFail();
        $this->assertSame('1.00', $delivery1->unit_price);
        $this->assertSame('1.00', $delivery1->charged_amount);

        // 3. Admin disables promo & changes unit price to 5.00 -> old delivery STAYS 1.00, new uses cash 5.00
        $salon['wallet']->update(['promo_balance' => '100.00']);
        Sanctum::actingAs($admin);
        $this->putJson('/api/admin/notification-center/settings', [
            'birthday_unit_price' => 5.00,
            'allow_promo_for_birthday' => false,
        ])->assertOk();

        $cust2 = $this->makeCustomerWithCompletedVisit($salon['user'], 'c2@test.local', 'Veli', '1991-11-22');
        Artisan::call('birthdays:send-greetings');
        $wallet->refresh();
        $delivery1->refresh();
        $delivery2 = BirthdayGreetingDelivery::where('customer_user_id', $cust2->id)->firstOrFail();

        $this->assertSame('1.00', $delivery1->charged_amount); // untouched historical price
        $this->assertSame('5.00', $delivery2->charged_amount);
        $this->assertSame('100.00', $wallet->promo_balance); // promo untouched when allow_promo=false
        $this->assertSame('14.50', $wallet->balance);

        // 4. Permanent FCM failure (UNREGISTERED token) releases reservation and records REFUND ledger row
        $fcmMode = 'unregistered';
        $cust3 = $this->makeCustomerWithCompletedVisit($salon['user'], 'c3@test.local', 'Selin', '1992-11-22');
        Artisan::call('birthdays:send-greetings');
        $wallet->refresh();
        $delivery3 = BirthdayGreetingDelivery::where('customer_user_id', $cust3->id)->firstOrFail();

        $this->assertSame('14.50', $wallet->balance);
        $this->assertSame('0.00', $wallet->reserved_cash_balance);
        $this->assertSame(NotificationDispatchRecipient::BILLING_RELEASED, $delivery3->billing_status);
        $this->assertSame(NotificationDispatchRecipient::DELIVERY_INVALID_TOKEN, $delivery3->delivery_status);
        $this->assertTrue(WalletTransaction::where('user_id', $salon['user']->id)
            ->where('type', WalletTransaction::TYPE_BIRTHDAY_NOTIFICATION_REFUND)
            ->exists());
    }

    public function test_insufficient_balance_and_frozen_wallet_block_sends_without_negative_balance(): void
    {
        $tz = (string) config('app.timezone', 'Europe/Istanbul');
        Carbon::setTestNow(Carbon::parse('2026-11-22 10:05:00', $tz));

        $admin = $this->makeAdmin();
        Sanctum::actingAs($admin);
        $this->putJson('/api/admin/notification-center/settings', ['birthday_unit_price' => 5.00])->assertOk();

        // 1. Insufficient balance (0.00)
        $emptySalon = $this->makeApprovedProvider('empty@test.local', 'Boş Cüzdan Kuaför', 0.00, 0.00);
        ProviderBirthdaySetting::create([
            'provider_profile_id' => $emptySalon['profile']->id,
            'is_enabled' => true,
            'send_on_birthday' => true,
            'send_time' => '10:00',
        ]);
        $custA = $this->makeCustomerWithCompletedVisit($emptySalon['user'], 'ca@test.local', 'Deniz', '1995-11-22');
        Artisan::call('birthdays:send-greetings');
        $this->assertSame(0, BirthdayGreetingDelivery::where('customer_user_id', $custA->id)->count());
        $this->assertTrue(NotificationAbuseAlert::where('provider_user_id', $emptySalon['user']->id)
            ->where('alert_type', NotificationAbuseAlert::TYPE_INSUFFICIENT_BALANCE_ATTEMPT)->exists());

        // 2. Frozen wallet (even with 500 TL balance)
        $frozenSalon = $this->makeApprovedProvider('frozen@test.local', 'Donuk Cüzdan', 500.00, 100.00);
        $frozenSalon['wallet']->update(['is_frozen' => true]);
        ProviderBirthdaySetting::create([
            'provider_profile_id' => $frozenSalon['profile']->id,
            'is_enabled' => true,
            'send_on_birthday' => true,
            'send_time' => '10:00',
        ]);
        $custB = $this->makeCustomerWithCompletedVisit($frozenSalon['user'], 'cb@test.local', 'Cem', '1995-11-22');
        Artisan::call('birthdays:send-greetings');
        $this->assertSame(0, BirthdayGreetingDelivery::where('customer_user_id', $custB->id)->count());

        // Concurrent/repeated notification ad purchases never go negative!
        $adSalon = $this->makeApprovedProvider('ad-race@test.local', 'Reklam Yarışı', 100.00, 0.00);
        $this->makeCustomerWithCompletedVisit($adSalon['user'], 'cust-ad@test.local', 'Zeynep', '1993-01-01');
        NotificationAdSetting::current()->update([
            'price_all' => 80.00,
            'max_sends_per_provider_per_day' => 5,
            'rapid_campaign_threshold' => 5,
        ]);

        Queue::fake();
        $adService = app(NotificationAdService::class);
        $ad1 = $adService->purchaseWithWallet($adSalon['user'], [
            'audience' => 'all',
            'title' => 'Kampanya 1',
            'body' => 'Tüm bakımlarda harika fırsat.',
            'discount_percent' => 15,
            'discount_days' => 3,
        ]);
        $this->assertSame('20.00', Wallet::where('user_id', $adSalon['user']->id)->value('promo_balance'));
        $this->assertSame(NotificationDispatch::SOURCE_PROMO, $ad1->balance_source);

        try {
            $adService->purchaseWithWallet($adSalon['user'], [
                'audience' => 'all',
                'title' => 'Kampanya 2',
                'body' => 'Farklı içerik ikinci deneme.',
                'discount_percent' => 15,
                'discount_days' => 3,
            ]);
            $this->fail('Expected ValidationException on insufficient balance');
        } catch (ValidationException) {
            // Expected
        }
        $walletAfter = Wallet::where('user_id', $adSalon['user']->id)->firstOrFail();
        $this->assertGreaterThanOrEqual(0, FinancialService::parseToCents($walletAfter->promo_balance));
        $this->assertGreaterThanOrEqual(0, FinancialService::parseToCents($walletAfter->balance));
    }

    public function test_admin_block_stops_queued_ads_and_birthday_push_while_allowing_essential_appointment_notifications(): void
    {
        Http::fake(['fcm.googleapis.com/*' => Http::response(['name' => 'projects/p/messages/9'], 200)]);
        $tz = (string) config('app.timezone', 'Europe/Istanbul');
        Carbon::setTestNow(Carbon::parse('2026-11-22 10:05:00', $tz));

        $admin = $this->makeAdmin();
        $salon = $this->makeApprovedProvider('blocked@test.local', 'Engelli Salon', 500.00, 200.00);
        // Register active FCM device for the provider to confirm appointment notifications still deliver
        PushDevice::create([
            'user_id' => $salon['user']->id,
            'platform' => 'ANDROID',
            'token_hash' => hash('sha256', 'provider-fcm-tok'),
            'token_encrypted' => 'provider-fcm-tok',
            'status' => PushDevice::STATUS_ACTIVE,
            'last_registered_at' => now(),
        ]);

        $cust = $this->makeCustomerWithCompletedVisit($salon['user'], 'cblk@test.local', 'Kaan', '1994-11-22');

        NotificationAdSetting::current()->update(['price_all' => 100.00, 'birthday_unit_price' => 2.00]);
        ProviderBirthdaySetting::create([
            'provider_profile_id' => $salon['profile']->id,
            'is_enabled' => true,
            'send_on_birthday' => true,
            'send_time' => '10:00',
        ]);

        // Enqueue both a NotificationAd AND a BirthdayGreeting BEFORE admin blocks
        Queue::fake();
        $ad = app(NotificationAdService::class)->purchaseWithWallet($salon['user'], [
            'audience' => 'all',
            'title' => 'Özel İndirim',
            'body' => 'Saç kesiminde geçerli fırsat.',
            'discount_percent' => 10,
            'discount_days' => 5,
        ]);
        $this->assertSame('400.00', Wallet::where('user_id', $salon['user']->id)->value('promo_balance'));

        Artisan::call('birthdays:send-greetings');
        $bdayDelivery = BirthdayGreetingDelivery::where('customer_user_id', $cust->id)->firstOrFail();
        $this->assertSame('2.00', Wallet::where('user_id', $salon['user']->id)->value('reserved_promo_balance'));

        // Admin disables provider outbound notification permissions with reason
        Sanctum::actingAs($admin);
        $this->putJson("/api/admin/notification-center/providers/{$salon['user']->id}/controls", [
            'can_send_notification_ads' => false,
            'can_send_birthday_greetings' => false,
            'can_send_auto_special_day' => false,
            'block_mode' => 'indefinite',
            'reason' => 'Kullanıcı şikayeti üzerine geçici inceleme.',
        ])->assertOk();

        // AdminLog recorded with before/after/reason
        $this->assertTrue(AdminLog::where('action', AdminLog::ACTION_PROVIDER_NOTIFICATION_PERMISSION_UPDATED)
            ->where('target_id', $salon['user']->id)->exists());

        // Provider trying to turn birthday assistant on gets 422
        Sanctum::actingAs($salon['user']);
        $this->putJson('/api/provider/birthday-assistant', ['is_enabled' => true])
            ->assertStatus(422);

        // Queued birthday push job executes AFTER block -> STOPPED, reservation released, zero FCM call to customer!
        Http::fake(['fcm.googleapis.com/*' => Http::response(['name' => 'projects/p/messages/ok'], 200)]);
        (new SendPushNotification($bdayDelivery->user_notification_id))->handle(app(FcmPushService::class));
        Http::assertNothingSent();

        // Queued NotificationAd was stopped & refunded (400.00 + 100.00 = 500.00 restored)
        $ad->refresh();
        $this->assertSame(NotificationAd::STATUS_BLOCKED, $ad->status);
        $wallet = Wallet::where('user_id', $salon['user']->id)->firstOrFail();
        $this->assertSame('500.00', $wallet->promo_balance);
        $this->assertSame('0.00', $wallet->reserved_promo_balance);

        // CRITICAL: Restricted provider STILL receives essential appointment & reminder notifications WITHOUT any fee!
        $notifService = app(NotificationService::class);
        $apptNotif = $notifService->notifyUser(
            $salon['user']->id,
            UserNotification::TYPE_APPOINTMENT_REQUESTED,
            'Yeni Randevu Talebi',
            'Kaan yeni bir randevu talep etti.',
            UserNotification::RESOURCE_SCHEDULED_APPOINTMENT,
            999,
            '/p/appointments'
        );
        (new SendPushNotification($apptNotif->id))->handle(app(FcmPushService::class));
        Http::assertSentCount(1);
        $this->assertSame('500.00', Wallet::where('user_id', $salon['user']->id)->value('promo_balance'));
        $this->assertSame(0, NotificationDispatch::where('provider_user_id', $salon['user']->id)
            ->where('notification_type', 'APPOINTMENT_REQUESTED')->count());
    }

    public function test_birthday_opt_out_promotional_consent_abuse_guards_admin_visibility_and_tenant_isolation(): void
    {
        Http::fake(['fcm.googleapis.com/*' => Http::response(['name' => 'projects/p/messages/ok'], 200)]);
        $tz = (string) config('app.timezone', 'Europe/Istanbul');
        Carbon::setTestNow(Carbon::parse('2026-11-22 10:05:00', $tz));

        $admin = $this->makeAdmin();
        $salonA = $this->makeApprovedProvider('salona@test.local', 'Salon A', 500.00, 0.00);
        $salonB = $this->makeApprovedProvider('salonb@test.local', 'Salon B', 500.00, 0.00);

        NotificationAdSetting::current()->update([
            'birthday_unit_price' => 3.00,
            'price_all' => 50.00,
            'max_sends_per_provider_per_day' => 10,
            'rapid_campaign_threshold' => 2,
            'rapid_campaign_window_minutes' => 30,
        ]);

        // Cust1 opted OUT of campaigns, opted IN to birthday -> promotional birthday copy MUST skip!
        $custNoPromo = $this->makeCustomerWithCompletedVisit($salonA['user'], 'noads@test.local', 'Ebru', '1994-11-22', true, false);
        // Cust2 opted IN to both -> allowed
        $custBoth = $this->makeCustomerWithCompletedVisit($salonA['user'], 'both@test.local', 'Canan', '1994-11-22', true, true);
        // Cust3 opted OUT of birthday
        $custNoBday = $this->makeCustomerWithCompletedVisit($salonA['user'], 'nobday@test.local', 'Okan', '1994-11-22', false, true);

        ProviderBirthdaySetting::create([
            'provider_profile_id' => $salonA['profile']->id,
            'is_enabled' => true,
            'send_on_birthday' => true,
            'send_time' => '10:00',
            'template_key' => 'custom',
            'custom_message' => 'İyi ki doğdun {ad}! Sana özel %20 indirim fırsatını kaçırma!',
        ]);

        Artisan::call('birthdays:send-greetings');
        $this->assertSame(0, BirthdayGreetingDelivery::where('customer_user_id', $custNoPromo->id)->count());
        $this->assertSame(0, BirthdayGreetingDelivery::where('customer_user_id', $custNoBday->id)->count());
        $this->assertSame(1, BirthdayGreetingDelivery::where('customer_user_id', $custBoth->id)->count());
        $this->assertTrue(NotificationAbuseAlert::where('provider_user_id', $salonA['user']->id)
            ->where('alert_type', NotificationAbuseAlert::TYPE_UNAUTHORIZED_MARKETING)->exists());

        // Abuse guard: Duplicate content + Rapid burst on NotificationAd
        Queue::fake();
        $adService = app(NotificationAdService::class);
        $adService->purchaseWithWallet($salonA['user'], [
            'audience' => 'all',
            'title' => 'Özel Gün',
            'body' => 'Hafta sonu özel bakım günü.',
            'discount_percent' => 15,
            'discount_days' => 2,
        ]);
        try {
            $adService->purchaseWithWallet($salonA['user'], [
                'audience' => 'all',
                'title' => 'Özel Gün',
                'body' => 'Hafta sonu özel bakım günü.',
                'discount_percent' => 15,
                'discount_days' => 2,
            ]);
            $this->fail('Expected duplicate content block');
        } catch (ValidationException) {
        }
        $adService->purchaseWithWallet($salonA['user'], [
            'audience' => 'all',
            'title' => 'Farklı Başlık',
            'body' => 'Farklı kampanya açıklaması.',
            'discount_percent' => 20,
            'discount_days' => 2,
        ]);
        try {
            $adService->purchaseWithWallet($salonA['user'], [
                'audience' => 'all',
                'title' => 'Üçüncü Hızlı',
                'body' => 'Kısa sürede aşırı deneme.',
                'discount_percent' => 20,
                'discount_days' => 2,
            ]);
            $this->fail('Expected rapid burst block');
        } catch (ValidationException) {
        }
        $this->assertTrue(NotificationAbuseAlert::where('provider_user_id', $salonA['user']->id)
            ->where('alert_type', NotificationAbuseAlert::TYPE_RAPID_CAMPAIGNS)->exists());

        // Admin views dispatch + recipients without exposing birth_date or FCM tokens
        $bdayDispatch = NotificationDispatch::where('provider_user_id', $salonA['user']->id)
            ->where('notification_type', NotificationDispatch::TYPE_BIRTHDAY_GREETING)
            ->firstOrFail();

        Sanctum::actingAs($admin);
        $overviewRes = $this->getJson('/api/admin/notification-center/overview')->assertOk();
        $this->assertGreaterThan(0, $overviewRes->json('data.totals.total_dispatches'));

        $recRes = $this->getJson("/api/admin/notification-center/dispatches/{$bdayDispatch->id}/recipients")->assertOk();
        $recJson = json_encode($recRes->json(), JSON_UNESCAPED_UNICODE);
        $this->assertStringContainsString('Canan Müşteri', $recJson);
        $this->assertStringContainsString('FCM tarafından kabul edildi', $recJson);
        $this->assertStringNotContainsString('1994-11-22', $recJson);
        $this->assertStringNotContainsString('raw-fcm-secret-token', $recJson);

        // Tenant isolation: Salon B CANNOT access Salon A's dispatch!
        Sanctum::actingAs($salonB['user']);
        $this->getJson("/api/provider/notification-report/dispatches/{$bdayDispatch->id}")->assertStatus(403);
        $this->assertTrue(NotificationAbuseAlert::where('provider_user_id', $salonB['user']->id)
            ->where('alert_type', NotificationAbuseAlert::TYPE_UNAUTHORIZED_PII_ACCESS)->exists());

        $reportRes = $this->getJson('/api/provider/notification-report')->assertOk();
        $this->assertStringNotContainsString('Salon A', json_encode($reportRes->json(), JSON_UNESCAPED_UNICODE));
        $this->assertStringNotContainsString('1994-11-22', json_encode($reportRes->json()));
    }
}
