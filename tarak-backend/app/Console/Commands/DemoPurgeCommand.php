<?php

namespace App\Console\Commands;

use App\Services\DemoDataService;
use Illuminate\Console\Command;

class DemoPurgeCommand extends Command
{
    protected $signature = 'demo:purge {--force : Do not ask for confirmation}';
    protected $description = 'Delete ALL demo customers, providers, reviews and demo images (run before going live)';

    public function handle(DemoDataService $demo): int
    {
        $stats = $demo->stats();
        if ($stats['customers'] + $stats['providers'] === 0) {
            $this->info('Silinecek demo veri yok.');

            return self::SUCCESS;
        }

        if (!$this->option('force') && !$this->confirm("{$stats['customers']} demo müşteri, {$stats['providers']} demo hizmet veren ve {$stats['reviews']} yorum silinecek. Devam edilsin mi?")) {
            return self::FAILURE;
        }

        $removed = $demo->purge();
        $this->info("Silindi: {$removed['customers']} müşteri, {$removed['providers']} hizmet veren, {$removed['reviews']} yorum.");

        return self::SUCCESS;
    }
}
