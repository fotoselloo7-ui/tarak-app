<?php

namespace Tests;

use Illuminate\Foundation\Testing\TestCase as BaseTestCase;

abstract class TestCase extends BaseTestCase
{
    public function createApplication()
    {
        // `artisan test` inherits .env values in $_SERVER. PHPUnit's <env
        // force="true"> updates getenv/$_ENV but leaves those server values
        // intact, and Dotenv prefers $_SERVER. Force all sources before boot
        // so RefreshDatabase can never migrate or clear a saved database.
        foreach ([
            'APP_ENV' => 'testing',
            'APP_CONFIG_CACHE' => dirname(__DIR__) . '/bootstrap/cache/test-only-never-cached.php',
            'APP_KEY' => 'base64:MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=',
            'DB_CONNECTION' => 'sqlite',
            'DB_DATABASE' => ':memory:',
            'DB_URL' => '',
            'CACHE_STORE' => 'array',
            'SESSION_DRIVER' => 'array',
            'QUEUE_CONNECTION' => 'sync',
            'MAIL_MAILER' => 'array',
            'BCRYPT_ROUNDS' => '4',
        ] as $name => $value) {
            putenv("{$name}={$value}");
            $_ENV[$name] = $value;
            $_SERVER[$name] = $value;
        }

        $app = parent::createApplication();

        // Build a new in-memory schema without ever running migrate:fresh or seeds.
        // RefreshDatabase then reuses this PDO and rolls each test back.
        if (isset($this->traitsUsedByTest[\Illuminate\Foundation\Testing\RefreshDatabase::class])
            && !\Illuminate\Foundation\Testing\RefreshDatabaseState::$migrated) {
            if ($app['config']['database.default'] !== 'sqlite'
                || $app['config']['database.connections.sqlite.database'] !== ':memory:') {
                throw new \RuntimeException('Auth tests may only migrate an in-memory database.');
            }
            if ($app->make(\Illuminate\Contracts\Console\Kernel::class)->call('migrate', ['--force' => true]) !== 0) {
                throw new \RuntimeException('In-memory test migrations failed.');
            }
            \Illuminate\Foundation\Testing\RefreshDatabaseState::$inMemoryConnections['sqlite'] = $app['db']->connection()->getPdo();
            \Illuminate\Foundation\Testing\RefreshDatabaseState::$migrated = true;
        }

        return $app;
    }

    protected function setUp(): void
    {
        parent::setUp();
        // Keep production file-backed rate counters out of isolated tests.
        $this->app->instance(\Illuminate\Cache\RateLimiter::class,
            new \Illuminate\Cache\RateLimiter($this->app['cache']->store('array')));
    }
}
