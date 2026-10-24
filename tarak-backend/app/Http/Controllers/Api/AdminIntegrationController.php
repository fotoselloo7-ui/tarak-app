<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AdminLog;
use App\Models\IntegrationEvent;
use App\Models\PushDevice;
use App\Models\SmsMessage;
use App\Models\UserNotification;
use App\Services\FcmPushService;
use App\Services\IntegrationSettings;
use App\Services\IntegrationStatusService;
use App\Services\Sms\SmsManager;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Mail;

/**
 * Admin integration control plane. EVERY route here is ADMIN-only (enforced by
 * the `role:ADMIN` middleware group in routes/api.php).
 *
 * Hard rule: no response from this controller may contain a raw credential.
 * Secrets are surfaced as masked strings or boolean "configured" flags only.
 */
class AdminIntegrationController extends Controller
{
    public function __construct(
        private IntegrationStatusService $status,
        private IntegrationSettings $settings,
        private SmsManager $sms,
    ) {
    }

    public function overview(): JsonResponse
    {
        return response()->json([
            'success' => true,
            'data' => [
                'cards' => $this->status->overview(),
                'health' => $this->status->systemHealth(),
                'generated_at' => now()->toIso8601String(),
            ],
        ]);
    }

    /** Detail payload for one integration tab. */
    public function show(string $integration): JsonResponse
    {
        $map = [
            'paytr' => fn () => $this->status->paytr(),
            'sms' => fn () => $this->status->sms(),
            'smtp' => fn () => $this->status->smtp(),
            'firebase' => fn () => $this->status->fcm(),
            'reverb' => fn () => $this->status->reverb(),
            'queue' => fn () => $this->status->queue(),
            'scheduler' => fn () => $this->status->scheduler(),
        ];

        if (!isset($map[$integration])) {
            return response()->json(['success' => false, 'message' => 'Bilinmeyen entegrasyon.'], 404);
        }

        return response()->json([
            'success' => true,
            'data' => $map[$integration](),
            'recent_events' => $this->recentEventsFor($integration === 'firebase' ? 'fcm' : $integration),
        ]);
    }

    /**
     * Updates admin-managed settings for one group.
     * Empty secret fields are ignored so an existing credential is preserved.
     */
    public function updateSettings(Request $request, string $group): JsonResponse
    {
        if (!isset(IntegrationSettings::SCHEMA[$group])) {
            return response()->json(['success' => false, 'message' => 'Bilinmeyen ayar grubu.'], 404);
        }

        $validated = $request->validate([
            'settings' => ['required', 'array'],
            'settings.*' => ['nullable', 'string', 'max:2000'],
        ], [
            'settings.required' => 'Ayarlar zorunludur.',
        ]);

        // The admin UI sends all values as strings, but validate the SMTP
        // configuration on the server before writing any encrypted credentials.
        // An invalid port/scheme is a validation error, never an SMTP 500.
        if ($group === 'smtp') {
            $smtp = $validated['settings'];
            if (isset($smtp['port']) && $smtp['port'] !== ''
                && (!ctype_digit((string) $smtp['port']) || (int) $smtp['port'] < 1 || (int) $smtp['port'] > 65535)) {
                return response()->json([
                    'success' => false,
                    'message' => 'SMTP portu 1–65535 arasında bir sayı olmalıdır (STARTTLS: 587, SSL: 465).',
                ], 422);
            }
            if (isset($smtp['encryption']) && $smtp['encryption'] !== '') {
                $encryption = strtolower(trim((string) $smtp['encryption']));
                if (!in_array($encryption, ['tls', 'starttls', 'ssl', 'smtps'], true)) {
                    return response()->json([
                        'success' => false,
                        'message' => 'SMTP şifrelemesi tls veya ssl olmalıdır (587=tls, 465=ssl).',
                    ], 422);
                }
                $validated['settings']['encryption'] = $encryption;
            }
        }

        $allowed = array_keys(IntegrationSettings::SCHEMA[$group]);
        $changed = [];
        $skippedSecrets = [];

        try {
            // All settings and their audit log must succeed together. A failure
            // must not leave half-updated SMTP credentials in production.
            DB::transaction(function () use ($validated, $group, $allowed, $request, &$changed, &$skippedSecrets): void {
                foreach ($validated['settings'] as $key => $value) {
                    if (!in_array($key, $allowed, true)) {
                        continue;
                    }

                    $isSecret = (bool) IntegrationSettings::SCHEMA[$group][$key]['secret'];
                    $applied = $this->settings->set($group, $key, $value, $request->user()->id);
                    if ($applied) {
                        $changed[] = $key;
                    } elseif ($isSecret) {
                        $skippedSecrets[] = $key;
                    }
                }

                $this->audit($request, 'INTEGRATION_SETTINGS_UPDATED', [
                    'group' => $group,
                    'changed_keys' => $changed,
                    'preserved_secret_keys' => $skippedSecrets,
                ]);
            });
        } catch (\Throwable $e) {
            // Deliberately do NOT log $e->getMessage(), SQL bindings, request
            // payload or stacktrace: any could expose the SMTP password.
            $errorId = strtoupper(bin2hex(random_bytes(4)));
            $dbNumber = $e instanceof \Illuminate\Database\QueryException
                ? (int) ($e->errorInfo[1] ?? 0)
                : null;
            $reason = match (true) {
                $dbNumber === 1146 => 'Entegrasyon veritabanı tablosu bulunamadı. Sunucuda php artisan migrate --force çalıştırın.',
                $dbNumber === 1054 => 'Entegrasyon tablosunda eksik sütun var. Veritabanı migrasyonlarını kontrol edin.',
                $dbNumber === 1452 => 'Yönetici hesabı için veritabanı ilişki hatası oluştu.',
                $e instanceof \Illuminate\Encryption\MissingAppKeyException => 'Laravel APP_KEY yapılandırılmamış. Mevcut şifreleme anahtarını kontrol edin; yeni bir anahtar oluşturmayın.',
                $e instanceof \Illuminate\Contracts\Encryption\DecryptException => 'Kaydedilmiş entegrasyon verileri mevcut APP_KEY ile çözülemiyor. Önce eski APP_KEY değerini geri yükleyin.',
                default => 'Entegrasyon ayarları veritabanına kaydedilemedi. Sunucu hata kodunu kontrol edin.',
            };
            try {
                logger()->error('integration_settings_save_failed', [
                    'error_id' => $errorId,
                    'group' => $group,
                    'exception_class' => get_class($e),
                    'database_errno' => $dbNumber,
                    'source_line' => $e->getLine(),
                    // Never record the submitted settings or their values.
                ]);
            } catch (\Throwable) {
                // Logging failure must not expose secrets to the response.
            }

            return response()->json([
                'success' => false,
                'message' => $reason . ' (Hata kodu: ' . $errorId . ')',
            ], 500);
        }

        // Cache invalidation after commit also prevents stale reads after an
        // earlier failed or retried transaction.
        try {
            $this->settings->flush();
        } catch (\Throwable) {
            // A cache outage after commit must not turn a successful save into
            // a false HTTP 500; the next request will re-read persisted values.
        }

        return response()->json([
            'success' => true,
            'message' => 'Ayarlar kaydedildi.',
            'data' => [
                'changed' => $changed,
                'preserved_secrets' => $skippedSecrets,
            ],
        ]);
    }

    // ------------------------------------------------------------ PayTR test

    /**
     * Config validation only. NEVER initiates a charge, refund or payout.
     */
    public function validatePaytr(Request $request): JsonResponse
    {
        $result = $this->status->validatePaytrConfig();

        IntegrationEvent::record(
            integration: 'paytr',
            eventType: 'config_validation',
            direction: 'outbound',
            status: $result['config_valid'] ? IntegrationEvent::STATUS_SUCCESS : IntegrationEvent::STATUS_WARNING,
            reference: 'admin:' . $request->user()->id,
        );

        return response()->json(['success' => true, 'data' => $result]);
    }

    // -------------------------------------------------------------- SMS test

    public function testSms(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'phone' => ['required', 'string', 'max:25'],
        ], [
            'phone.required' => 'Test için telefon numarası giriniz.',
        ]);

        if (!$this->sms->isEnabled()) {
            return response()->json([
                'success' => false,
                'message' => 'SMS entegrasyonu kapalı. Önce "Aktif" olarak kaydedin.',
            ], 422);
        }

        $config = $this->sms->validateConfig();
        if (!$config['valid']) {
            return response()->json([
                'success' => false,
                'message' => 'SMS sağlayıcı yapılandırılmamış. Eksik: ' . implode(', ', $config['missing']),
            ], 422);
        }

        if (SmsManager::normalizePhone($validated['phone']) === null) {
            return response()->json([
                'success' => false,
                'message' => 'Geçersiz telefon numarası. Örnek: 05551112233',
            ], 422);
        }

        // `admin_test` bypasses the per-event switch on purpose: it is an
        // explicit, manual admin action, not an automated domain notification.
        $result = $this->sms->send(
            $validated['phone'],
            SmsManager::TEMPLATES['admin_test'],
            'admin_test',
            $request->user()->id,
        );

        $this->audit($request, 'INTEGRATION_TEST_SMS', [
            'provider' => $result['provider'] ?? $this->sms->providerKey(),
            'result' => $result['sent'] ? 'success' : 'failed',
        ]);

        return response()->json([
            'success' => $result['sent'],
            'message' => $result['sent']
                ? 'Test SMS sağlayıcıya iletildi.'
                : ('Test SMS gönderilemedi: ' . ($result['error'] ?? $result['reason'] ?? 'bilinmeyen hata')),
            'data' => [
                'provider' => $result['provider'] ?? $this->sms->providerKey(),
                'log_id' => $result['log_id'] ?? null,
            ],
        ], $result['sent'] ? 200 : 422);
    }

    /** SMS delivery log (recipients already masked at write time). */
    public function smsLogs(Request $request): JsonResponse
    {
        $logs = SmsMessage::query()
            ->latest('id')
            ->limit(min((int) $request->query('limit', 50), 200))
            ->get()
            ->map(fn (SmsMessage $m) => [
                'id' => $m->id,
                'provider' => $m->provider,
                'recipient' => $m->recipient_masked,
                'template_key' => $m->template_key,
                'status' => $m->status,
                'provider_message_id' => $m->provider_message_id,
                'error_code' => $m->error_code,
                'error_message' => $m->error_message,
                'created_at' => $m->created_at?->toIso8601String(),
                'sent_at' => $m->sent_at?->toIso8601String(),
            ]);

        return response()->json(['success' => true, 'data' => $logs]);
    }

    // ------------------------------------------------------------ SMTP test

    public function testEmail(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'email' => ['required', 'email', 'max:180'],
        ], [
            'email.required' => 'Test için e-posta adresi giriniz.',
        ]);

        $mailer = (string) config('mail.default');
        $sent = false;
        $error = null;

        // The SMTP values saved in the admin panel are the ones the business e-mails use too: test with exactly those.
        app(\App\Services\MailSettingsApplier::class)->apply();

        try {
            Mail::raw(
                "Tarak e-posta bağlantı testi.\n\n"
                . "Bu mesaj yönetici panelinden gönderilmiştir.\n"
                . 'Gönderim zamanı: ' . now()->toDateTimeString(),
                function ($message) use ($validated) {
                    $message->to($validated['email'])->subject('Tarak E-posta Bağlantı Testi');
                }
            );
            // Mail::raw throws on transport failure, so reaching here means the
            // mailer actually accepted the message (not just an HTTP 200).
            $sent = true;
        } catch (\Throwable $e) {
            $error = $e->getMessage();
        }

        IntegrationEvent::record(
            integration: 'smtp',
            eventType: 'test_email',
            direction: 'outbound',
            status: $sent ? IntegrationEvent::STATUS_SUCCESS : IntegrationEvent::STATUS_FAILED,
            reference: 'admin:' . $request->user()->id,
            errorMessage: $error,
        );

        $this->audit($request, 'INTEGRATION_TEST_EMAIL', [
            'mailer' => $mailer,
            'result' => $sent ? 'success' : 'failed',
        ]);

        return response()->json([
            'success' => $sent,
            'message' => $sent
                ? ($mailer === 'log'
                    ? 'E-posta "log" sürücüsüne yazıldı (gerçek gönderim için SMTP yapılandırın).'
                    : 'Test e-postası gönderildi.')
                : ('E-posta gönderilemedi: ' . IntegrationEvent::sanitise($error)),
            'data' => ['mailer' => $mailer],
        ], $sent ? 200 : 422);
    }

    // -------------------------------------------------------- Firebase test

    public function testPush(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'device_id' => ['nullable', 'integer'],
        ]);

        $fcm = app(FcmPushService::class);
        if (!$fcm->isConfigured()) {
            return response()->json([
                'success' => false,
                'message' => 'Firebase yapılandırılmamış (project id / service account eksik).',
            ], 422);
        }

        $device = $validated['device_id'] ?? null
            ? PushDevice::query()->where('id', $validated['device_id'])->first()
            : PushDevice::query()->where('status', PushDevice::STATUS_ACTIVE)->latest('last_used_at')->first();

        if (!$device) {
            return response()->json([
                'success' => false,
                'message' => 'Test için kayıtlı aktif cihaz bulunamadı.',
            ], 422);
        }

        // A real notification row is required by the delivery contract; it is
        // addressed to the device owner and clearly marked as a test.
        $notification = UserNotification::create([
            'user_id' => $device->user_id,
            'type' => 'SYSTEM_TEST',
            'title' => 'Tarak Test Bildirimi',
            'message' => 'Bu bildirim yönetici panelinden gönderilen bir bağlantı testidir.',
            'idempotency_key' => 'admin-test-push-' . uniqid(),
        ]);

        $result = $fcm->sendToDevice($device, $notification);
        $success = (bool) ($result['success'] ?? false);

        IntegrationEvent::record(
            integration: 'fcm',
            eventType: 'test_push',
            direction: 'outbound',
            status: $success ? IntegrationEvent::STATUS_SUCCESS : IntegrationEvent::STATUS_FAILED,
            reference: $result['provider_message_id'] ?? ('device:' . $device->id),
            errorCode: $result['error_code'] ?? null,
        );

        $this->audit($request, 'INTEGRATION_TEST_PUSH', [
            'device_id' => $device->id,
            'platform' => $device->platform,
            'result' => $success ? 'success' : 'failed',
        ], 'PUSH_DEVICE', $device->id);

        return response()->json([
            'success' => $success,
            'message' => $success
                ? 'Test bildirimi FCM tarafından kabul edildi.'
                : ('Test bildirimi gönderilemedi (' . ($result['error_code'] ?? $result['status'] ?? 'bilinmeyen') . ').'),
            'data' => [
                'device_id' => $device->id,
                'platform' => $device->platform,
                'status' => $result['status'] ?? null,
                'error_code' => $result['error_code'] ?? null,
            ],
        ], $success ? 200 : 422);
    }

    /** Active devices usable as a test push target (no raw tokens exposed). */
    public function pushDevices(): JsonResponse
    {
        $devices = PushDevice::query()
            ->where('status', PushDevice::STATUS_ACTIVE)
            ->with('user:id,name,role')
            ->latest('last_used_at')
            ->limit(25)
            ->get()
            ->map(fn (PushDevice $d) => [
                'id' => $d->id,
                'platform' => $d->platform,
                'user' => $d->user?->name,
                'role' => $d->user?->role,
                'device_model' => $d->device_model,
                'app_version' => $d->app_version,
                'last_used_at' => $d->last_used_at?->toIso8601String(),
            ]);

        return response()->json(['success' => true, 'data' => $devices]);
    }

    // ----------------------------------------------------------- Reverb test

    public function testReverb(Request $request): JsonResponse
    {
        $detail = $this->status->reverb();

        IntegrationEvent::record(
            integration: 'reverb',
            eventType: 'health_probe',
            direction: 'outbound',
            status: $detail['process_reachable'] ? IntegrationEvent::STATUS_SUCCESS : IntegrationEvent::STATUS_FAILED,
            reference: 'admin:' . $request->user()->id,
            errorMessage: $detail['process_reachable'] ? null : 'Reverb sürecine TCP bağlantısı kurulamadı.',
        );

        return response()->json([
            'success' => true,
            'data' => [
                // Config validity and process reachability stay separate.
                'configured' => $detail['configured'],
                'process_reachable' => $detail['process_reachable'],
                'status' => $detail['status'],
                'warnings' => $detail['warnings'],
                'message' => $detail['summary'],
            ],
        ]);
    }

    // ----------------------------------------------------------- Failed jobs

    public function failedJobs(Request $request): JsonResponse
    {
        return response()->json([
            'success' => true,
            'data' => $this->status->failedJobs(min((int) $request->query('limit', 50), 200)),
        ]);
    }

    public function retryFailedJob(Request $request, string $uuid): JsonResponse
    {
        $exists = DB::table('failed_jobs')->where('uuid', $uuid)->exists();
        if (!$exists) {
            return response()->json(['success' => false, 'message' => 'Kayıt bulunamadı.'], 404);
        }

        // Canonical Laravel path — re-pushes the job and removes the failed row.
        \Illuminate\Support\Facades\Artisan::call('queue:retry', ['id' => [$uuid]]);

        $this->audit($request, 'FAILED_JOB_RETRY', ['uuid' => $uuid]);

        return response()->json(['success' => true, 'message' => 'İş yeniden kuyruğa alındı.']);
    }

    public function deleteFailedJob(Request $request, string $uuid): JsonResponse
    {
        $deleted = DB::table('failed_jobs')->where('uuid', $uuid)->delete();
        if (!$deleted) {
            return response()->json(['success' => false, 'message' => 'Kayıt bulunamadı.'], 404);
        }

        $this->audit($request, 'FAILED_JOB_DELETED', ['uuid' => $uuid]);

        return response()->json(['success' => true, 'message' => 'Kayıt silindi.']);
    }

    // --------------------------------------------------------------- Events

    public function events(Request $request): JsonResponse
    {
        $query = IntegrationEvent::query()->latest('occurred_at');

        if ($integration = $request->query('integration')) {
            $query->where('integration', $integration);
        }
        if ($status = $request->query('status')) {
            $query->where('status', $status);
        }

        $events = $query->limit(min((int) $request->query('limit', 100), 300))->get()
            ->map(fn (IntegrationEvent $e) => [
                'id' => $e->id,
                'integration' => $e->integration,
                'event_type' => $e->event_type,
                'direction' => $e->direction,
                'reference' => $e->reference,
                'status' => $e->status,
                'http_status' => $e->http_status,
                'error_code' => $e->error_code,
                'error_message' => $e->error_message,
                'occurred_at' => $e->occurred_at?->toIso8601String(),
            ]);

        return response()->json(['success' => true, 'data' => $events]);
    }

    public function health(): JsonResponse
    {
        return response()->json(['success' => true, 'data' => $this->status->systemHealth()]);
    }

    /**
     * Records a critical admin action. `metadata` carries field NAMES and
     * outcomes only — never a credential value.
     */
    private function audit(
        Request $request,
        string $action,
        array $metadata,
        string $targetType = 'INTEGRATION',
        ?int $targetId = null,
    ): void {
        AdminLog::create([
            'admin_user_id' => $request->user()->id,
            'action' => $action,
            'target_type' => $targetType,
            // admin_logs.target_id is NOT NULL; integration-scoped actions have
            // no domain row, so the acting admin is used as the target.
            'target_id' => $targetId ?? $request->user()->id,
            'metadata' => $metadata,
        ]);
    }

    private function recentEventsFor(string $integration, int $limit = 15): array
    {
        return IntegrationEvent::query()
            ->where('integration', $integration)
            ->latest('occurred_at')
            ->limit($limit)
            ->get()
            ->map(fn (IntegrationEvent $e) => [
                'id' => $e->id,
                'event_type' => $e->event_type,
                'direction' => $e->direction,
                'reference' => $e->reference,
                'status' => $e->status,
                'http_status' => $e->http_status,
                'error_message' => $e->error_message,
                'occurred_at' => $e->occurred_at?->toIso8601String(),
            ])->all();
    }
}
