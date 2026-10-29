<?php

namespace App\Services;

use App\Models\Appointment;
use App\Models\ProviderProfile;
use App\Models\ServiceRequest;
use App\Models\SiteContent;
use App\Models\User;
use App\Support\SiteContentDefaults;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;

/**
 * The "persuasion" numbers on the home pages (web + mobile, customer + provider).
 *
 * The admin keeps one list in site content (landing.stats). Each row can point at a
 * real platform metric and/or carry a hand-typed value; landing.stats_mode decides
 * which one the public sees:
 *   - "real":   only rows with a metric, showing the measured number (zero/empty rows are hidden)
 *   - "manual": the typed values (rows without one fall back to the real number when they have a metric)
 * When "real" leaves nothing to show (e.g. only old hand-typed rows without a metric are stored) the
 * built-in metric rows are measured instead, so the section never silently disappears.
 *
 * Demo (pre-launch preview) accounts: landing.stats_count_demo = "auto" counts them everywhere except
 * production — the same demo profiles are listed publicly, so "1 provider" next to 100 listed providers
 * would look broken — "yes" always counts them, "no" never does.
 */
class HomeStatsService
{
    /** metric key => default label shown when the admin leaves the label empty */
    public const METRICS = [
        'weekly_services' => 'Haftalık Hizmet',
        'total_services' => 'Tamamlanan Hizmet',
        'providers' => 'Doğrulanmış Hizmet Veren',
        'customers' => 'Hizmet Alan Müşteri',
        'reviews' => 'Müşteri Değerlendirmesi',
        'avg_rating' => 'Ortalama Tarak Puanı',
        'new_providers_week' => 'Bu Hafta Katılan Uzman',
        'cities' => 'Hizmet Verilen Şehir',
    ];

    public const AUDIENCES = ['all', 'customer', 'provider'];
    private const MAX_ITEMS = 6;

    public const DEMO_MODES = ['auto', 'yes', 'no'];

    /** Measured values, cached for a minute so a busy home page never runs the counts per request. */
    public function metrics(bool $includeDemo = false): array
    {
        return Cache::remember('home_stats_metrics:' . ($includeDemo ? 'demo' : 'real'), 60, fn () => $this->measure($includeDemo));
    }

    private function includeDemo(array $landing): bool
    {
        // Seed accounts are customer-facing production content; is_demo is retained
        // only as an internal admin purge marker.
        return true;
    }

    /**
     * @return array{mode: string, items: list<array<string, mixed>>}
     */
    public function resolve(string $audience = 'all'): array
    {
        $audience = in_array($audience, self::AUDIENCES, true) ? $audience : 'all';
        $content = SiteContent::query()->oldest('id')->first()?->content ?? [];
        $landing = array_replace(SiteContentDefaults::landing(), $content['landing'] ?? []);

        $mode = ($landing['stats_mode'] ?? 'real') === 'manual' ? 'manual' : 'real';
        $includeDemo = $this->includeDemo($landing);
        $metrics = $this->metrics($includeDemo);

        $stored = $landing['stats'] ?? [];
        $items = $this->buildItems($stored, $mode, $audience, $metrics, $includeDemo);
        // Only hand-typed rows left over from before the metrics existed: show the built-in measured rows
        // instead of an empty section. An admin who switched every row off (or removed them) keeps it hidden.
        $hasActiveRow = collect($stored)->contains(fn ($row) => is_array($row) && ($row['is_active'] ?? true) !== false);
        if ($items === [] && $mode === 'real' && $hasActiveRow) {
            $items = $this->buildItems(SiteContentDefaults::landing()['stats'], 'real', $audience, $metrics, $includeDemo);
        }

        return ['mode' => $mode, 'items' => $items];
    }

    /**
     * @param  array<int, mixed>  $stored
     * @param  array<string, int|float|null>  $metrics
     * @return list<array<string, mixed>>
     */
    private function buildItems(array $stored, string $mode, string $audience, array $metrics, bool $includeDemo): array
    {
        $rows = collect($stored)
            ->filter(fn ($row) => is_array($row) && ($row['is_active'] ?? true) !== false)
            ->filter(fn ($row) => in_array($row['audience'] ?? 'all', array_unique(['all', $audience]), true))
            ->sortBy(fn ($row) => (int) ($row['order'] ?? 0))
            ->values();

        $items = [];
        foreach ($rows as $index => $row) {
            $metric = isset($row['metric']) && isset(self::METRICS[$row['metric']]) ? $row['metric'] : null;
            $typed = trim((string) ($row['value'] ?? ''));
            $label = trim((string) ($row['label'] ?? '')) ?: ($metric ? self::METRICS[$metric] : '');
            if ($label === '') {
                continue;
            }

            $real = $metric !== null ? ($metrics[$metric] ?? null) : null;
            $hasReal = $real !== null && (float) $real > 0;

            if ($mode === 'manual' && $typed !== '') {
                $value = $typed;
                $isFake = true;
            } elseif ($metric !== null && $hasReal) {
                $value = $this->format($metric, (float) $real);
                $isFake = false;
            } else {
                continue; // nothing true (or typed) to show for this row
            }

            $items[] = [
                'key' => $metric ?? ('custom_' . $index),
                'metric' => $metric,
                'label' => $label,
                'desc' => (($row['desc'] ?? null) ?: null),
                'value' => $value,
                'is_fake' => $isFake,
                'includes_demo' => false,
            ];
            if (count($items) >= self::MAX_ITEMS) {
                break;
            }
        }

        return $items;
    }

    private function format(string $metric, float $value): string
    {
        if ($metric === 'avg_rating') {
            return number_format($value, 1, ',', '.');
        }

        return number_format((int) round($value), 0, ',', '.');
    }

    /** @return array<string, int|float|null> */
    private function measure(bool $includeDemo): array
    {
        $weekAgo = now()->subDays(7);
        $listed = fn () => ProviderProfile::query()->publiclyListed()
            ->when(!$includeDemo, fn ($q) => $q->whereHas('user', fn ($u) => $u->where('is_demo', false)));

        $completed = fn (string $model, ?\Carbon\CarbonInterface $since) => $model::query()
            ->where('status', 'COMPLETED')
            ->when($since, fn ($q) => $q->where('completed_at', '>=', $since))
            ->count();

        $reviews = DB::table('provider_reviews')
            ->join('users', 'users.id', '=', 'provider_reviews.provider_user_id')
            ->join('users as review_customers', 'review_customers.id', '=', 'provider_reviews.customer_user_id')
            ->when(!$includeDemo, fn ($q) => $q->where('users.is_demo', false)->where('review_customers.is_demo', false));
        $reviewCount = (clone $reviews)->count();

        return [
            'weekly_services' => $completed(ServiceRequest::class, $weekAgo) + $completed(Appointment::class, $weekAgo),
            'total_services' => $completed(ServiceRequest::class, null) + $completed(Appointment::class, null),
            'providers' => $listed()->count(),
            'customers' => User::query()->where('role', User::ROLE_CUSTOMER)->where('status', 'active')
                ->when(!$includeDemo, fn ($q) => $q->where('is_demo', false))->count(),
            'reviews' => $reviewCount,
            'avg_rating' => $reviewCount > 0 ? round((float) (clone $reviews)->avg('provider_reviews.rating'), 1) : null,
            'new_providers_week' => $listed()->where('approved_at', '>=', $weekAgo)->count(),
            'cities' => $listed()->whereNotNull('city')->where('city', '!=', '')->distinct()->count('city'),
        ];
    }
}
