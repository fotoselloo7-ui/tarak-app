<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ProviderServiceArea extends Model
{
    use HasFactory;

    protected $fillable = [
        'provider_profile_id',
        'province',
        'district',
        'neighborhood',
        'normalized_key',
    ];

    public function providerProfile(): BelongsTo
    {
        return $this->belongsTo(ProviderProfile::class);
    }

    /**
     * Turkish-insensitive ASCII normalization matching mobile `geoKey`.
     */
    public static function normalizePart(?string $value): string
    {
        if ($value === null) {
            return '';
        }

        $map = [
            'İ' => 'i', 'I' => 'i', 'ı' => 'i', 'i' => 'i',
            'Ç' => 'c', 'ç' => 'c',
            'Ğ' => 'g', 'ğ' => 'g',
            'Ö' => 'o', 'ö' => 'o',
            'Ş' => 's', 'ş' => 's',
            'Ü' => 'u', 'ü' => 'u',
        ];

        $normalized = mb_strtolower(strtr(trim($value), $map), 'UTF-8');

        return preg_replace('/\s+/', ' ', $normalized) ?? '';
    }

    /**
     * Canonical deduplication and lookup key: `province|district|neighborhood` or `province|district|*`.
     */
    public static function makeNormalizedKey(string $province, string $district, ?string $neighborhood = null): string
    {
        $p = self::normalizePart($province);
        $d = self::normalizePart($district);
        $n = self::normalizePart($neighborhood);

        return "{$p}|{$d}|" . ($n !== '' ? $n : '*');
    }
}
