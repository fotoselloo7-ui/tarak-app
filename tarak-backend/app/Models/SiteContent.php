<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class SiteContent extends Model
{
    protected $table = 'site_contents';

    protected $fillable = [
        'content',
        'updated_by',
    ];

    protected function casts(): array
    {
        return [
            'content' => 'array',
        ];
    }

    /**
     * The single content row, whatever its actual id happens to be.
     *
     * Deliberately NOT hardcoded to id=1: MySQL/InnoDB auto_increment is not
     * transactional, so a rolled-back insert (e.g. in tests, or an aborted
     * request) permanently advances the counter — a later firstOrCreate(['id'
     * => 1]) would then create a SECOND row instead of finding the first,
     * silently orphaning it. Always resolve the oldest existing row instead.
     */
    public static function current(): self
    {
        return self::query()->oldest('id')->first() ?? self::create(['content' => []]);
    }
}
