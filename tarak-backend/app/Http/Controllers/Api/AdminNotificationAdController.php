<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AdminLog;
use App\Models\NotificationAd;
use App\Models\NotificationAdSetting;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/** Admin side of "bildirim reklamı": prices per audience, discount limits, anti-spam caps, and what was sent. */
class AdminNotificationAdController extends Controller
{
    public function settings(): JsonResponse
    {
        return response()->json(['success' => true, 'data' => NotificationAdSetting::current()->presentForAdmin()]);
    }

    public function updateSettings(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'is_enabled' => ['sometimes', 'boolean'],
            'title' => ['sometimes', 'string', 'min:2', 'max:120'],
            'description' => ['sometimes', 'nullable', 'string', 'max:1000'],
            'price_service_area' => ['sometimes', 'numeric', 'min:0', 'max:1000000'],
            'price_location' => ['sometimes', 'numeric', 'min:0', 'max:1000000'],
            'price_all' => ['sometimes', 'numeric', 'min:0', 'max:1000000'],
            'min_discount_percent' => ['sometimes', 'integer', 'min:1', 'max:99'],
            'max_discount_percent' => ['sometimes', 'integer', 'min:1', 'max:99'],
            'max_discount_days' => ['sometimes', 'integer', 'min:1', 'max:365'],
            'max_sends_per_provider_per_day' => ['sometimes', 'integer', 'min:1', 'max:50'],
            'max_per_customer_per_day' => ['sometimes', 'integer', 'min:1', 'max:20'],
        ], [
            'title.min' => 'Başlık en az 2 karakter olmalı.',
            'price_service_area.numeric' => 'Fiyat sayı olmalı.',
            'price_location.numeric' => 'Fiyat sayı olmalı.',
            'price_all.numeric' => 'Fiyat sayı olmalı.',
        ]);

        $settings = NotificationAdSetting::current();
        $min = $validated['min_discount_percent'] ?? $settings->min_discount_percent;
        $max = $validated['max_discount_percent'] ?? $settings->max_discount_percent;
        if ($min > $max) {
            return response()->json(['success' => false, 'message' => 'En düşük indirim oranı en yüksekten büyük olamaz.', 'errors' => ['min_discount_percent' => ['En düşük indirim oranı en yüksekten büyük olamaz.']]], 422);
        }

        $settings->update($validated);
        AdminLog::logAction((int) $request->user()->id, AdminLog::ACTION_NOTIFICATION_AD_SETTINGS_SAVED, AdminLog::TARGET_FEATURED, (int) $settings->id, $validated);

        return response()->json(['success' => true, 'message' => 'Bildirim reklamı ayarları kaydedildi.', 'data' => $settings->fresh()->presentForAdmin()]);
    }

    /** What was sent (newest first) with a small revenue summary. */
    public function index(Request $request): JsonResponse
    {
        $paid = NotificationAd::query()->whereIn('status', [NotificationAd::STATUS_QUEUED, NotificationAd::STATUS_SENT]);
        $query = NotificationAd::query()->whereIn('status', [NotificationAd::STATUS_QUEUED, NotificationAd::STATUS_SENT, NotificationAd::STATUS_FAILED])
            ->with('provider:id,name,email', 'provider.providerProfile:id,user_id,business_name,city');

        if ($term = trim((string) $request->query('q', ''))) {
            $query->whereHas('provider', fn ($q) => $q->where('name', 'like', "%{$term}%")->orWhere('email', 'like', "%{$term}%")
                ->orWhereHas('providerProfile', fn ($p) => $p->where('business_name', 'like', "%{$term}%")));
        }

        $page = $query->latest('id')->paginate(min(max((int) $request->query('per_page', 25), 1), 100));

        return response()->json([
            'success' => true,
            'data' => collect($page->items())->map(fn (NotificationAd $ad) => $ad->present() + [
                'provider' => [
                    'id' => $ad->provider?->id,
                    'name' => $ad->provider?->providerProfile?->business_name ?: $ad->provider?->name,
                    'city' => $ad->provider?->providerProfile?->city,
                ],
            ])->values(),
            'meta' => [
                'total' => $page->total(),
                'page' => $page->currentPage(),
                'last_page' => $page->lastPage(),
                'revenue_total' => (float) (clone $paid)->sum('amount'),
                'revenue_30d' => (float) (clone $paid)->where('created_at', '>=', now()->subDays(30))->sum('amount'),
                'sent_30d' => (clone $paid)->where('created_at', '>=', now()->subDays(30))->count(),
                'recipients_30d' => (int) (clone $paid)->where('created_at', '>=', now()->subDays(30))->sum('recipients_count'),
            ],
        ]);
    }
}
