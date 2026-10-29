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

        return self::baseUrl() . '/' . ltrim($url, '/');
    }

    public static function fromPublicPath(string $path): string
    {
        $path = ltrim(str_replace('\\', '/', $path), '/');
        $encoded = implode('/', array_map('rawurlencode', explode('/', $path)));

        return self::baseUrl() . '/api/media/' . $encoded;
    }

    private static function baseUrl(): string
    {
        if (!app()->runningInConsole()) {
            try {
                $request = request();
                $host = $request->getSchemeAndHttpHost();
                if ($host !== '') {
                    return rtrim($host, '/');
                }
            } catch (\Throwable) {
                // Fall through to APP_URL for non-HTTP contexts.
            }
        }

        return rtrim((string) config('app.url'), '/');
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
        } elseif (str_starts_with($path, 'avatars/') || str_starts_with($path, 'provider-media/')) {
            // Older mobile uploads stored the public disk path without /storage/.
            // Normalize those known managed folders for every web/app avatar.
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
