<?php

namespace App\Models;

use App\Support\MediaUrl;
use App\Support\TurkishSlug;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Facades\Schema;

class ProviderProfile extends Model
{
    use HasFactory;

    public const DIRECTORY_NOT_REQUESTED = 'NOT_REQUESTED';
    public const DIRECTORY_PENDING = 'PENDING';
    public const DIRECTORY_APPROVED = 'APPROVED';
    public const DIRECTORY_REJECTED = 'REJECTED';
    public const DIRECTORY_SUSPENDED = 'SUSPENDED';

    public const WORK_MODE_VENUE = 'venue';
    public const WORK_MODE_MOBILE = 'mobile';
    public const WORK_MODE_BOTH = 'both';

    protected $fillable = [
        'user_id',
        'provider_type',
        'work_mode',
        'business_name',
        'slug',
        'is_approved',
        'identity_status',
        'is_online',
        'accepts_new_clients',
        'directory_listed',
        'directory_status',
        'directory_approved_at',
        'directory_reviewed_at',
        'directory_rejection_reason',
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
        'logo_url',
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
        'directory_listed' => false,
        'directory_status' => self::DIRECTORY_NOT_REQUESTED,
        'show_public_contact' => true,
    ];

    protected function casts(): array
    {
        return [
            'is_approved' => 'boolean',
            'is_online' => 'boolean',
            'accepts_new_clients' => 'boolean',
            'directory_listed' => 'boolean',
            'show_public_contact' => 'boolean',
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
            'directory_approved_at' => 'datetime',
            'directory_reviewed_at' => 'datetime',
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

    public function staff(): \Illuminate\Database\Eloquent\Relations\HasMany
    {
        return $this->hasMany(ProviderStaff::class)->orderBy('sort_order')->orderBy('id');
    }

    public function activeStaff(): \Illuminate\Database\Eloquent\Relations\HasMany
    {
        return $this->staff()->where('is_active', true)->whereNull('archived_at');
    }

    public function birthdaySetting(): \Illuminate\Database\Eloquent\Relations\HasOne
    {
        return $this->hasOne(ProviderBirthdaySetting::class);
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

    public function serviceAreas(): \Illuminate\Database\Eloquent\Relations\HasMany
    {
        return $this->hasMany(ProviderServiceArea::class, 'provider_profile_id')
            ->orderBy('province')
            ->orderBy('district')
            ->orderBy('neighborhood');
    }

    /**
     * Public map pins are ONLY allowed for fixed-venue or hybrid providers with valid non-zero coordinates.
     * Mobile-only providers (`work_mode === 'mobile'`) MUST NEVER appear as public pins.
     */
    public function hasPublicVenuePin(): bool
    {
        if (! in_array($this->work_mode, [self::WORK_MODE_VENUE, self::WORK_MODE_BOTH], true)) {
            return false;
        }

        if ($this->latitude === null || $this->longitude === null) {
            return false;
        }

        $lat = (float) $this->latitude;
        $lng = (float) $this->longitude;

        return abs($lat) <= 90 && abs($lng) <= 180 && ($lat != 0.0 || $lng != 0.0);
    }

    public function isDirectoryPubliclyVisible(): bool
    {
        $user = $this->user;

        return (bool) $this->directory_listed
            && $this->directory_status === self::DIRECTORY_APPROVED
            && $user !== null
            && $user->status === 'active';
    }

    public function canAcceptTarakBookings(): bool
    {
        return (bool) $this->accepts_new_clients
            && (bool) $this->is_approved
            && $this->identity_status === 'APPROVED'
            && $this->isVerified();
    }

    public function publicFormattedAddress(): ?string
    {
        if (! $this->hasPublicVenuePin()) {
            $approx = array_filter([
                $this->district ? trim((string) $this->district) : null,
                $this->city ? trim((string) $this->city) : null,
            ]);

            return $approx !== [] ? implode(', ', $approx) : null;
        }

        $streetPart = trim(implode(' ', array_filter([
            $this->street ? trim((string) $this->street) : null,
            $this->building_no ? 'No:' . trim((string) $this->building_no) : null,
        ])));

        $parts = array_filter([
            $streetPart !== '' ? $streetPart : ($this->address_detail ? trim((string) $this->address_detail) : null),
            $this->neighborhood ? trim((string) $this->neighborhood) : null,
            $this->district ? trim((string) $this->district) : null,
            $this->city ? trim((string) $this->city) : null,
        ]);

        return $parts !== [] ? implode(', ', array_unique($parts)) : null;
    }

    public static function hasDirectorySchema(): bool
    {
        return Schema::hasColumn('provider_profiles', 'directory_listed');
    }

    public static function hasServiceAreasTable(): bool
    {
        return Schema::hasTable('provider_service_areas');
    }

    public function pinImageUrl(): ?string
    {
        $logoUrl = array_key_exists('logo_url', $this->attributes) ? $this->attributes['logo_url'] : null;

        return MediaUrl::resolve($logoUrl)
            ?: MediaUrl::resolve($this->user?->avatar_url)
            ?: MediaUrl::resolve($this->cover_url);
    }

    public function ensureSlug(): string
    {
        $existing = array_key_exists('slug', $this->attributes) ? $this->attributes['slug'] : null;
        if (is_string($existing) && trim($existing) !== '') {
            return $existing;
        }

        $base = $this->business_name ?: ($this->user?->name ?: 'isletme-' . ($this->id ?: 'yeni'));
        $slug = TurkishSlug::uniqueForProviderProfile((string) $base, $this->district, $this->exists ? (int) $this->id : null);
        $this->slug = $slug;

        return $slug;
    }

    public function scopeDirectoryListedPublic(\Illuminate\Database\Eloquent\Builder $query): \Illuminate\Database\Eloquent\Builder
    {
        if (! self::hasDirectorySchema()) {
            return $query
                ->discoverable()
                ->whereHas('user', fn ($u) => $u->where('role', User::ROLE_PROVIDER)->where('status', 'active'));
        }

        return $query
            ->where(function ($q) {
                $q->where(function ($dir) {
                    $dir->where('directory_listed', true)
                        ->where('directory_status', self::DIRECTORY_APPROVED);
                })->orWhere(function ($approved) {
                    $approved->where('is_approved', true)
                        ->where('identity_status', 'APPROVED')
                        ->where('directory_status', self::DIRECTORY_NOT_REQUESTED);
                });
            })
            ->whereHas('user', fn ($u) => $u->where('role', User::ROLE_PROVIDER)->where('status', 'active'));
    }

    public function scopeMapPinEligible(\Illuminate\Database\Eloquent\Builder $query): \Illuminate\Database\Eloquent\Builder
    {
        return $query
            ->directoryListedPublic()
            ->whereIn('work_mode', [self::WORK_MODE_VENUE, self::WORK_MODE_BOTH])
            ->whereNotNull('latitude')
            ->whereNotNull('longitude')
            ->whereBetween('latitude', [-90, 90])
            ->whereBetween('longitude', [-180, 180])
            ->where(fn ($q) => $q->where('latitude', '!=', 0)->orWhere('longitude', '!=', 0));
    }
}

