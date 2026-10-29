<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ProviderProfile extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'provider_type',
        'work_mode',
        'business_name',
        'is_approved',
        'identity_status',
        'is_online',
        'accepts_new_clients',
        'service_radius_km',
        'experience_years',
        'profile_completed',
        'city',
        'district',
        'neighborhood',
        'street',
        'building_no',
        'address_detail',
        'bio',
        'title',
        'cover_url',
        'cover_position_x',
        'cover_position_y',
        'gallery',
        'commission_rate_override',
        'approved_at',
        'reviewed_at',
        'rejection_reason',
        'reupload_reason',
        'has_received_welcome_bonus',
        'payment_reference',
        'latitude',
        'longitude',
    ];

    protected $attributes = [
        'has_received_welcome_bonus' => false,
    ];

    protected function casts(): array
    {
        return [
            'is_approved' => 'boolean',
            'is_online' => 'boolean',
            'accepts_new_clients' => 'boolean',
            'service_radius_km' => 'integer',
            'experience_years' => 'integer',
            'profile_completed' => 'boolean',
            'cover_position_x' => 'integer',
            'cover_position_y' => 'integer',
            'gallery' => 'array',
            'commission_rate_override' => 'decimal:2',
            'has_received_welcome_bonus' => 'boolean',
            'latitude' => 'float',
            'longitude' => 'float',
            'approved_at' => 'datetime',
            'reviewed_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function services(): \Illuminate\Database\Eloquent\Relations\BelongsToMany
    {
        return $this->belongsToMany(Service::class, 'provider_services')
            ->withPivot('id', 'custom_price', 'custom_duration_minutes', 'description', 'is_active')
            ->withTimestamps();
    }

    public function providerServices(): \Illuminate\Database\Eloquent\Relations\HasMany
    {
        return $this->hasMany(ProviderService::class);
    }

    public function packages(): \Illuminate\Database\Eloquent\Relations\HasMany
    {
        return $this->hasMany(ProviderPackage::class)->orderBy('sort_order')->orderBy('id');
    }

    public function documents(): \Illuminate\Database\Eloquent\Relations\HasMany
    {
        return $this->hasMany(ProviderDocument::class);
    }

    /**
     * Checks if provider has at least one approved vocational qualification document.
     */
    public function hasApprovedDocument(): bool
    {
        return $this->documents()
            ->where('status', ProviderDocument::STATUS_APPROVED)
            ->whereIn('document_type', [
                ProviderDocument::TYPE_DIPLOMA,
                ProviderDocument::TYPE_MASTER_CERTIFICATE,
                ProviderDocument::TYPE_JOURNEYMAN_CERTIFICATE,
            ])
            ->exists();
    }

    /**
     * Public verified badge derivation:
     * is_approved === true AND identity_status === APPROVED AND en az bir APPROVED mesleki belge varsa
     */
    public function isVerified(): bool
    {
        // Demo documents are placeholders, never evidence of a real identity review.
        if ($this->user?->is_demo) {
            return false;
        }

        if (! $this->is_approved || $this->identity_status !== 'APPROVED') {
            return false;
        }

        // Lists that eager-load `documents` get the answer without a query per provider.
        if ($this->relationLoaded('documents')) {
            return $this->documents->contains(fn ($d) => $d->status === ProviderDocument::STATUS_APPROVED
                && in_array($d->document_type, [
                    ProviderDocument::TYPE_DIPLOMA,
                    ProviderDocument::TYPE_MASTER_CERTIFICATE,
                    ProviderDocument::TYPE_JOURNEYMAN_CERTIFICATE,
                ], true));
        }

        return $this->hasApprovedDocument();
    }

    /**
     * Profiles that may appear in the general provider directory. Approval and
     * identity review are required; the blue verification tick is still reserved
     * for profiles with an approved vocational document via isVerified().
     */
    public function scopeDiscoverable(\Illuminate\Database\Eloquent\Builder $query): \Illuminate\Database\Eloquent\Builder
    {
        return $query
            ->where('is_approved', true)
            ->where('identity_status', 'APPROVED');
    }

    /**
     * Profiles used by explicitly verified-only surfaces.
     */
    public function scopePubliclyListed(\Illuminate\Database\Eloquent\Builder $query): \Illuminate\Database\Eloquent\Builder
    {
        return $query
            ->where('is_approved', true)
            ->where('identity_status', 'APPROVED')
            ->whereHas('documents', fn ($q) => $q->where('status', ProviderDocument::STATUS_APPROVED));
    }

    public function adminLogs(): \Illuminate\Database\Eloquent\Relations\HasMany
    {
        return $this->hasMany(AdminLog::class, 'target_id')
            ->where('target_type', AdminLog::TARGET_PROVIDER);
    }

    public function weeklySchedules(): \Illuminate\Database\Eloquent\Relations\HasMany
    {
        return $this->hasMany(ProviderWeeklySchedule::class, 'provider_profile_id');
    }

    public function closedDates(): \Illuminate\Database\Eloquent\Relations\HasMany
    {
        return $this->hasMany(ProviderClosedDate::class, 'provider_profile_id');
    }
}

