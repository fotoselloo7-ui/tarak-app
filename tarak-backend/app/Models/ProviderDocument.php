<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ProviderDocument extends Model
{
    use HasFactory;

    public const STATUS_PENDING = 'PENDING';
    public const STATUS_APPROVED = 'APPROVED';
    public const STATUS_REJECTED = 'REJECTED';
    public const STATUS_REUPLOAD_REQUIRED = 'REUPLOAD_REQUIRED';

    public const TYPE_DIPLOMA = 'DIPLOMA';
    public const TYPE_MASTER_CERTIFICATE = 'MASTER_CERTIFICATE';
    public const TYPE_JOURNEYMAN_CERTIFICATE = 'JOURNEYMAN_CERTIFICATE';

    protected $fillable = [
        'provider_profile_id',
        'document_type',
        'original_name',
        'storage_path',
        'mime_type',
        'file_size',
        'status',
        'rejection_reason',
        'uploaded_at',
        'reviewed_at',
    ];

    protected function casts(): array
    {
        return [
            'file_size' => 'integer',
            'uploaded_at' => 'datetime',
            'reviewed_at' => 'datetime',
        ];
    }

    public function providerProfile(): BelongsTo
    {
        return $this->belongsTo(ProviderProfile::class);
    }
}
