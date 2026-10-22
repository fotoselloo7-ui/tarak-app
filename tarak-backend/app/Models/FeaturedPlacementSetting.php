<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * Admin controls of one "öne çıkarma" placement: whether new purchases are open, how many
 * sponsored slots a list shows and how many seconds they stay before the set changes (listing), and the copy providers read.
 */
class FeaturedPlacementSetting extends Model
{
    protected $fillable = ['placement', 'is_enabled', 'slots', 'rotation_seconds', 'title', 'description'];

    protected function casts(): array
    {
        return [
            'is_enabled' => 'boolean',
            'slots' => 'integer',
            'rotation_seconds' => 'integer',
        ];
    }

    /** Settings row of a placement (created from sane defaults if the table was emptied). */
    public static function for(string $placement): self
    {
        return self::query()->firstOrCreate(['placement' => $placement], match ($placement) {
            FeaturedPromotion::PLACEMENT_LISTING => ['is_enabled' => true, 'slots' => 3, 'rotation_seconds' => 20, 'title' => 'Liste Reklamı', 'description' => null],
            default => ['is_enabled' => true, 'slots' => 6, 'rotation_seconds' => 0, 'title' => 'Ana Sayfa Vitrini', 'description' => null],
        });
    }

    public function present(): array
    {
        return [
            'placement' => $this->placement,
            'is_enabled' => $this->is_enabled,
            'slots' => $this->slots,
            'rotation_seconds' => $this->rotation_seconds,
            'title' => $this->title,
            'description' => $this->description,
        ];
    }
}
