<?php

namespace App\Support;

class MediaUrl
{
    private const MANAGED_PREFIXES = ['avatars/', 'provider-media/'];

    public static function resolve(?string $url): ?string
    {
        $url = trim((string) $url);
        if ($url === '') {
            return null;
        }

        if (str_starts_with($url, 'data:') || str_starts_with($url, 'blob:')) {
            return $url;
        }

        $path = parse_url($url, PHP_URL_PATH) ?: $url;
        $managedPath = self::managedPublicPath($url);
        if ($managedPath !== null) {
            return self::fromPublicPath($managedPath);
        }

        if (preg_match('#^https?://#i', $url)) {
            return $url;
        }

        $base = rtrim((string) config('app.url'), '/');
        return $base . '/' . ltrim($url, '/');
    }

    public static function fromPublicPath(string $path): string
    {
        $path = ltrim(str_replace('\\', '/', $path), '/');
        $encoded = implode('/', array_map('rawurlencode', explode('/', $path)));

        return rtrim((string) config('app.url'), '/') . '/api/media/' . $encoded;
    }

    public static function managedPublicPath(?string $url): ?string
    {
        $url = trim((string) $url);
        if ($url === '') {
            return null;
        }

        $path = parse_url($url, PHP_URL_PATH) ?: $url;
        $path = rawurldecode(str_replace('\\', '/', $path));

        if (str_starts_with($path, '/api/media/')) {
            $path = substr($path, strlen('/api/media/'));
        } elseif (str_starts_with($path, 'api/media/')) {
            $path = substr($path, strlen('api/media/'));
        } elseif (str_starts_with($path, '/storage/')) {
            $path = substr($path, strlen('/storage/'));
        } elseif (str_starts_with($path, 'storage/')) {
            $path = substr($path, strlen('storage/'));
        } else {
            return null;
        }

        $path = ltrim($path, '/');
        if ($path === '' || str_contains($path, '..')) {
            return null;
        }

        foreach (self::MANAGED_PREFIXES as $prefix) {
            if (str_starts_with($path, $prefix)) {
                return $path;
            }
        }

        return null;
    }
}
