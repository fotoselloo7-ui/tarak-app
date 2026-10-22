<?php

namespace App\Services;

use App\Models\IntegrationEvent;
use App\Models\PaymentGatewayAttempt;
use App\Models\PaymentRefund;
use App\Models\PayoutTransfer;
use App\Models\PushDeliveryAttempt;
use App\Models\PushDevice;
use App\Models\SchedulerHeartbeat;
use App\Models\ServicePayment;
use App\Models\SmsMessage;
use App\Services\Sms\SmsManager;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

/**
 * Builds the REAL status of every external integration from live config and
 * live database state. Nothing here is hardcoded to "connected", and no
 * secret value ever reaches the returned payload — only masked strings and
 * boolean "configured" flags.
 */
class IntegrationStatusService
{
    public const HEALTHY = 'HEALTHY';
    public const WARNING = 'WARNING';
    public const ERROR = 'ERROR';
    public const NOT_CONFIGURED = 'NOT_CONFIGURED';

    public function __construct(
        private IntegrationSettings $settings,
        private SmsManager $sms,
    ) {
    }

    /** Compact card list for the "Genel Durum" dashboard. */
    public function overview(): array
    {
        $cards = [];
        foreach (
            [
                'paytr' => 'PayTR',
                'sms' => 'SMS',
                'smtp' => 'E-posta / SMTP',
                'fcm' => 'Firebase / Push',
                'reverb' => 'Realtime / Reverb',
                'queue' => 'Queue',
                'scheduler' => 'Scheduler',
            ] as $key => $label
        ) {
            $detail = $this->{$key}();
            $cards[] = [
                'key' => $key,
                'label' => $label,
                'status' => $detail['status'],
                'configured' => $detail['configured'],
                'mode' => $detail['mode'] ?? null,
                'summary' => $detail['summary'] ?? null,
                'last_success_at' => $detail['last_success_at'] ?? null,
                'last_error' => $detail['last_error'] ?? null,
                'checked_at' => now()->toIso8601String(),
            ];
        }

        return $cards;
    }

    // ---------------------------------------------------------------- PayTR

    public function paytr(): array
    {
        $required = ['merchant_id', 'merchant_key', 'merchant_salt'];
        $missing = array_values(array_filter(
            $required,
            fn ($k) => !$this->settings->isConfigured('paytr', $k)
        ));
        $configured = $missing === [];

        $testMode = (int) $this->settings->get('paytr', 'test_mode', 1) === 1;
        $callbackUrl = rtrim((string) config('app.url'), '/') . '/api/payments/paytr/callback';

        $lastAttempt = PaymentGatewayAttempt::query()->latest('id')->first();
        $lastCallback = PaymentGatewayAttempt::query()->whereNotNull('callback_received_at')
            ->latest('callback_received_at')->first();
        $lastSuccess = PaymentGatewayAttempt::query()
            ->where('status', PaymentGatewayAttempt::STATUS_SUCCESS)->latest('id')->first();
        $lastFailure = PaymentGatewayAttempt::query()
            ->where('status', PaymentGatewayAttempt::STATUS_FAILED)->latest('id')->first();
        $lastRefund = PaymentRefund::query()->latest('id')->first();
        $lastPayout = PayoutTransfer::query()->latest('id')->first();
        $lastError = $this->lastError('paytr');

        $warnings = $this->paytrWarnings($configured, $testMode, $callbackUrl);

        return [
            'status' => !$configured ? self::NOT_CONFIGURED : ($warnings ? self::WARNING : self::HEALTHY),
            'configured' => $configured,
            'missing' => $missing,
            'mode' => $testMode ? 'TEST' : 'PRODUCTION',
            'warnings' => $warnings,
            'summary' => $configured
                ? ($testMode ? 'Test modunda yapılandırılmış' : 'Canlı mod yapılandırılmış')
                : 'Kimlik bilgileri eksik',
            'credentials' => [
                'merchant_id' => $this->settings->mask('paytr', 'merchant_id'),
                'merchant_key_configured' => $this->settings->isConfigured('paytr', 'merchant_key'),
                'merchant_salt_configured' => $this->settings->isConfigured('paytr', 'merchant_salt'),
                'overridden_from_admin' => $this->settings->isOverridden('paytr', 'merchant_id'),
            ],
            'urls' => [
                'callback' => $callbackUrl,
                'transfer_callback' => rtrim((string) config('app.url'), '/') . '/api/payments/paytr/platform-transfer/callback',
                'ok_url' => (string) $this->settings->get('paytr', 'ok_url', ''),
                'fail_url' => (string) $this->settings->get('paytr', 'fail_url', ''),
                'app_url_is_https' => str_starts_with((string) config('app.url'), 'https://'),
            ],
            'capabilities' => [
                'payment' => true,
                'callback' => true,
                'refund' => class_exists(\App\Services\PaytrRefundService::class),
                'marketplace_payout' => class_exists(\App\Services\PayoutTransferService::class),
            ],
            'activity' => [
                'last_attempt_at' => $lastAttempt?->created_at?->toIso8601String(),
                'last_callback_at' => $lastCallback?->callback_received_at?->toIso8601String(),
                'last_callback_reference' => $lastCallback?->merchant_oid,
                'last_callback_status' => $lastCallback?->status,
                'last_success_at' => $lastSuccess?->created_at?->toIso8601String(),
                'last_failure_at' => $lastFailure?->created_at?->toIso8601String(),
                'last_failure_reason' => $lastFailure?->failure_message
                    ? IntegrationEvent::sanitise($lastFailure->failure_message) : null,
                'last_refund' => $lastRefund ? [
                    'reference_no' => $lastRefund->reference_no ?? null,
                    'status' => $lastRefund->status,
                    'at' => $lastRefund->created_at?->toIso8601String(),
                ] : null,
                'last_payout' => $lastPayout ? [
                    'status' => $lastPayout->status,
                    'at' => $lastPayout->created_at?->toIso8601String(),
                ] : null,
                'totals' => [
                    'payments' => ServicePayment::query()->count(),
                    'refunds_pending' => PaymentRefund::query()
                        ->whereIn('status', [PaymentRefund::STATUS_PENDING, PaymentRefund::STATUS_REQUESTED])->count(),
                    'refunds_failed' => PaymentRefund::query()->where('status', PaymentRefund::STATUS_FAILED)->count(),
                    'payouts_pending' => PayoutTransfer::query()
                        ->whereIn('status', [PayoutTransfer::STATUS_READY, PayoutTransfer::STATUS_REQUESTED])->count(),
                    'payouts_failed' => PayoutTransfer::query()->where('status', PayoutTransfer::STATUS_FAILED)->count(),
                ],
            ],
            'last_error' => $lastError,
            'last_success_at' => $lastSuccess?->created_at?->toIso8601String(),
        ];
    }

    /** @return string[] */
    private function paytrWarnings(bool $configured, bool $testMode, string $callbackUrl): array
    {
        $warnings = [];
        if (!$configured) {
            return $warnings;
        }

        $appUrl = (string) config('app.url');
        if (!str_starts_with($appUrl, 'https://')) {
            $warnings[] = 'APP_URL HTTPS değil — PayTR callback üretimde HTTPS gerektirir.';
        }
        if (str_contains($callbackUrl, 'localhost') || str_contains($callbackUrl, '127.0.0.1')) {
            $warnings[] = 'Callback adresi localhost — PayTR dışarıdan erişilebilir bir alan adı ister.';
        }
        if (!$testMode && app()->environment('local')) {
            $warnings[] = 'Canlı PayTR modu local ortamda açık.';
        }
        foreach (['ok_url', 'fail_url'] as $key) {
            if (!$this->settings->isConfigured('paytr', $key)) {
                $warnings[] = strtoupper($key) . ' tanımlı değil.';
            }
        }

        return $warnings;
    }

    /**
     * Config validation only — NEVER starts a real payment/charge.
     * Separates "config valid" from "live verified" per spec section 5.
     */
    public function validatePaytrConfig(): array
    {
        $detail = $this->paytr();
        $checks = [];

        $checks[] = $this->check('Kimlik bilgileri (merchant id/key/salt)', $detail['configured'],
            $detail['configured'] ? null : 'Eksik: ' . implode(', ', $detail['missing']));
        $checks[] = $this->check('APP_URL HTTPS', $detail['urls']['app_url_is_https'],
            $detail['urls']['app_url_is_https'] ? null : 'Üretimde HTTPS zorunludur.');
        $checks[] = $this->check('Callback adresi dışarıdan erişilebilir',
            !str_contains($detail['urls']['callback'], 'localhost') && !str_contains($detail['urls']['callback'], '127.0.0.1'),
            'Local adres PayTR tarafından çağrılamaz.');
        $checks[] = $this->check('OK / FAIL yönlendirme adresleri',
            $detail['urls']['ok_url'] !== '' && $detail['urls']['fail_url'] !== '', 'Eksik yönlendirme adresi.');

        // The service must be able to READ its own config through the same path
        // the live gateway uses (no charge is initiated).
        $serviceReadable = app(PaytrService::class)->isConfigured();
        $checks[] = $this->check('PaytrService config okuyabiliyor', $serviceReadable,
            'PaytrService kimlik bilgilerini okuyamıyor.');

        $allPassed = collect($checks)->every(fn ($c) => $c['passed']);

        return [
            'config_valid' => $allPassed,
            // Verifying against the live gateway would require a real
            // transaction, so this is explicitly never claimed here.
            'live_verified' => false,
            'live_verification_note' => 'PayTR gerçek doğrulaması yalnızca kontrollü bir üretim testi ile yapılabilir; bu buton hiçbir finansal işlem başlatmaz.',
            'checks' => $checks,
        ];
    }

    // ------------------------------------------------------------------ SMS

    public function sms(): array
    {
        $providerKey = $this->sms->providerKey();
        $provider = $this->sms->provider();
        $config = $provider->validateConfig();
        $enabled = $this->sms->isEnabled();

        $last = SmsMessage::query()->latest('id')->first();
        $lastSent = SmsMessage::query()->where('status', SmsMessage::STATUS_SENT)->latest('id')->first();
        $lastFailed = SmsMessage::query()->where('status', SmsMessage::STATUS_FAILED)->latest('id')->first();

        $status = match (true) {
            !$config['valid'] => self::NOT_CONFIGURED,
            !$enabled => self::WARNING,
            $lastFailed && (!$lastSent || $lastFailed->id > $lastSent->id) => self::WARNING,
            default => self::HEALTHY,
        };

        return [
            'status' => $status,
            'configured' => $config['valid'],
            'enabled' => $enabled,
            'missing' => $config['missing'],
            'mode' => $this->settings->isEnabled('sms', 'test_mode', true) ? 'TEST' : 'PRODUCTION',
            'summary' => $config['valid']
                ? ($enabled ? $provider->label() . ' aktif' : $provider->label() . ' yapılandırıldı, kapalı')
                : 'SMS sağlayıcı bilgileri eksik',
            'provider' => $providerKey,
            'provider_label' => $provider->label(),
            'available_providers' => collect(SmsManager::PROVIDERS)
                ->map(fn ($cls, $key) => ['key' => $key, 'label' => app($cls)->label()])
                ->values()->all(),
            'credentials' => [
                'username' => $this->settings->get('sms', 'username') ?: null,
                'password_configured' => $this->settings->isConfigured('sms', 'password'),
                'sender_title' => $this->settings->get('sms', 'sender_title') ?: null,
                'default_country' => $this->settings->get('sms', 'default_country', '90'),
            ],
            'events' => collect(array_keys(IntegrationSettings::SCHEMA['sms_events']))
                ->mapWithKeys(fn ($k) => [$k => $this->sms->isEventEnabled($k)])->all(),
            'templates' => SmsManager::TEMPLATES,
            'activity' => [
                'last_at' => $last?->created_at?->toIso8601String(),
                'last_status' => $last?->status,
                'last_success_at' => $lastSent?->sent_at?->toIso8601String(),
                'last_failure_at' => $lastFailed?->created_at?->toIso8601String(),
                'last_failure_reason' => $lastFailed?->error_message,
                'total' => SmsMessage::query()->count(),
                'sent_last_30d' => SmsMessage::query()->where('status', SmsMessage::STATUS_SENT)
                    ->where('created_at', '>=', now()->subDays(30))->count(),
                'failed_last_30d' => SmsMessage::query()->where('status', SmsMessage::STATUS_FAILED)
                    ->where('created_at', '>=', now()->subDays(30))->count(),
            ],
            'otp_capability' => $this->otpCapability(),
            'last_error' => $lastFailed?->error_message,
            'last_success_at' => $lastSent?->sent_at?->toIso8601String(),
        ];
    }

    /**
     * Honest report of whether a phone-verification/OTP flow exists in the
     * codebase — the SMS layer does not invent one (spec section 12).
     */
    private function otpCapability(): array
    {
        $hasColumn = Cache::remember('integration_otp_capability', 600, function () {
            try {
                return \Illuminate\Support\Facades\Schema::hasColumn('users', 'phone_verified_at');
            } catch (\Throwable) {
                return false;
            }
        });

        return [
            'present' => (bool) $hasColumn,
            'note' => $hasColumn
                ? 'users.phone_verified_at mevcut; OTP akışı SMS sağlayıcıya bağlanabilir.'
                : 'Projede telefon doğrulama/OTP akışı yok. Bu fazda auth mimarisine OTP eklenmedi.',
        ];
    }

    // ----------------------------------------------------------------- SMTP

    public function smtp(): array
    {
        $mailer = (string) config('mail.default');
        $host = (string) $this->settings->get('smtp', 'host', '');
        $fromAddress = (string) $this->settings->get('smtp', 'from_address', '');

        $isSmtp = $mailer === 'smtp';
        $configured = $isSmtp ? ($host !== '' && $fromAddress !== '') : $mailer === 'log';

        $lastSuccess = $this->lastEvent('smtp', IntegrationEvent::STATUS_SUCCESS);
        $lastError = $this->lastError('smtp');

        $status = match (true) {
            $mailer === 'log' => self::WARNING,   // mails go to the log file, not a real inbox
            !$configured => self::NOT_CONFIGURED,
            $lastError !== null && ($lastSuccess === null || $lastError['at'] > $lastSuccess->occurred_at->toIso8601String()) => self::ERROR,
            default => self::HEALTHY,
        };

        return [
            'status' => $status,
            'configured' => $configured,
            'mode' => $mailer === 'log' ? 'LOG' : strtoupper($mailer),
            'summary' => $mailer === 'log'
                ? 'MAIL_MAILER=log — e-postalar yalnızca log dosyasına yazılıyor'
                : ($configured ? $host . ' üzerinden SMTP' : 'SMTP bilgileri eksik'),
            'settings' => [
                'mailer' => $mailer,
                'host' => $host ?: null,
                'port' => $this->settings->get('smtp', 'port') ?: null,
                'encryption' => $this->settings->get('smtp', 'encryption') ?: null,
                'username' => $this->settings->get('smtp', 'username') ?: null,
                'username_configured' => $this->settings->isConfigured('smtp', 'username'),
                'password_configured' => $this->settings->isConfigured('smtp', 'password'),
                'from_address' => $fromAddress ?: null,
                'from_name' => $this->settings->get('smtp', 'from_name') ?: null,
            ],
            'last_success_at' => $lastSuccess?->occurred_at?->toIso8601String(),
            'last_error' => $lastError,
        ];
    }

    // ------------------------------------------------------------- Firebase

    public function fcm(): array
    {
        $enabled = (bool) config('fcm.enabled', false);
        $projectId = (string) (config('fcm.project_id') ?? '');
        $credentialsPath = (string) (config('fcm.credentials_path') ?? '');
        $credentialsExist = $credentialsPath !== '' && is_readable($credentialsPath);
        $serviceConfigured = app(\App\Services\FcmPushService::class)->isConfigured();

        $lastAttempt = PushDeliveryAttempt::query()->latest('id')->first();
        $lastSent = PushDeliveryAttempt::query()->where('status', PushDeliveryAttempt::STATUS_SENT)->latest('id')->first();
        $lastFailed = PushDeliveryAttempt::query()
            ->whereIn('status', [PushDeliveryAttempt::STATUS_FAILED, PushDeliveryAttempt::STATUS_INVALID_TOKEN])
            ->latest('id')->first();

        $status = match (true) {
            !$serviceConfigured => self::NOT_CONFIGURED,
            !$enabled => self::WARNING,
            default => self::HEALTHY,
        };

        return [
            'status' => $status,
            'configured' => $serviceConfigured,
            'enabled' => $enabled,
            'mode' => $enabled ? 'ACTIVE' : 'DISABLED',
            'summary' => $serviceConfigured
                ? ($enabled ? 'FCM HTTP v1 hazır' : 'Yapılandırıldı ancak FCM_ENABLED kapalı')
                : 'Firebase project id / service-account eksik',
            'settings' => [
                'project_id' => $projectId ?: null,
                'credentials_configured' => $credentialsPath !== '',
                'credentials_readable' => $credentialsExist,
                // Deliberately NOT returning the path contents or the key itself.
                'credentials_path_set' => $credentialsPath !== '',
            ],
            'devices' => [
                'total' => PushDevice::query()->count(),
                'active' => PushDevice::query()->where('status', PushDevice::STATUS_ACTIVE)->count(),
                'android' => PushDevice::query()->where('platform', 'android')
                    ->where('status', PushDevice::STATUS_ACTIVE)->count(),
                'ios' => PushDevice::query()->where('platform', 'ios')
                    ->where('status', PushDevice::STATUS_ACTIVE)->count(),
                'invalid' => PushDevice::query()->where('status', PushDevice::STATUS_INVALID)->count(),
            ],
            'activity' => [
                'last_attempt_at' => $lastAttempt?->created_at?->toIso8601String(),
                'last_success_at' => $lastSent?->sent_at?->toIso8601String(),
                'last_failure_at' => $lastFailed?->failed_at?->toIso8601String(),
                'last_failure_code' => $lastFailed?->error_code,
            ],
            'last_success_at' => $lastSent?->sent_at?->toIso8601String(),
            'last_error' => $lastFailed?->error_code ? ['message' => $lastFailed->error_code, 'at' => $lastFailed->failed_at?->toIso8601String()] : null,
        ];
    }

    // --------------------------------------------------------------- Reverb

    public function reverb(): array
    {
        $driver = (string) config('broadcasting.default');
        $app = config('reverb.apps.apps.0', []);
        $host = (string) ($app['options']['host'] ?? '');
        $port = (int) ($app['options']['port'] ?? 0);
        $scheme = (string) ($app['options']['scheme'] ?? 'http');
        $serverHost = (string) config('reverb.servers.reverb.host', '127.0.0.1');
        $serverPort = (int) config('reverb.servers.reverb.port', 8081);

        $configured = !empty($app['key']) && !empty($app['secret']) && !empty($app['app_id']);

        // Real reachability probe against the Reverb process (config alone is
        // never reported as "connected").
        $reachable = $this->probeTcp($serverHost === '0.0.0.0' ? '127.0.0.1' : $serverHost, $serverPort);

        $warnings = [];
        if ($configured && !app()->environment('local')) {
            if ($scheme !== 'https') {
                $warnings[] = 'Üretimde REVERB_SCHEME=https (WSS) olmalıdır.';
            }
            if (in_array($host, ['127.0.0.1', 'localhost', '10.0.2.2'], true)) {
                $warnings[] = 'REVERB_HOST local bir adres — üretimde gerçek alan adı gerekir.';
            }
        }

        $status = match (true) {
            !$configured => self::NOT_CONFIGURED,
            !$reachable => self::ERROR,
            $warnings !== [] => self::WARNING,
            default => self::HEALTHY,
        };

        $lastBroadcast = $this->lastEvent('reverb', IntegrationEvent::STATUS_SUCCESS);

        return [
            'status' => $status,
            'configured' => $configured,
            // Explicit separation demanded by spec section 18.
            'process_reachable' => $reachable,
            'mode' => app()->environment(),
            'summary' => !$configured
                ? 'Reverb app key/secret/app_id eksik'
                : ($reachable ? 'Yapılandırıldı ve süreç erişilebilir' : 'CONFIGURED — PROCESS UNREACHABLE'),
            'settings' => [
                'broadcast_driver' => $driver,
                'app_id_configured' => !empty($app['app_id']),
                'key_configured' => !empty($app['key']),
                'secret_configured' => !empty($app['secret']),
                'client_host' => $host ?: null,
                'client_port' => $port ?: null,
                'scheme' => $scheme,
                'server_host' => $serverHost,
                'server_port' => $serverPort,
                'allowed_origins' => $app['allowed_origins'] ?? [],
            ],
            'warnings' => $warnings,
            'last_success_at' => $lastBroadcast?->occurred_at?->toIso8601String(),
            'last_error' => $this->lastError('reverb'),
        ];
    }

    // ---------------------------------------------------------------- Queue

    public function queue(): array
    {
        $driver = (string) config('queue.default');
        $defaultQueue = (string) config('queue.connections.' . $driver . '.queue', 'default');

        $failedCount = 0;
        $pending = null;
        $oldestPendingAt = null;
        try {
            $failedCount = DB::table('failed_jobs')->count();
        } catch (\Throwable) {
            $failedCount = 0;
        }

        if ($driver === 'database') {
            try {
                $pending = DB::table(config('queue.connections.database.table', 'jobs'))->count();
                $oldest = DB::table(config('queue.connections.database.table', 'jobs'))
                    ->orderBy('id')->first();
                if ($oldest && isset($oldest->available_at)) {
                    $oldestPendingAt = now()->setTimestamp((int) $oldest->available_at)->toIso8601String();
                }
            } catch (\Throwable) {
                $pending = null;
            }
        }

        // A growing backlog with an old head job means no worker is consuming.
        $workerSuspect = $pending !== null && $pending > 0 && $oldestPendingAt !== null
            && now()->diffInMinutes(\Illuminate\Support\Carbon::parse($oldestPendingAt)) > 10;

        $status = match (true) {
            $driver === 'sync' => self::WARNING,
            $workerSuspect => self::WARNING,
            $failedCount > 0 => self::WARNING,
            default => self::HEALTHY,
        };

        $summary = match (true) {
            $driver === 'sync' => 'QUEUE_CONNECTION=sync — işler istek içinde senkron çalışıyor',
            $workerSuspect => 'Bekleyen işler var, worker çalışmıyor olabilir',
            $failedCount > 0 => $failedCount . ' başarısız iş mevcut',
            default => $driver . ' sürücüsü sağlıklı',
        };

        return [
            'status' => $status,
            'configured' => true,
            'mode' => strtoupper($driver),
            'summary' => $summary,
            'settings' => [
                'driver' => $driver,
                'default_queue' => $defaultQueue,
                'failed_driver' => (string) config('queue.failed.driver'),
            ],
            'failed_count' => $failedCount,
            'pending_count' => $pending,
            'oldest_pending_at' => $oldestPendingAt,
            'worker_suspect' => $workerSuspect,
            'last_success_at' => null,
            'last_error' => null,
        ];
    }

    /** Recent failed jobs with a SAFE exception summary (no serialized payload). */
    public function failedJobs(int $limit = 50): array
    {
        try {
            $rows = DB::table('failed_jobs')->orderByDesc('id')->limit($limit)->get();
        } catch (\Throwable) {
            return [];
        }

        return $rows->map(function ($row) {
            $payload = json_decode($row->payload ?? '{}', true) ?: [];

            return [
                'id' => $row->id,
                'uuid' => $row->uuid ?? null,
                'connection' => $row->connection ?? null,
                'queue' => $row->queue ?? null,
                'job_class' => $payload['displayName'] ?? ($payload['job'] ?? 'Bilinmeyen iş'),
                // Only the first line of the exception; never the trace or payload.
                'exception_summary' => IntegrationEvent::sanitise(
                    trim(strtok((string) ($row->exception ?? ''), "\n") ?: '')
                ),
                'failed_at' => $row->failed_at ?? null,
            ];
        })->all();
    }

    // ------------------------------------------------------------ Scheduler

    public function scheduler(): array
    {
        $heartbeat = SchedulerHeartbeat::query()
            ->where('task', SchedulerHeartbeat::TASK_SCHEDULER)->first();

        $alive = $heartbeat?->isAlive() ?? false;
        $everRan = $heartbeat?->last_success_at !== null;

        $status = match (true) {
            !$everRan => self::NOT_CONFIGURED,
            !$alive => self::ERROR,
            default => self::HEALTHY,
        };

        return [
            'status' => $status,
            'configured' => $everRan,
            'mode' => $alive ? 'RUNNING' : 'STALE',
            'summary' => match (true) {
                !$everRan => 'Scheduler hiç çalışmadı — cron `schedule:run` tanımlı değil',
                !$alive => 'Son sinyal ' . $heartbeat->last_success_at->diffForHumans() . ' — cron durmuş olabilir',
                default => 'Cron çalışıyor',
            },
            'heartbeat' => [
                'last_run_at' => $heartbeat?->last_run_at?->toIso8601String(),
                'last_success_at' => $heartbeat?->last_success_at?->toIso8601String(),
                'alive' => $alive,
            ],
            'tasks' => $this->scheduledTasks(),
            'last_success_at' => $heartbeat?->last_success_at?->toIso8601String(),
            'last_error' => null,
        ];
    }

    /** Reads the real schedule definitions registered by the framework. */
    private function scheduledTasks(): array
    {
        try {
            // Schedule definitions live in routes/console.php, which is only
            // loaded once the console kernel has bootstrapped. In an HTTP
            // request that has not happened, so bootstrap it (read-only: this
            // registers definitions, it does not run any task).
            app(\Illuminate\Contracts\Console\Kernel::class)->bootstrap();

            $schedule = app(\Illuminate\Console\Scheduling\Schedule::class);

            return collect($schedule->events())->map(fn ($event) => [
                'command' => self::prettifyCommand((string) $event->command),
                'expression' => $event->expression,
                'description' => $event->description,
                'without_overlapping' => $event->withoutOverlapping,
            ])->values()->all();
        } catch (\Throwable) {
            return [];
        }
    }

    // -------------------------------------------------------- System health

    public function systemHealth(): array
    {
        $checks = [];

        $checks[] = $this->check('PHP ' . PHP_VERSION, version_compare(PHP_VERSION, '8.2', '>='), 'PHP 8.2+ önerilir.');

        $env = app()->environment();
        $checks[] = $this->check('Ortam: ' . $env, true, null);

        $debug = (bool) config('app.debug');
        $checks[] = $this->check(
            'APP_DEBUG kapalı',
            !$debug || $env === 'local',
            $debug && $env !== 'local' ? 'KRİTİK: Üretimde APP_DEBUG açık — hata detayları sızabilir.' : null,
            $debug && $env !== 'local' ? self::ERROR : null,
        );

        $appUrl = (string) config('app.url');
        $httpsOk = str_starts_with($appUrl, 'https://') || $env === 'local';
        $checks[] = $this->check('APP_URL HTTPS', $httpsOk, $httpsOk ? null : 'Üretimde HTTPS kullanılmalı.');

        $dbOk = true;
        try {
            DB::connection()->getPdo();
        } catch (\Throwable) {
            $dbOk = false;
        }
        $checks[] = $this->check('Veritabanı bağlantısı', $dbOk, 'Veritabanına bağlanılamıyor.', $dbOk ? null : self::ERROR);

        $cacheOk = false;
        try {
            Cache::put('__integration_probe__', true, 10);
            $cacheOk = Cache::get('__integration_probe__') === true;
        } catch (\Throwable) {
            $cacheOk = false;
        }
        $checks[] = $this->check('Cache (' . config('cache.default') . ')', $cacheOk, 'Cache yazılamıyor.');

        $storageWritable = is_writable(storage_path('app'));
        $checks[] = $this->check('storage/app yazılabilir', $storageWritable, 'Yazma izni yok.');

        $checks[] = $this->check('APP_KEY tanımlı', !empty(config('app.key')), 'APP_KEY yok — şifreli ayarlar çalışmaz.',
            empty(config('app.key')) ? self::ERROR : null);

        return [
            'checks' => $checks,
            'storage' => $this->storageHealth(),
            'environment' => [
                'php_version' => PHP_VERSION,
                'laravel_version' => app()->version(),
                'environment' => $env,
                'debug' => $debug,
                'app_url' => $appUrl,
                'timezone' => config('app.timezone'),
            ],
        ];
    }

    /**
     * Public media disk health. The PRIVATE KYC disk is deliberately excluded —
     * it must never be exposed through a public-storage health indicator.
     */
    public function storageHealth(): array
    {
        $linkPath = public_path('storage');
        // is_link()/is_dir() both return false on Windows for a symlink created
        // by Git Bash, even though the link resolves and serves files fine.
        // Probe functionally instead: can the path be resolved and read?
        $linkExists = is_link($linkPath)
            || is_dir($linkPath)
            || (realpath($linkPath) !== false && is_readable($linkPath));

        $writable = is_writable(storage_path('app/public'));

        $probeUrl = null;
        try {
            $probeUrl = Storage::disk('public')->url('branding/probe.png');
        } catch (\Throwable) {
            $probeUrl = null;
        }

        return [
            'public_disk_writable' => $writable,
            'storage_link_present' => $linkExists,
            'public_url_sample' => $probeUrl,
            'private_kyc_disk' => [
                'note' => 'KYC belgeleri private diskte tutulur ve public health göstergesine dahil edilmez.',
                'writable' => is_writable(storage_path('app/private')),
            ],
        ];
    }

    // -------------------------------------------------------------- helpers

    /**
     * '"C:\php\php.exe" "D:\app\artisan" payments:reconcile' -> 'php artisan payments:reconcile'
     * Absolute paths are stripped so the panel never exposes server filesystem layout.
     */
    private static function prettifyCommand(string $command): string
    {
        if (preg_match('/artisan["\']?\s+(.+)$/i', $command, $m)) {
            return 'php artisan ' . trim($m[1], " \"'");
        }

        return trim(str_replace([base_path(), PHP_BINARY, '"', "'"], '', $command));
    }

    private function check(string $label, bool $passed, ?string $hint = null, ?string $severity = null): array
    {
        return [
            'label' => $label,
            'passed' => $passed,
            'hint' => $passed ? null : $hint,
            'severity' => $passed ? self::HEALTHY : ($severity ?? self::WARNING),
        ];
    }

    private function lastEvent(string $integration, string $status): ?IntegrationEvent
    {
        return IntegrationEvent::query()
            ->where('integration', $integration)
            ->where('status', $status)
            ->latest('occurred_at')
            ->first();
    }

    private function lastError(string $integration): ?array
    {
        $event = IntegrationEvent::query()
            ->where('integration', $integration)
            ->where('status', IntegrationEvent::STATUS_FAILED)
            ->latest('occurred_at')
            ->first();

        return $event ? [
            'message' => $event->error_message ?? $event->error_code,
            'code' => $event->error_code,
            'at' => $event->occurred_at?->toIso8601String(),
        ] : null;
    }

    /** Opens a short TCP connection to prove a service is actually listening. */
    private function probeTcp(string $host, int $port, float $timeout = 1.0): bool
    {
        if ($port <= 0) {
            return false;
        }

        try {
            $socket = @fsockopen($host, $port, $errno, $errstr, $timeout);
            if ($socket === false) {
                return false;
            }
            fclose($socket);

            return true;
        } catch (\Throwable) {
            return false;
        }
    }
}
