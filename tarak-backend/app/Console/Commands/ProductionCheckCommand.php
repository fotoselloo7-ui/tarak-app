<?php

namespace App\Console\Commands;

use App\Models\User;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\File;

class ProductionCheckCommand extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'app:production-check {--strict : Enforce strict production environment}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Audit environment and system configuration for production readiness';

    protected int $passCount = 0;
    protected int $warnCount = 0;
    protected int $failCount = 0;

    /**
     * Execute the console command.
     */
    public function handle(): int
    {
        $this->info('========================================');
        $this->info(' Tarak Production Readiness Check');
        $this->info('========================================');

        $this->checkEnvironment();
        $this->checkDebugMode();
        $this->checkAppKey();
        $this->checkAppUrl();
        $this->checkDatabase();
        $this->checkQueueConnection();
        $this->checkReverbConfig();
        $this->checkPaytrConfig();
        $this->checkFcmConfig();
        $this->checkStoragePermissions();
        $this->checkMigrations();
        $this->checkDemoData();
        $this->checkFrontendUrl();

        $this->newLine();
        $this->info("Summary: {$this->passCount} PASSED, {$this->warnCount} WARNINGS, {$this->failCount} FAILED");

        if ($this->failCount > 0) {
            $this->error('Production check FAILED! Fix the critical issues above before deploying to production.');
            return Command::FAILURE;
        }

        if ($this->warnCount > 0) {
            $this->warn('Production check passed with warnings.');
        } else {
            $this->info('Production check PASSED! System is ready for live production.');
        }

        return Command::SUCCESS;
    }

    protected function checkDemoData(): void
    {
        try {
            $count = User::withTrashed()->where('is_demo', true)->count();
        } catch (\Throwable) {
            return; // column not migrated yet; the migrations check reports that
        }

        if ($count === 0) {
            $this->pass('Demo (ön izleme) hesabı bulunmuyor.');

            return;
        }

        $message = "{$count} demo hesap var. Canlıya almadan önce `php artisan demo:purge` çalıştırın (veya Admin > Demo Veriler > Tümünü Sil).";
        app()->environment('production') ? $this->failMessage($message) : $this->warnMessage($message);
    }

    protected function pass(string $message): void
    {
        $this->passCount++;
        $this->line("<fg=green>PASS:</> {$message}");
    }

    protected function warnMessage(string $message): void
    {
        $this->warnCount++;
        $this->line("<fg=yellow>WARN:</> {$message}");
    }

    protected function failMessage(string $message): void
    {
        $this->failCount++;
        $this->line("<fg=red>FAIL:</> {$message}");
    }

    protected function checkEnvironment(): void
    {
        $env = (string) config('app.env');
        if ($env === 'production') {
            $this->pass('APP_ENV is production');
        } else {
            $this->failMessage("APP_ENV must be production (current: {$env})");
        }
    }

    protected function checkDebugMode(): void
    {
        $debug = (bool) config('app.debug');
        if (!$debug) {
            $this->pass('APP_DEBUG disabled');
        } else {
            $this->failMessage('APP_DEBUG must be false in production');
        }
    }

    protected function checkAppKey(): void
    {
        $key = (string) config('app.key');
        if (!empty($key) && str_starts_with($key, 'base64:')) {
            $this->pass('APP_KEY configured');
        } elseif (!empty($key)) {
            $this->pass('APP_KEY configured');
        } else {
            $this->failMessage('APP_KEY missing');
        }
    }

    protected function checkAppUrl(): void
    {
        $url = (string) config('app.url');
        if (empty($url)) {
            $this->failMessage('APP_URL missing');
        } elseif (str_starts_with(strtolower($url), 'https://')) {
            $this->pass('APP_URL uses HTTPS');
        } else {
            $this->failMessage("APP_URL must use HTTPS in production (configured: {$url})");
        }
    }

    protected function checkDatabase(): void
    {
        $connection = (string) config('database.default');
        try {
            DB::connection()->getPdo();
            $this->pass("Database connection successful ({$connection})");
        } catch (\Throwable $e) {
            $this->failMessage('Database connection failed');
        }
    }

    protected function checkQueueConnection(): void
    {
        $queue = (string) config('queue.default');
        if ($queue === 'sync') {
            $this->failMessage('QUEUE_CONNECTION cannot be sync in production (must be database, redis, etc.)');
        } else {
            $this->pass("QUEUE_CONNECTION configured ({$queue})");
        }
    }

    protected function checkReverbConfig(): void
    {
        $scheme = (string) config('reverb.apps.apps.0.options.scheme', env('REVERB_SCHEME', 'http'));
        if (strtolower($scheme) === 'https') {
            $this->pass('Reverb production scheme is https (wss)');
        } else {
            $this->failMessage("Reverb scheme must be https (wss) in production (current: {$scheme})");
        }

        $origins = config('reverb.apps.apps.0.allowed_origins');
        if (!is_array($origins)) {
            $rawOrigins = env('REVERB_ALLOWED_ORIGINS');
            $origins = $rawOrigins ? explode(',', $rawOrigins) : [];
        }

        $hasWildcard = false;
        foreach ($origins as $origin) {
            if (trim((string) $origin) === '*' || str_contains((string) $origin, '*')) {
                $hasWildcard = true;
                break;
            }
        }

        if ($hasWildcard) {
            $this->failMessage('Reverb allowed origins cannot contain wildcard (*) in production');
        } elseif (empty($origins)) {
            $this->warnMessage('Reverb allowed origins is empty');
        } else {
            $this->pass('Reverb allowed origins configured without wildcards');
        }

        $appKey = (string) config('reverb.apps.apps.0.key', env('REVERB_APP_KEY'));
        $appSecret = (string) config('reverb.apps.apps.0.secret', env('REVERB_APP_SECRET'));
        $appId = (string) config('reverb.apps.apps.0.app_id', env('REVERB_APP_ID'));

        if (!empty($appKey) && !empty($appSecret) && !empty($appId)) {
            $this->pass('Reverb application credentials configured');
        } else {
            $this->failMessage('Reverb application credentials missing');
        }
    }

    protected function checkPaytrConfig(): void
    {
        $merchantId = (string) config('paytr.merchant_id');
        $merchantKey = (string) config('paytr.merchant_key');
        $merchantSalt = (string) config('paytr.merchant_salt');

        if (empty($merchantId) || empty($merchantKey) || empty($merchantSalt)) {
            $this->failMessage('PAYTR credentials missing (merchant_id, merchant_key, or merchant_salt)');
        } else {
            $this->pass('PAYTR credentials configured');
        }

        $testMode = (int) config('paytr.test_mode', 1);
        if ($testMode === 1) {
            $this->warnMessage('PAYTR_TEST_MODE is enabled (test mode active)');
        } else {
            $this->pass('PAYTR_TEST_MODE disabled (live mode)');
        }
    }

    protected function checkFcmConfig(): void
    {
        $fcmEnabled = (bool) config('fcm.enabled', false);
        if (!$fcmEnabled) {
            $this->pass('FCM push notifications disabled (credentials check skipped)');
            return;
        }

        $projectId = (string) config('fcm.project_id');
        $credentialsPath = (string) config('fcm.credentials_path');

        if (empty($projectId)) {
            $this->failMessage('FCM_PROJECT_ID missing while FCM is enabled');
            return;
        }

        if (empty($credentialsPath)) {
            $this->failMessage('GOOGLE_APPLICATION_CREDENTIALS path missing while FCM is enabled');
            return;
        }

        if (!File::exists($credentialsPath) || !File::isReadable($credentialsPath)) {
            $this->failMessage('FCM service account credentials file missing or unreadable');
            return;
        }

        $this->pass('FCM configuration and service account file valid');
    }

    protected function checkStoragePermissions(): void
    {
        $dirs = [
            storage_path(),
            storage_path('framework/cache'),
            storage_path('framework/views'),
            storage_path('framework/sessions'),
            storage_path('logs'),
            storage_path('app/private'),
            base_path('bootstrap/cache'),
        ];

        $allWritable = true;
        foreach ($dirs as $dir) {
            if (!File::exists($dir)) {
                File::makeDirectory($dir, 0755, true, true);
            }
            if (!is_writable($dir)) {
                $allWritable = false;
                break;
            }
        }

        if ($allWritable) {
            $this->pass('Storage and cache directories are writable');
        } else {
            $this->failMessage('Storage and cache directories are not writable');
        }
    }

    protected function checkMigrations(): void
    {
        try {
            $migrator = app('migrator');
            $files = $migrator->getMigrationFiles($migrator->paths());
            $ran = $migrator->getRepository()->getRan();
            $pending = array_diff(array_keys($files), $ran);

            if (count($pending) > 0) {
                $this->failMessage('Pending database migrations found (' . count($pending) . ' unapplied)');
            } else {
                $this->pass('Database schema is up to date (no pending migrations)');
            }
        } catch (\Throwable $e) {
            $this->warnMessage('Could not verify migrations status: ' . $e->getMessage());
        }
    }

    protected function checkFrontendUrl(): void
    {
        $origins = config('cors.allowed_origins');
        if (empty($origins) || !is_array($origins)) {
            $frontendUrl = (string) env('FRONTEND_URL', '');
            $origins = array_filter(array_map('trim', explode(',', $frontendUrl)));
        }

        if (empty($origins)) {
            $this->warnMessage('FRONTEND_URL not set in environment');
            return;
        }
        $hasLocalhost = false;
        $hasWildcard = false;

        foreach ($origins as $origin) {
            if ($origin === '*' || str_contains($origin, '*')) {
                $hasWildcard = true;
            }
            if (str_contains($origin, 'localhost') || str_contains($origin, '127.0.0.1') || str_contains($origin, '10.0.2.2')) {
                $hasLocalhost = true;
            }
        }

        if ($hasWildcard) {
            $this->failMessage('FRONTEND_URL cannot contain wildcard (*) in production');
        } elseif ($hasLocalhost) {
            $this->failMessage('FRONTEND_URL cannot point to localhost/127.0.0.1 in production');
        } else {
            $this->pass('FRONTEND_URL configured for production');
        }
    }
}
