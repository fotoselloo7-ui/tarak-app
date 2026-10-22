<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\SiteContent;
use App\Services\HomeStatsService;
use App\Support\SiteContentDefaults;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

class SiteContentController extends Controller
{
    private const MAX_CONTENT_BYTES = 200_000;

    /** Branding image "types" this endpoint accepts, mapped to their content.branding/seo key. */
    private const BRANDING_TYPES = [
        'logo' => ['group' => 'branding', 'field' => 'logo_url'],
        'logo_dark' => ['group' => 'branding', 'field' => 'logo_dark_url'],
        'favicon' => ['group' => 'branding', 'field' => 'favicon_url'],
        'hero_image' => ['group' => 'branding', 'field' => 'hero_image_url'],
        'og_image' => ['group' => 'seo', 'field' => 'og_image_url'],
    ];

    private const BRANDING_MAX_KB = 2048; // 2MB

    /**
     * Public marketing + legal content. Launch-ready defaults (legal texts,
     * store links) are merged UNDER any admin-managed overrides so public
     * pages are never empty before customisation.
     */
    public function show(): JsonResponse
    {
        $stored = SiteContent::query()->oldest('id')->first()?->content ?? [];
        $content = self::withDefaults($stored);

        return response()->json([
            'success' => true,
            'data' => (object) $content,
        ]);
    }

    /**
     * Admin content laid over the launch defaults. A homepage-section list the admin saved
     * before a new section existed is completed with the new keys (placed after the section
     * that precedes them by default), so new sections show up in the panel and in both apps.
     */
    private static function withDefaults(array $stored): array
    {
        $defaults = SiteContentDefaults::all();
        $merged = self::deepMerge($defaults, $stored);

        $sections = $merged['home']['sections'] ?? [];
        $present = array_column($sections, 'key');
        $defaultKeys = array_column($defaults['home']['sections'], 'key');
        foreach ($defaultKeys as $position => $key) {
            if (in_array($key, $present, true)) {
                continue;
            }
            $previous = $position > 0 ? $defaultKeys[$position - 1] : null;
            $at = $previous !== null ? array_search($previous, array_column($sections, 'key'), true) : false;
            $entry = ['key' => $key, 'is_active' => true, 'order' => 0];
            array_splice($sections, $at === false ? count($sections) : $at + 1, 0, [$entry]);
            $present = array_column($sections, 'key');
        }
        foreach ($sections as $index => &$section) {
            $section['order'] = $index + 1;
        }
        unset($section);
        $merged['home']['sections'] = array_values($sections);

        return $merged;
    }

    /**
     * Merge $override recursively over $base (associative arrays only).
     */
    private static function deepMerge(array $base, array $override): array
    {
        foreach ($override as $key => $value) {
            if (is_array($value) && isset($base[$key]) && is_array($base[$key])
                && array_keys($value) !== range(0, count($value) - 1)) {
                $base[$key] = self::deepMerge($base[$key], $value);
            } else {
                $base[$key] = $value;
            }
        }

        return $base;
    }

    /**
     * Protected: ADMIN only.
     */
    public function update(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'content' => ['required', 'array'],
            'content.landing' => ['sometimes', 'array'],
            'content.landing.stats' => ['sometimes', 'array', 'max:8'],
            // A row needs a typed value OR a real metric to read from (see HomeStatsService).
            'content.landing.stats.*.value' => ['nullable', 'string', 'max:40', 'required_without:content.landing.stats.*.metric'],
            'content.landing.stats.*.label' => ['required_with:content.landing.stats', 'string', 'max:80'],
            'content.landing.stats.*.desc' => ['nullable', 'string', 'max:120'],
            'content.landing.stats.*.metric' => ['nullable', 'string', Rule::in(array_keys(HomeStatsService::METRICS))],
            'content.landing.stats.*.audience' => ['sometimes', 'nullable', 'string', Rule::in(HomeStatsService::AUDIENCES)],
            'content.landing.stats_mode' => ['sometimes', 'string', 'in:real,manual'],
            'content.landing.stats_count_demo' => ['sometimes', 'string', Rule::in(HomeStatsService::DEMO_MODES)],
            'content.landing.featured_providers' => ['sometimes', 'array', 'max:12'],
            'content.landing.featured_providers.*.name' => ['required_with:content.landing.featured_providers', 'string', 'max:80'],
            'content.landing.featured_providers.*.role' => ['nullable', 'string', 'max:60'],
            'content.landing.featured_providers.*.city' => ['nullable', 'string', 'max:60'],
            'content.landing.featured_providers.*.rating' => ['nullable', 'numeric', 'min:0', 'max:5'],
            'content.landing.featured_providers.*.reviews' => ['nullable', 'integer', 'min:0'],
            'content.landing.featured_providers.*.services' => ['nullable', 'string', 'max:40'],
            'content.landing.featured_providers.*.photo_url' => ['nullable', 'string', 'max:500', 'regex:/^(https:\/\/|\/)/'],
            'content.landing.featured_providers.*.provider_id' => ['nullable', 'string', 'max:64'],
            // Legal documents (public pages).
            'content.legal' => ['sometimes', 'array'],
            'content.legal.privacy.title' => ['sometimes', 'string', 'max:120'],
            'content.legal.privacy.body' => ['sometimes', 'string', 'max:40000'],
            'content.legal.privacy.updated_at' => ['sometimes', 'string', 'max:40'],
            'content.legal.kvkk.title' => ['sometimes', 'string', 'max:120'],
            'content.legal.kvkk.body' => ['sometimes', 'string', 'max:40000'],
            'content.legal.kvkk.updated_at' => ['sometimes', 'string', 'max:40'],
            'content.legal.terms.title' => ['sometimes', 'string', 'max:120'],
            'content.legal.terms.body' => ['sometimes', 'string', 'max:40000'],
            'content.legal.terms.updated_at' => ['sometimes', 'string', 'max:40'],
            'content.legal.cookies.title' => ['sometimes', 'string', 'max:120'],
            'content.legal.cookies.body' => ['sometimes', 'string', 'max:40000'],
            'content.legal.cookies.updated_at' => ['sometimes', 'string', 'max:40'],
            // App configuration (store links, support email).
            'content.config' => ['sometimes', 'array'],
            'content.config.app_store_url' => ['sometimes', 'nullable', 'string', 'max:500', 'regex:/^(https:\/\/.*)?$/'],
            'content.config.play_store_url' => ['sometimes', 'nullable', 'string', 'max:500', 'regex:/^(https:\/\/.*)?$/'],
            'content.config.support_email' => ['sometimes', 'nullable', 'email', 'max:120'],
            // Home verification / trust section (shared with mobile).
            'content.home' => ['sometimes', 'array'],
            'content.home.verification' => ['sometimes', 'array'],
            'content.home.verification.eyebrow' => ['sometimes', 'string', 'max:120'],
            'content.home.verification.title' => ['sometimes', 'string', 'max:160'],
            'content.home.verification.subtitle' => ['sometimes', 'string', 'max:500'],
            'content.home.verification.cards' => ['sometimes', 'array', 'max:8'],
            'content.home.verification.cards.*.icon' => ['sometimes', 'string', 'max:40'],
            'content.home.verification.cards.*.title' => ['required_with:content.home.verification.cards', 'string', 'max:120'],
            'content.home.verification.cards.*.desc' => ['nullable', 'string', 'max:240'],
            // Homepage section visibility + order (shared by web & mobile).
            'content.home.sections' => ['sometimes', 'array', 'max:20'],
            'content.home.sections.*.key' => ['required_with:content.home.sections', 'string', 'max:40'],
            'content.home.sections.*.is_active' => ['sometimes', 'boolean'],
            'content.home.sections.*.order' => ['sometimes', 'integer', 'min:0', 'max:100'],
            // Hero CTA labels (copy only — destinations stay in app routing).
            'content.landing.hero.badge' => ['sometimes', 'nullable', 'string', 'max:160'],
            'content.landing.hero.title_prefix' => ['sometimes', 'nullable', 'string', 'max:120'],
            'content.landing.hero.title_highlight' => ['sometimes', 'nullable', 'string', 'max:120'],
            'content.landing.hero.description' => ['sometimes', 'nullable', 'string', 'max:600'],
            'content.landing.hero.cta_primary' => ['sometimes', 'nullable', 'string', 'max:60'],
            'content.landing.hero.cta_primary_desc' => ['sometimes', 'nullable', 'string', 'max:120'],
            'content.landing.hero.cta_secondary' => ['sometimes', 'nullable', 'string', 'max:60'],
            'content.landing.hero.cta_secondary_desc' => ['sometimes', 'nullable', 'string', 'max:120'],
            // Per-stat visibility/order (value/label/desc validated above).
            'content.landing.stats.*.is_active' => ['sometimes', 'boolean'],
            'content.landing.stats.*.order' => ['sometimes', 'integer', 'min:0', 'max:50'],
            // "Nasıl Çalışır?" steps.
            'content.home.how_it_works' => ['sometimes', 'array'],
            'content.home.how_it_works.eyebrow' => ['sometimes', 'nullable', 'string', 'max:80'],
            'content.home.how_it_works.title' => ['sometimes', 'nullable', 'string', 'max:160'],
            'content.home.how_it_works.subtitle' => ['sometimes', 'nullable', 'string', 'max:300'],
            'content.home.how_it_works.steps' => ['sometimes', 'array', 'max:8'],
            'content.home.how_it_works.steps.*.title' => ['required_with:content.home.how_it_works.steps', 'string', 'max:120'],
            'content.home.how_it_works.steps.*.desc' => ['nullable', 'string', 'max:240'],
            // Service categories section — presentation only, never the records.
            'content.home.categories' => ['sometimes', 'array'],
            'content.home.categories.eyebrow' => ['sometimes', 'nullable', 'string', 'max:80'],
            'content.home.categories.title' => ['sometimes', 'nullable', 'string', 'max:160'],
            'content.home.categories.subtitle' => ['sometimes', 'nullable', 'string', 'max:300'],
            'content.home.categories.limit' => ['sometimes', 'integer', 'min:1', 'max:12'],
            // Featured provider section + selection strategy.
            'content.home.providers' => ['sometimes', 'array'],
            'content.home.providers.eyebrow' => ['sometimes', 'nullable', 'string', 'max:80'],
            'content.home.providers.title' => ['sometimes', 'nullable', 'string', 'max:160'],
            'content.home.providers.subtitle' => ['sometimes', 'nullable', 'string', 'max:300'],
            'content.home.providers.mode' => ['sometimes', 'string', 'in:auto,selected'],
            'content.home.providers.limit' => ['sometimes', 'integer', 'min:1', 'max:20'],
            // Paid "öne çıkarma" section + newest providers section.
            'content.home.spotlight' => ['sometimes', 'array'],
            'content.home.spotlight.eyebrow' => ['sometimes', 'nullable', 'string', 'max:80'],
            'content.home.spotlight.title' => ['sometimes', 'nullable', 'string', 'max:160'],
            'content.home.spotlight.subtitle' => ['sometimes', 'nullable', 'string', 'max:300'],
            'content.home.spotlight.rotate_seconds' => ['sometimes', 'integer', 'min:3', 'max:120'],
            'content.home.newest' => ['sometimes', 'array'],
            'content.home.newest.eyebrow' => ['sometimes', 'nullable', 'string', 'max:80'],
            'content.home.newest.title' => ['sometimes', 'nullable', 'string', 'max:160'],
            'content.home.newest.subtitle' => ['sometimes', 'nullable', 'string', 'max:300'],
            'content.home.newest.limit' => ['sometimes', 'integer', 'min:1', 'max:20'],
            // Provider recruitment banner.
            'content.home.provider_cta' => ['sometimes', 'array'],
            'content.home.provider_cta.eyebrow' => ['sometimes', 'nullable', 'string', 'max:80'],
            'content.home.provider_cta.title' => ['sometimes', 'nullable', 'string', 'max:160'],
            'content.home.provider_cta.subtitle' => ['sometimes', 'nullable', 'string', 'max:500'],
            'content.home.provider_cta.cta_label' => ['sometimes', 'nullable', 'string', 'max:60'],
            // Mobile app download banner.
            'content.home.app_download' => ['sometimes', 'array'],
            'content.home.app_download.eyebrow' => ['sometimes', 'nullable', 'string', 'max:80'],
            'content.home.app_download.title' => ['sometimes', 'nullable', 'string', 'max:80'],
            'content.home.app_download.title_highlight' => ['sometimes', 'nullable', 'string', 'max:80'],
            'content.home.app_download.subtitle' => ['sometimes', 'nullable', 'string', 'max:300'],
            // General identity / contact / footer copy.
            'content.general' => ['sometimes', 'array'],
            'content.general.site_name' => ['sometimes', 'nullable', 'string', 'max:80'],
            'content.general.brand_name' => ['sometimes', 'nullable', 'string', 'max:80'],
            'content.general.slogan' => ['sometimes', 'nullable', 'string', 'max:120'],
            'content.general.description' => ['sometimes', 'nullable', 'string', 'max:500'],
            'content.general.footer_description' => ['sometimes', 'nullable', 'string', 'max:500'],
            'content.general.company_name' => ['sometimes', 'nullable', 'string', 'max:160'],
            'content.general.address' => ['sometimes', 'nullable', 'string', 'max:300'],
            'content.general.city' => ['sometimes', 'nullable', 'string', 'max:60'],
            'content.general.district' => ['sometimes', 'nullable', 'string', 'max:60'],
            'content.general.working_hours' => ['sometimes', 'nullable', 'string', 'max:80'],
            'content.general.support_hours' => ['sometimes', 'nullable', 'string', 'max:80'],
            // Extra contact channels alongside the existing support_email.
            'content.config.support_phone' => ['sometimes', 'nullable', 'string', 'max:30'],
            'content.config.whatsapp_number' => ['sometimes', 'nullable', 'string', 'max:30'],
            // Social profile links.
            'content.social' => ['sometimes', 'array'],
            'content.social.instagram' => ['sometimes', 'nullable', 'string', 'max:200'],
            'content.social.facebook' => ['sometimes', 'nullable', 'string', 'max:200'],
            'content.social.x' => ['sometimes', 'nullable', 'string', 'max:200'],
            'content.social.youtube' => ['sometimes', 'nullable', 'string', 'max:200'],
            'content.social.linkedin' => ['sometimes', 'nullable', 'string', 'max:200'],
            'content.social.tiktok' => ['sometimes', 'nullable', 'string', 'max:200'],
            // Homepage + core-branding SEO only.
            'content.seo' => ['sometimes', 'array'],
            'content.seo.site_title' => ['sometimes', 'nullable', 'string', 'max:80'],
            'content.seo.meta_description' => ['sometimes', 'nullable', 'string', 'max:300'],
            'content.seo.og_title' => ['sometimes', 'nullable', 'string', 'max:80'],
            'content.seo.og_description' => ['sometimes', 'nullable', 'string', 'max:300'],
            'content.seo.canonical_url' => ['sometimes', 'nullable', 'string', 'max:300'],
            'content.seo.robots_index' => ['sometimes', 'boolean'],
            'content.seo.robots_follow' => ['sometimes', 'boolean'],
            // Branding image URLs are normally written by uploadBrandingImage(); validated
            // here too so a manual save can never persist something other than a real URL.
            'content.branding' => ['sometimes', 'array'],
            'content.branding.logo_url' => ['sometimes', 'nullable', 'string', 'max:500', 'regex:/^(https:\/\/|\/)/'],
            'content.branding.logo_dark_url' => ['sometimes', 'nullable', 'string', 'max:500', 'regex:/^(https:\/\/|\/)/'],
            'content.branding.favicon_url' => ['sometimes', 'nullable', 'string', 'max:500', 'regex:/^(https:\/\/|\/)/'],
            'content.branding.hero_image_url' => ['sometimes', 'nullable', 'string', 'max:500', 'regex:/^(https:\/\/|\/)/'],
            'content.seo.og_image_url' => ['sometimes', 'nullable', 'string', 'max:500', 'regex:/^(https:\/\/|\/)/'],
        ], [
            'content.required' => 'İçerik zorunludur.',
            'content.landing.featured_providers.*.photo_url.regex' => 'Fotoğraf adresi https:// veya / ile başlamalıdır.',
        ]);

        if (strlen(json_encode($validated['content'])) > self::MAX_CONTENT_BYTES) {
            return response()->json(['success' => false, 'message' => 'İçerik çok büyük.'], 422);
        }

        $site = SiteContent::current();
        $site->update([
            'content' => $request->input('content'),
            'updated_by' => $request->user()->id,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Site içeriği güncellendi.',
            'data' => (object) $site->content,
        ]);
    }

    /**
     * Protected: ADMIN only. Uploads a brand image (logo / favicon / OG image)
     * to the PUBLIC disk under a managed "branding/" prefix — never the private
     * KYC storage — and writes its URL straight into the singleton site content.
     */
    public function uploadBrandingImage(Request $request, string $type): JsonResponse
    {
        if (!isset(self::BRANDING_TYPES[$type])) {
            return response()->json(['success' => false, 'message' => 'Geçersiz görsel türü.'], 404);
        }

        $isFavicon = $type === 'favicon';
        $request->validate([
            'image' => [
                'required',
                'file',
                $isFavicon ? 'mimes:png,ico,jpg,jpeg,webp,svg' : 'mimes:png,jpg,jpeg,webp,svg',
                'max:' . self::BRANDING_MAX_KB,
            ],
        ], [
            'image.required' => 'Lütfen bir görsel seçiniz.',
            'image.mimes' => 'Desteklenmeyen dosya formatı.',
            'image.max' => 'Görsel boyutu en fazla ' . (self::BRANDING_MAX_KB / 1024) . ' MB olabilir.',
        ]);

        ['group' => $group, 'field' => $field] = self::BRANDING_TYPES[$type];

        $file = $request->file('image');
        $extension = strtolower($file->getClientOriginalExtension() ?: $file->extension());
        $filename = (string) Str::uuid() . '.' . $extension;
        $path = $file->storeAs('branding/' . $type, $filename, 'public');
        $url = Storage::disk('public')->url($path);

        $site = SiteContent::current();
        $content = $site->content ?? [];
        $oldPath = self::managedBrandingPath($content[$group][$field] ?? null);
        $content[$group] = array_merge($content[$group] ?? [], [$field => $url]);

        $site->update(['content' => $content, 'updated_by' => $request->user()->id]);

        if ($oldPath && $oldPath !== $path) {
            Storage::disk('public')->delete($oldPath);
        }

        $merged = self::withDefaults($content);

        return response()->json([
            'success' => true,
            'message' => 'Görsel güncellendi.',
            'data' => (object) $merged,
        ]);
    }

    /**
     * Protected: ADMIN only. Removes a brand image and reverts the field to
     * empty (callers fall back to the built-in icon+text mark).
     */
    public function deleteBrandingImage(Request $request, string $type): JsonResponse
    {
        if (!isset(self::BRANDING_TYPES[$type])) {
            return response()->json(['success' => false, 'message' => 'Geçersiz görsel türü.'], 404);
        }

        ['group' => $group, 'field' => $field] = self::BRANDING_TYPES[$type];

        $site = SiteContent::current();
        $content = $site->content ?? [];
        $oldPath = self::managedBrandingPath($content[$group][$field] ?? null);
        $content[$group] = array_merge($content[$group] ?? [], [$field => '']);

        $site->update(['content' => $content, 'updated_by' => $request->user()->id]);

        if ($oldPath) {
            Storage::disk('public')->delete($oldPath);
        }

        $merged = self::withDefaults($content);

        return response()->json([
            'success' => true,
            'message' => 'Görsel kaldırıldı.',
            'data' => (object) $merged,
        ]);
    }

    /**
     * Resolves $url to a disk-relative path IF AND ONLY IF it points into the
     * "branding/" folder we manage on the public disk. Mirrors
     * ProfileMediaController::managedPublicPath's arbitrary-path safety, scoped
     * to brand assets so this controller never deletes a file it doesn't own.
     */
    private static function managedBrandingPath(?string $url): ?string
    {
        if (!$url) {
            return null;
        }
        $base = rtrim(Storage::disk('public')->url(''), '/') . '/';
        if (!str_starts_with($url, $base)) {
            return null;
        }
        $path = substr($url, strlen($base));
        if (!str_starts_with($path, 'branding/')) {
            return null;
        }

        return $path;
    }
}
