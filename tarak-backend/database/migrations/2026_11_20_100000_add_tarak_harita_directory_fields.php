<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('provider_profiles', function (Blueprint $table) {
            $table->string('slug', 180)->nullable()->after('business_name');
            $table->boolean('directory_listed')->default(false)->after('accepts_new_clients');
            $table->string('directory_status', 30)->default('NOT_REQUESTED')->after('directory_listed');
            $table->timestamp('directory_approved_at')->nullable()->after('directory_status');
            $table->timestamp('directory_reviewed_at')->nullable()->after('directory_approved_at');
            $table->text('directory_rejection_reason')->nullable()->after('directory_reviewed_at');
            $table->string('logo_url', 500)->nullable()->after('cover_url');
            $table->string('contact_phone', 30)->nullable()->after('gallery');
            $table->string('whatsapp_phone', 30)->nullable()->after('contact_phone');
            $table->string('instagram_handle', 100)->nullable()->after('whatsapp_phone');
            $table->string('website_url', 255)->nullable()->after('instagram_handle');
            $table->boolean('show_public_contact')->default(true)->after('website_url');

            $table->unique('slug', 'pp_slug_unique');
            $table->index(['directory_listed', 'directory_status', 'work_mode'], 'pp_directory_visibility_idx');
            $table->index(['latitude', 'longitude'], 'pp_lat_lng_idx');
        });

        Schema::create('provider_service_areas', function (Blueprint $table) {
            $table->id();
            $table->foreignId('provider_profile_id')->constrained('provider_profiles')->cascadeOnDelete();
            $table->string('province', 100);
            $table->string('district', 100);
            $table->string('neighborhood', 150)->nullable();
            $table->string('normalized_key', 255);
            $table->timestamps();

            $table->unique(['provider_profile_id', 'normalized_key'], 'psa_profile_key_unique');
            $table->index(['province', 'district'], 'psa_province_district_idx');
            $table->index('normalized_key', 'psa_normalized_key_idx');
        });

        // Backfill existing approved fixed-venue/hybrid providers into the public map directory.
        // Providers with work_mode = 'mobile' are intentionally excluded so home locations never become public pins.
        $now = now();
        $profiles = DB::table('provider_profiles')
            ->leftJoin('users', 'users.id', '=', 'provider_profiles.user_id')
            ->select([
                'provider_profiles.id',
                'provider_profiles.business_name',
                'provider_profiles.district',
                'provider_profiles.work_mode',
                'provider_profiles.is_approved',
                'provider_profiles.identity_status',
                'provider_profiles.approved_at',
                'provider_profiles.created_at',
                'provider_profiles.slug',
                'users.name as user_name',
            ])
            ->orderBy('provider_profiles.id')
            ->get();

        $usedSlugs = [];
        foreach ($profiles as $row) {
            $updates = [];

            if (empty($row->slug)) {
                $baseText = trim((string) ($row->business_name ?: ($row->user_name ?: 'isletme-' . $row->id)));
                $district = trim((string) ($row->district ?? ''));
                $baseSlug = $this->slugify(trim($baseText . ($district !== '' ? ' ' . $district : '')));
                $baseSlug = mb_substr($baseSlug, 0, 150);
                $candidate = $baseSlug;
                $suffix = 2;
                while (isset($usedSlugs[$candidate]) || DB::table('provider_profiles')->where('slug', $candidate)->where('id', '!=', $row->id)->exists()) {
                    $tag = '-' . $suffix;
                    $candidate = mb_substr($baseSlug, 0, 165 - strlen($tag)) . $tag;
                    $suffix++;
                }
                $usedSlugs[$candidate] = true;
                $updates['slug'] = $candidate;
            } else {
                $usedSlugs[$row->slug] = true;
            }

            $isApprovedVenue = (bool) $row->is_approved
                && $row->identity_status === 'APPROVED'
                && in_array($row->work_mode, ['venue', 'both'], true);

            if ($isApprovedVenue) {
                $updates['directory_listed'] = true;
                $updates['directory_status'] = 'APPROVED';
                $updates['directory_approved_at'] = $row->approved_at ?? $row->created_at ?? $now;
            }

            if ($updates !== []) {
                DB::table('provider_profiles')->where('id', $row->id)->update($updates);
            }
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('provider_service_areas');

        Schema::table('provider_profiles', function (Blueprint $table) {
            $table->dropIndex('pp_directory_visibility_idx');
            $table->dropIndex('pp_lat_lng_idx');
            $table->dropUnique('pp_slug_unique');

            $table->dropColumn([
                'slug',
                'directory_listed',
                'directory_status',
                'directory_approved_at',
                'directory_reviewed_at',
                'directory_rejection_reason',
                'logo_url',
                'contact_phone',
                'whatsapp_phone',
                'instagram_handle',
                'website_url',
                'show_public_contact',
            ]);
        });
    }

    private function slugify(string $text): string
    {
        $map = [
            'ç' => 'c', 'Ç' => 'c',
            'ğ' => 'g', 'Ğ' => 'g',
            'ı' => 'i', 'I' => 'i', 'İ' => 'i', 'i' => 'i',
            'ö' => 'o', 'Ö' => 'o',
            'ş' => 's', 'Ş' => 's',
            'ü' => 'u', 'Ü' => 'u',
        ];

        $slug = Str::slug(strtr($text, $map));

        return $slug !== '' ? $slug : 'isletme';
    }
};
