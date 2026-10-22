<?php

namespace App\Console\Commands;

use App\Services\DemoDataException;
use App\Services\DemoDataService;
use Illuminate\Console\Command;

class DemoSeedCommand extends Command
{
    protected $signature = 'demo:seed {--customers=100 : Number of demo customers} {--providers=100 : Number of demo providers} {--fresh : Delete existing demo data first}';
    protected $description = 'Generate the demo (pre-launch preview) customers, providers, galleries and reviews';

    public function handle(DemoDataService $demo): int
    {
        try {
            if ($this->option('fresh') && $demo->exists()) {
                $removed = $demo->purge();
                $this->info("Önceki demo veri silindi ({$removed['customers']} müşteri, {$removed['providers']} hizmet veren).");
            }
            $stats = $demo->generate((int) $this->option('customers'), (int) $this->option('providers'));
        } catch (DemoDataException $e) {
            $this->error($e->getMessage());

            return self::FAILURE;
        }

        $this->info(sprintf(
            'Demo veri hazır: %d müşteri, %d hizmet veren, %d yorum, %d galeri görseli.',
            $stats['customers'],
            $stats['providers'],
            $stats['reviews'],
            $stats['gallery_images']
        ));
        if (array_sum($stats['pack']) === 0) {
            $this->warn('Fotoğraf paketi boş: ' . $stats['pack_path'] . ' — profiller yer tutucu avatarla oluşturuldu, galeriler boş.');
        }

        return self::SUCCESS;
    }
}
