<?php

namespace App\Support;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * Generates clean ASCII SEO slugs from Turkish business names and districts,
 * ensuring uniqueness against `provider_profiles.slug`.
 */
final class TurkishSlug
{
    public static function transliterate(string $text): string
    {
        $map = [
            'ç' => 'c', 'Ç' => 'c',
            'ğ' => 'g', 'Ğ' => 'g',
            'ı' => 'i', 'I' => 'i', 'İ' => 'i', 'i' => 'i',
            'ö' => 'o', 'Ö' => 'o',
            'ş' => 's', 'Ş' => 's',
            'ü' => 'u', 'Ü' => 'u',
        ];

        $replaced = strtr(trim($text), $map);
        $slug = Str::slug($replaced);

        return $slug !== '' ? $slug : 'isletme';
    }

    public static function uniqueForProviderProfile(
        string $baseText,
        ?string $district = null,
        ?int $ignoreProfileId = null,
    ): string {
        $parts = array_filter([trim($baseText), $district ? trim($district) : null], fn ($v) => $v !== null && $v !== '');
        $base = self::transliterate(implode(' ', $parts) ?: 'isletme');
        $base = mb_substr($base, 0, 150);

        $candidate = $base;
        $suffix = 2;

        while (self::slugExists($candidate, $ignoreProfileId)) {
            $tag = '-' . $suffix;
            $candidate = mb_substr($base, 0, 165 - strlen($tag)) . $tag;
            $suffix++;
        }

        return $candidate;
    }

    private static function slugExists(string $slug, ?int $ignoreProfileId): bool
    {
        return DB::table('provider_profiles')
            ->where('slug', $slug)
            ->when($ignoreProfileId !== null, fn ($q) => $q->where('id', '!=', $ignoreProfileId))
            ->exists();
    }
}
