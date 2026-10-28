<?php

namespace App\Providers;

use Illuminate\Database\Events\ConnectionEstablished;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        // SQLite is used for local development and tests. Some Windows PHP builds
        // omit SQLite's optional math extension; register the same functions that
        // the production MySQL distance query uses, without opening the database
        // before artisan migrate can create it.
        Event::listen(ConnectionEstablished::class, static function (ConnectionEstablished $event): void {
            $connection = $event->connection;
            if ($connection->getDriverName() !== 'sqlite') {
                return;
            }

            $original = $connection->getRawPdo();
            $connection->setPdo(static function () use ($original): \PDO {
                $pdo = $original instanceof \Closure ? $original() : $original;
                $pdo->sqliteCreateFunction('RADIANS', static fn ($n) => deg2rad((float) $n), 1);
                $pdo->sqliteCreateFunction('SIN', static fn ($n) => sin((float) $n), 1);
                $pdo->sqliteCreateFunction('COS', static fn ($n) => cos((float) $n), 1);
                $pdo->sqliteCreateFunction('ASIN', static fn ($n) => asin((float) $n), 1);
                $pdo->sqliteCreateFunction('SQRT', static fn ($n) => sqrt((float) $n), 1);
                $pdo->sqliteCreateFunction('POWER', static fn ($base, $exponent) => pow((float) $base, (float) $exponent), 2);

                return $pdo;
            });
        });
    }
}
