<?php

namespace App\Console\Commands;

use App\Services\DemoDataException;
use App\Services\DemoPhotoFetcher;
use App\Services\PexelsPhotoSource;
use Illuminate\Console\Command;

class DemoFetchPhotosCommand extends Command
{
    protected $signature = 'demo:fetch-photos
        {--key= : Pexels API key (or set PEXELS_API_KEY). Free at https://www.pexels.com/api/ — never stored}
        {--portraits=100 : Portraits per gender (profile pictures)}
        {--works=150 : Work photos per gender (galleries)}
        {--dry-run : Only print the plan}';
    protected $description = 'Download free stock photos (Pexels) into the demo photo pack used by demo:seed';

    public function handle(DemoPhotoFetcher $fetcher): int
    {
        $targets = [
            'portraits/women' => (int) $this->option('portraits'),
            'portraits/men' => (int) $this->option('portraits'),
            'works/women' => (int) $this->option('works'),
            'works/men' => (int) $this->option('works'),
        ];

        if ($this->option('dry-run')) {
            $this->table(['Klasör', 'Hedef', 'Arama sorguları'], collect(DemoPhotoFetcher::PLAN)->map(
                fn ($plan, $folder) => [$folder, $targets[$folder], implode(' | ', $plan['queries'])]
            )->values()->all());
            $this->line('Toplam ' . array_sum($targets) . ' görsel; ortalama 80-150 KB (yaklaşık ' . round(array_sum($targets) * 0.115) . ' MB). Kaynak: pexels.com (Pexels Lisansı).');

            return self::SUCCESS;
        }

        $key = (string) ($this->option('key') ?: env('PEXELS_API_KEY', ''));
        if ($key === '') {
            $this->error('Pexels API anahtarı gerekli: --key=... ya da PEXELS_API_KEY. Ücretsiz anahtar: https://www.pexels.com/api/');

            return self::FAILURE;
        }

        $bar = null;
        try {
            $summary = $fetcher->fetch(new PexelsPhotoSource($key), $targets, function (string $folder, int $have, int $target) use (&$bar) {
                $this->output->write("\r{$folder}: {$have}/{$target}   ");
            });
        } catch (DemoDataException $e) {
            $this->newLine();
            $this->error($e->getMessage());

            return self::FAILURE;
        }

        $this->newLine();
        $this->info('İndirilen: ' . json_encode($summary['downloaded']) . ' — atlanan: ' . $summary['skipped']);
        $this->line('Krediler credits.json dosyasına yazıldı. Şimdi `php artisan demo:seed --fresh` ile profilleri yeniden oluşturun.');

        return self::SUCCESS;
    }
}
