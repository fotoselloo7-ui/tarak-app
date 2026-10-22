<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * Admin-managed integration credential/toggle.
 *
 * `value` is ENCRYPTED at rest (Laravel Crypt / APP_KEY). Secret values must
 * never leave the backend — read them through IntegrationSettings, and expose
 * only masked/boolean "configured" indicators to the API.
 */
class IntegrationSetting extends Model
{
    protected $table = 'integration_settings';

    protected $fillable = [
        'group',
        'key',
        'value',
        'is_secret',
        'updated_by',
    ];

    protected function casts(): array
    {
        return [
            'value' => 'encrypted',
            'is_secret' => 'boolean',
        ];
    }
}
