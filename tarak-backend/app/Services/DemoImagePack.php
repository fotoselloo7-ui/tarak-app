<?php

namespace App\Services;

use Illuminate\Support\Facades\Storage;

/**
 * Photo source for the demo data set.
 *
 * Photos come from a local "pack" folder (storage/app/demo-pack):
 *   portraits/women, portraits/men   -> profile pictures
 *   works/women,     works/men       -> work gallery / cover pictures
 * Files are copied once into a shared pool on the public disk (demo/pool/...),
 * so many profiles can reference the same file without duplicating it. When the
 * pack is empty a neutral head-and-shoulders placeholder avatar is generated.
 *
 * All demo files live under `demo/` on the public disk (and `demo/` on the
 * private disk for the document placeholder) so a purge removes them in one go.
 */
class DemoImagePack
{
    public const DIR = 'demo';
    private const EXT = ['jpg', 'jpeg', 'png', 'webp'];
    private const PALETTE = [
        [94, 109, 140], [140, 110, 94], [100, 135, 120], [150, 115, 135], [118, 120, 160],
        [160, 130, 100], [105, 140, 150], [140, 125, 150], [125, 145, 110], [150, 120, 120],
    ];

    public function packPath(): string
    {
        $pack = storage_path('app/demo-pack');
        if (is_dir($pack)) {
            return $pack;
        }

        // The published source archive already contains the original demo
        // portraits and covers. Reuse them for local previews only.
        $bundled = base_path('../tarak.app/demo-media/pool');
        if (app()->environment('local') && is_dir($bundled)) {
            return $bundled;
        }

        return $pack;
    }

    /** @return array{portraits_women:int, portraits_men:int, works_women:int, works_men:int} */
    public function inventory(): array
    {
        return [
            'portraits_women' => count($this->files('portraits/women')),
            'portraits_men' => count($this->files('portraits/men')),
            'works_women' => count($this->files('works/women')),
            'works_men' => count($this->files('works/men')),
        ];
    }

    public function hasPortraits(): bool
    {
        $inv = $this->inventory();

        return $inv['portraits_women'] > 0 && $inv['portraits_men'] > 0;
    }

    /** Public URLs of the pack portraits for "women" | "men" (copied into the shared pool once). */
    public function portraitUrls(string $group): array
    {
        return $this->poolUrls('portraits/' . $group);
    }

    /** Public URLs of the pack work photos for "women" | "men". */
    public function workUrls(string $group): array
    {
        return $this->poolUrls('works/' . $group);
    }

    /** Public URLs of the wide (landscape) work photos for "women" | "men": they fit a cover banner without cropping a face to a sliver. */
    public function coverUrls(string $group): array
    {
        $disk = Storage::disk('public');
        $urls = [];
        foreach ($this->files('works/' . $group) as $file) {
            $size = @getimagesize($file);
            if (!$size || $size[0] < $size[1] * 1.3) {
                continue;
            }
            $target = self::DIR . '/pool/works/' . $group . '/' . basename($file);
            if (!$disk->exists($target)) {
                $disk->put($target, (string) file_get_contents($file));
            }
            $urls[] = $disk->url($target);
        }

        return $urls;
    }

    /** A generated head-and-shoulders avatar (used when no portrait pack exists). */
    public function placeholderAvatarUrl(int $seed): string
    {
        $path = self::DIR . '/avatars/placeholder-' . ($seed % 100000) . '.png';
        $disk = Storage::disk('public');
        if (!$disk->exists($path)) {
            $disk->put($path, $this->renderAvatar($seed));
        }

        return $disk->url($path);
    }

    /** Shared placeholder for demo KYC documents on the private disk. */
    public function documentPlaceholderPath(): string
    {
        $path = self::DIR . '/documents/demo-belge.png';
        $disk = Storage::disk('local');
        if (!$disk->exists($path)) {
            $disk->put($path, $this->renderDocument());
        }

        return $path;
    }

    public function documentPlaceholderSize(): int
    {
        return (int) Storage::disk('local')->size($this->documentPlaceholderPath());
    }

    /** Removes every demo file from both disks. */
    public function purgeFiles(): void
    {
        Storage::disk('public')->deleteDirectory(self::DIR);
        Storage::disk('local')->deleteDirectory(self::DIR);
    }

    /** @return list<string> */
    private function files(string $relative): array
    {
        $dir = $this->packPath() . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, $relative);
        if (!is_dir($dir)) {
            return [];
        }
        $found = [];
        foreach (scandir($dir) ?: [] as $name) {
            if (in_array(strtolower(pathinfo($name, PATHINFO_EXTENSION)), self::EXT, true) && is_file($dir . DIRECTORY_SEPARATOR . $name)) {
                $found[] = $dir . DIRECTORY_SEPARATOR . $name;
            }
        }
        sort($found);

        return $found;
    }

    /** @return list<string> */
    private function poolUrls(string $relative): array
    {
        $disk = Storage::disk('public');
        $urls = [];
        foreach ($this->files($relative) as $file) {
            $target = self::DIR . '/pool/' . $relative . '/' . basename($file);
            if (!$disk->exists($target)) {
                $disk->put($target, (string) file_get_contents($file));
            }
            $urls[] = $disk->url($target);
        }

        return $urls;
    }

    private function renderAvatar(int $seed): string
    {
        $size = 512;
        [$r, $g, $b] = self::PALETTE[$seed % count(self::PALETTE)];
        $img = imagecreatetruecolor($size, $size);
        imagefilledrectangle($img, 0, 0, $size, $size, imagecolorallocate($img, $r, $g, $b));
        $light = imagecolorallocate($img, min(255, $r + 70), min(255, $g + 70), min(255, $b + 70));
        imagefilledellipse($img, (int) ($size / 2), (int) ($size * 0.40), (int) ($size * 0.34), (int) ($size * 0.34), $light);
        imagefilledellipse($img, (int) ($size / 2), (int) ($size * 0.98), (int) ($size * 0.78), (int) ($size * 0.62), $light);

        $out = imagecreatetruecolor(256, 256);
        imagecopyresampled($out, $img, 0, 0, 0, 0, 256, 256, $size, $size);
        ob_start();
        imagepng($out);
        $bytes = (string) ob_get_clean();
        imagedestroy($img);
        imagedestroy($out);

        return $bytes;
    }

    private function renderDocument(): string
    {
        $img = imagecreatetruecolor(480, 640);
        imagefilledrectangle($img, 0, 0, 480, 640, imagecolorallocate($img, 250, 250, 247));
        $ink = imagecolorallocate($img, 120, 120, 125);
        imagerectangle($img, 20, 20, 459, 619, $ink);
        imagestring($img, 5, 150, 70, 'DEMO BELGE', imagecolorallocate($img, 90, 90, 100));
        for ($y = 150; $y < 560; $y += 36) {
            imagefilledrectangle($img, 60, $y, 420, $y + 6, imagecolorallocate($img, 220, 220, 224));
        }
        ob_start();
        imagepng($img);
        $bytes = (string) ob_get_clean();
        imagedestroy($img);

        return $bytes;
    }
}
