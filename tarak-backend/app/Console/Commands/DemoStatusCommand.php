<?php

namespace App\Console\Commands;

use App\Services\DemoDataService;
use Illuminate\Console\Command;

class DemoStatusCommand extends Command
{
    protected $signature = 'demo:status';
    protected $description = 'Show how much demo data exists and which demo photos are available';

    public function handle(DemoDataService $demo): int
    {
        $stats = $demo->stats();
        $this->table(['Kalem', 'Adet'], [
            ['Demo müşteri', $stats['customers']],
            ['Demo hizmet veren', $stats['providers']],
            ['Demo yorum', $stats['reviews']],
            ['Galeri görseli', $stats['gallery_images']],
            ['Paket: kadın portre', $stats['pack']['portraits_women']],
            ['Paket: erkek portre', $stats['pack']['portraits_men']],
            ['Paket: kadın iş fotoğrafı', $stats['pack']['works_women']],
            ['Paket: erkek iş fotoğrafı', $stats['pack']['works_men']],
        ]);
        $this->line('Fotoğraf paketi klasörü: ' . $stats['pack_path']);

        return self::SUCCESS;
    }
}
