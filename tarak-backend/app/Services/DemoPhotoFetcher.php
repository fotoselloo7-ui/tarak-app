<?php

namespace App\Services;

use Illuminate\Support\Facades\Process;

/** Where demo photos come from (search + download); the real one talks to Pexels. */
interface DemoPhotoSource
{
    /** @return list<array<string, mixed>> raw photo rows (id, width, height, alt, url, photographer, photographer_url, src.large) */
    public function search(string $query, int $page, int $perPage): array;

    public function download(string $url, string $path): bool;
}

/**
 * Pexels (https://www.pexels.com/api/) via the system `curl` binary.
 * Photos are free to use under the Pexels licence; credits are still recorded.
 * The API key is only held in memory for the run.
 */
class PexelsPhotoSource implements DemoPhotoSource
{
    public function __construct(private string $apiKey)
    {
    }

    public function search(string $query, int $page, int $perPage): array
    {
        $url = 'https://api.pexels.com/v1/search?' . http_build_query([
            'query' => $query,
            'page' => $page,
            'per_page' => $perPage,
            'size' => 'medium',
        ]);
        $result = Process::timeout(60)->run(['curl', '-sS', '-L', '-H', 'Authorization: ' . $this->apiKey, $url]);
        if (!$result->successful()) {
            throw new DemoDataException('Pexels isteği başarısız: ' . trim($result->errorOutput()));
        }
        $json = json_decode($result->output(), true);
        if (!is_array($json) || !isset($json['photos'])) {
            $reason = is_array($json) ? ($json['error'] ?? 'beklenmeyen yanıt') : 'geçersiz yanıt';
            throw new DemoDataException('Pexels yanıtı alınamadı (' . $reason . '). API anahtarını kontrol edin.');
        }

        return $json['photos'];
    }

    public function download(string $url, string $path): bool
    {
        $result = Process::timeout(120)->run(['curl', '-sS', '-L', '-f', '-o', $path, $url]);

        return $result->successful() && is_file($path) && filesize($path) > 2048;
    }
}

/**
 * Fills the demo photo pack (storage/app/demo-pack) with free stock photos:
 * portraits for profile pictures and hair/beard/beauty work photos for galleries.
 */
class DemoPhotoFetcher
{
    /** Search plan per pack folder. */
    public const PLAN = [
        'portraits/women' => [
            'target' => 100,
            'portrait_only' => true,
            'queries' => ['beautiful woman portrait smiling', 'young woman portrait natural light', 'elegant woman headshot', 'stylish woman portrait', 'woman face portrait studio'],
        ],
        'portraits/men' => [
            'target' => 100,
            'portrait_only' => true,
            'queries' => ['handsome man portrait', 'young man portrait beard', 'man portrait smiling', 'stylish man headshot', 'man face portrait natural light'],
        ],
        'works/women' => [
            'target' => 150,
            'portrait_only' => false,
            'queries' => ['women hairstyle salon', 'balayage hair color', 'bridal hairstyle updo', 'blowout hair styling', 'woman haircut bob', 'long wavy hairstyle', 'manicure nails salon', 'hair braid style', 'makeup artist bride'],
        ],
        'works/men' => [
            'target' => 150,
            'portrait_only' => false,
            'queries' => ['men haircut fade', 'barber shop haircut', 'beard trim barber', 'men hairstyle pompadour', 'barber straight razor shave', 'mens short haircut', 'beard styling'],
        ],
    ];

    /** Portrait pictures must not show children, aprons or workwear. */
    private const PORTRAIT_BLOCKLIST = '/\b(child|children|kid|kids|baby|toddler|boy|girl|teen|apron|barber|hairdresser|chef|worker|uniform|nurse|doctor)\b/i';
    private const PER_PAGE = 40;
    private const MAX_PAGES = 5;

    public function __construct(private DemoImagePack $pack)
    {
    }

    /**
     * @param array<string, int> $targets optional override: folder => target count
     * @return array{downloaded: array<string, int>, skipped: int}
     */
    public function fetch(DemoPhotoSource $source, array $targets = [], ?callable $progress = null): array
    {
        $root = $this->pack->packPath();
        $seen = [];
        $credits = [];
        $summary = ['downloaded' => [], 'skipped' => 0];

        foreach (self::PLAN as $folder => $plan) {
            $dir = $root . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, $folder);
            if (!is_dir($dir)) {
                mkdir($dir, 0777, true);
            }
            $target = $targets[$folder] ?? $plan['target'];
            $have = count(glob($dir . DIRECTORY_SEPARATOR . '*.jpg') ?: []);
            $summary['downloaded'][$folder] = 0;

            for ($page = 1; $page <= self::MAX_PAGES && $have < $target; $page++) {
                foreach ($plan['queries'] as $query) {
                    if ($have >= $target) {
                        break;
                    }
                    foreach ($source->search($query, $page, self::PER_PAGE) as $photo) {
                        if ($have >= $target) {
                            break;
                        }
                        $id = (string) ($photo['id'] ?? '');
                        $url = $photo['src']['large'] ?? null;
                        if ($id === '' || !$url || isset($seen[$id]) || !$this->acceptable($photo, $plan['portrait_only'])) {
                            $summary['skipped']++;
                            continue;
                        }
                        $seen[$id] = true;
                        $file = $dir . DIRECTORY_SEPARATOR . $id . '.jpg';
                        if (!is_file($file) && !$source->download($url, $file)) {
                            @unlink($file);
                            $summary['skipped']++;
                            continue;
                        }
                        $have++;
                        $summary['downloaded'][$folder]++;
                        $credits[$folder . '/' . $id . '.jpg'] = [
                            'photographer' => $photo['photographer'] ?? null,
                            'photographer_url' => $photo['photographer_url'] ?? null,
                            'source' => $photo['url'] ?? null,
                            'query' => $query,
                        ];
                        if ($progress) {
                            $progress($folder, $have, $target);
                        }
                    }
                }
            }
        }

        $this->writeCredits($root, $credits);

        return $summary;
    }

    /** @param array<string, mixed> $photo */
    private function acceptable(array $photo, bool $portraitOnly): bool
    {
        $w = (int) ($photo['width'] ?? 0);
        $h = (int) ($photo['height'] ?? 0);
        if ($w < 400 || $h < 400) {
            return false;
        }
        if ($portraitOnly) {
            if ($h < $w * 0.95) {
                return false; // landscape shots crop badly into round avatars
            }
            if (preg_match(self::PORTRAIT_BLOCKLIST, (string) ($photo['alt'] ?? ''))) {
                return false;
            }
        }

        return true;
    }

    /** @param array<string, array<string, mixed>> $credits */
    private function writeCredits(string $root, array $credits): void
    {
        if (!$credits) {
            return;
        }
        $path = $root . DIRECTORY_SEPARATOR . 'credits.json';
        $existing = is_file($path) ? (json_decode((string) file_get_contents($path), true) ?: []) : [];
        file_put_contents($path, json_encode($existing + $credits, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES));
    }
}
