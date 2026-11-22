<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ProviderPackage;
use App\Models\ProviderProfile;
use App\Models\ProviderScheduleBreak;
use App\Models\ProviderStaff;
use App\Models\ProviderStaffScheduleBreak;
use App\Models\ProviderStaffService;
use App\Models\ProviderStaffTimeOff;
use App\Models\ProviderStaffWeeklySchedule;
use App\Services\MessageContentPolicyService;
use App\Services\ProviderAvailabilityService;
use App\Support\MediaUrl;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class ProviderStaffController extends Controller
{
    public function __construct(
        protected ProviderAvailabilityService $availabilityService,
        protected MessageContentPolicyService $contentPolicy,
    ) {}

    public function index(Request $request): JsonResponse
    {
        $profile = $request->user()->providerProfile;
        if (!$profile) {
            return response()->json(['success' => false, 'message' => 'Hizmet veren profili bulunamadı.'], 404);
        }

        $staff = $profile->staff()
            ->with(['staffServices.service', 'weeklySchedules.breaks', 'timeOffs'])
            ->orderByRaw('CASE WHEN archived_at IS NULL THEN 0 ELSE 1 END')
            ->orderBy('sort_order')
            ->orderBy('id')
            ->get();

        return response()->json([
            'success' => true,
            'data' => $staff->map(fn (ProviderStaff $s) => $this->presentStaff($s))->values(),
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $user = $request->user();
        $profile = $user->providerProfile;
        if (!$profile) {
            return response()->json(['success' => false, 'message' => 'Hizmet veren profili bulunamadı.'], 404);
        }

        $validated = $this->validateStaffPayload($request, isCreate: true);

        if (!empty($validated['schedule']) && is_array($validated['schedule'])) {
            $this->availabilityService->validateSchedulePayload($validated['schedule']);
        }

        $staff = DB::transaction(function () use ($profile, $request, $validated) {
            $staff = ProviderStaff::create([
                'provider_profile_id' => $profile->id,
                'first_name' => trim($validated['first_name']),
                'last_name' => trim($validated['last_name']),
                'title' => isset($validated['title']) ? trim((string) $validated['title']) : null,
                'specialty' => isset($validated['specialty']) ? trim((string) $validated['specialty']) : null,
                'is_active' => $validated['is_active'] ?? true,
                'accepts_appointments' => $validated['accepts_appointments'] ?? true,
                'visible_to_customers' => $validated['visible_to_customers'] ?? true,
                'sort_order' => $validated['sort_order'] ?? ((int) $profile->staff()->max('sort_order') + 1),
            ]);

            if ($request->has('services') || $request->has('service_ids')) {
                $this->syncServices($staff, $validated['services'] ?? null, $validated['service_ids'] ?? null);
            } else {
                $defaultServiceIds = $profile->providerServices()
                    ->where('is_active', true)
                    ->pluck('service_id')
                    ->all();
                $this->syncServices($staff, null, $defaultServiceIds);
            }

            if (!empty($validated['schedule']) && is_array($validated['schedule'])) {
                $this->syncSchedule($staff, $validated['schedule']);
            }

            return $staff->fresh(['staffServices.service', 'weeklySchedules.breaks', 'timeOffs']);
        });

        return response()->json([
            'success' => true,
            'message' => 'Çalışan başarıyla eklendi.',
            'data' => $this->presentStaff($staff),
        ], 201);
    }

    public function update(Request $request, int $id): JsonResponse
    {
        $profile = $request->user()->providerProfile;
        if (!$profile) {
            return response()->json(['success' => false, 'message' => 'Hizmet veren profili bulunamadı.'], 404);
        }

        $staff = $profile->staff()->whereKey($id)->first();
        if (!$staff) {
            return response()->json(['success' => false, 'message' => 'Çalışan bulunamadı veya yetkiniz yok.'], 404);
        }

        $validated = $this->validateStaffPayload($request, isCreate: false);

        if (array_key_exists('schedule', $validated) && is_array($validated['schedule']) && !empty($validated['schedule'])) {
            $this->availabilityService->validateSchedulePayload($validated['schedule']);
        }

        DB::transaction(function () use ($staff, $request, $validated) {
            $updates = [];
            foreach (['first_name', 'last_name', 'title', 'specialty'] as $strCol) {
                if (array_key_exists($strCol, $validated)) {
                    $val = $validated[$strCol];
                    $updates[$strCol] = $val !== null ? trim((string) $val) : null;
                }
            }
            foreach (['is_active', 'accepts_appointments', 'visible_to_customers'] as $boolCol) {
                if (array_key_exists($boolCol, $validated)) {
                    $updates[$boolCol] = (bool) $validated[$boolCol];
                }
            }
            if (array_key_exists('sort_order', $validated)) {
                $updates['sort_order'] = (int) $validated['sort_order'];
            }
            if (($updates['is_active'] ?? null) === true && $staff->archived_at !== null) {
                $updates['archived_at'] = null;
            } elseif (($updates['is_active'] ?? null) === false && $staff->archived_at === null) {
                $updates['archived_at'] = now();
            }

            if ($updates !== []) {
                $staff->update($updates);
            }

            if ($request->has('services') || $request->has('service_ids')) {
                $this->syncServices($staff, $validated['services'] ?? null, $validated['service_ids'] ?? null);
            }

            if ($request->has('schedule') && is_array($validated['schedule'])) {
                $this->syncSchedule($staff, $validated['schedule']);
            }
        });

        $fresh = $staff->fresh(['staffServices.service', 'weeklySchedules.breaks', 'timeOffs']);

        return response()->json([
            'success' => true,
            'message' => 'Çalışan bilgileri güncellendi.',
            'data' => $this->presentStaff($fresh),
        ]);
    }

    /**
     * Soft-archives/deactivates a staff member so historical appointments keep their record intact.
     */
    public function destroy(Request $request, int $id): JsonResponse
    {
        $profile = $request->user()->providerProfile;
        if (!$profile) {
            return response()->json(['success' => false, 'message' => 'Hizmet veren profili bulunamadı.'], 404);
        }

        $staff = $profile->staff()->whereKey($id)->first();
        if (!$staff) {
            return response()->json(['success' => false, 'message' => 'Çalışan bulunamadı veya yetkiniz yok.'], 404);
        }

        $staff->update([
            'is_active' => false,
            'accepts_appointments' => false,
            'visible_to_customers' => false,
            'archived_at' => now(),
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Çalışan pasife alındı (arşivlendi). Geçmiş randevular korundu.',
            'data' => $this->presentStaff($staff->fresh(['staffServices.service', 'weeklySchedules.breaks', 'timeOffs'])),
        ]);
    }

    public function uploadPhoto(Request $request, int $id): JsonResponse
    {
        $user = $request->user();
        $profile = $user->providerProfile;
        if (!$profile) {
            return response()->json(['success' => false, 'message' => 'Hizmet veren profili bulunamadı.'], 404);
        }

        $staff = $profile->staff()->whereKey($id)->first();
        if (!$staff) {
            return response()->json(['success' => false, 'message' => 'Çalışan bulunamadı veya yetkiniz yok.'], 404);
        }

        $request->validate([
            'photo' => ['required', 'file', 'mimes:jpg,jpeg,png,webp', 'max:5120'],
        ], [
            'photo.required' => 'Lütfen bir çalışan fotoğrafı seçin.',
            'photo.mimes' => 'Yalnızca JPG, JPEG, PNG veya WEBP görseller kabul edilir.',
            'photo.max' => 'Fotoğraf boyutu en fazla 5 MB olabilir.',
        ]);

        $file = $request->file('photo');
        $ext = strtolower($file->getClientOriginalExtension() ?: $file->extension());
        $path = $file->storeAs("provider-media/{$user->id}/staff", Str::uuid() . ".{$ext}", 'public');
        $url = MediaUrl::fromPublicPath($path);

        $oldPath = MediaUrl::managedPublicPath($staff->photo_url);
        $staff->update(['photo_url' => $url]);

        if ($oldPath && $oldPath !== $path) {
            Storage::disk('public')->delete($oldPath);
        }

        return response()->json([
            'success' => true,
            'message' => 'Çalışan fotoğrafı güncellendi.',
            'data' => ['photo_url' => $url],
        ]);
    }

    public function destroyPhoto(Request $request, int $id): JsonResponse
    {
        $profile = $request->user()->providerProfile;
        if (!$profile) {
            return response()->json(['success' => false, 'message' => 'Hizmet veren profili bulunamadı.'], 404);
        }

        $staff = $profile->staff()->whereKey($id)->first();
        if (!$staff) {
            return response()->json(['success' => false, 'message' => 'Çalışan bulunamadı.'], 404);
        }

        $oldPath = MediaUrl::managedPublicPath($staff->photo_url);
        $staff->update(['photo_url' => null]);

        if ($oldPath) {
            Storage::disk('public')->delete($oldPath);
        }

        return response()->json([
            'success' => true,
            'message' => 'Çalışan fotoğrafı kaldırıldı.',
            'data' => ['photo_url' => null],
        ]);
    }

    public function storeTimeOff(Request $request, int $id): JsonResponse
    {
        $profile = $request->user()->providerProfile;
        if (!$profile) {
            return response()->json(['success' => false, 'message' => 'Hizmet veren profili bulunamadı.'], 404);
        }

        $staff = $profile->staff()->whereKey($id)->first();
        if (!$staff) {
            return response()->json(['success' => false, 'message' => 'Çalışan bulunamadı.'], 404);
        }

        $validated = $request->validate([
            'start_date' => ['required', 'date_format:Y-m-d'],
            'end_date' => ['required', 'date_format:Y-m-d', 'after_or_equal:start_date'],
            'start_time' => ['nullable', 'required_with:end_time', 'date_format:H:i'],
            'end_time' => ['nullable', 'required_with:start_time', 'date_format:H:i'],
            'reason' => ['nullable', 'string', 'max:60'],
            'note' => ['nullable', 'string', 'max:500'],
        ]);

        if (!empty($validated['start_time']) && !empty($validated['end_time']) && $validated['start_time'] >= $validated['end_time']) {
            return response()->json([
                'success' => false,
                'message' => 'İzin başlangıç saati bitiş saatinden önce olmalıdır.',
            ], 422);
        }

        $timeOff = ProviderStaffTimeOff::create([
            'provider_staff_id' => $staff->id,
            'start_date' => $validated['start_date'],
            'end_date' => $validated['end_date'],
            'start_time' => $validated['start_time'] ?? null,
            'end_time' => $validated['end_time'] ?? null,
            'reason' => trim((string) ($validated['reason'] ?? 'izin')) ?: 'izin',
            'note' => $validated['note'] ?? null,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Çalışan izni kaydedildi.',
            'data' => [
                'id' => $timeOff->id,
                'start_date' => $timeOff->start_date->format('Y-m-d'),
                'end_date' => $timeOff->end_date->format('Y-m-d'),
                'start_time' => $timeOff->start_time ? substr($timeOff->start_time, 0, 5) : null,
                'end_time' => $timeOff->end_time ? substr($timeOff->end_time, 0, 5) : null,
                'reason' => $timeOff->reason,
                'note' => $timeOff->note,
            ],
        ], 201);
    }

    public function destroyTimeOff(Request $request, int $staffId, int $timeOffId): JsonResponse
    {
        $profile = $request->user()->providerProfile;
        if (!$profile) {
            return response()->json(['success' => false, 'message' => 'Hizmet veren profili bulunamadı.'], 404);
        }

        $staff = $profile->staff()->whereKey($staffId)->first();
        if (!$staff) {
            return response()->json(['success' => false, 'message' => 'Çalışan bulunamadı.'], 404);
        }

        $timeOff = $staff->timeOffs()->whereKey($timeOffId)->first();
        if (!$timeOff) {
            return response()->json(['success' => false, 'message' => 'İzin kaydı bulunamadı.'], 404);
        }

        $timeOff->delete();

        return response()->json([
            'success' => true,
            'message' => 'Çalışan izni silindi.',
        ]);
    }

    /**
     * Customer-facing list of selectable visible staff for a provider and selected services/package.
     */
    public function publicIndex(Request $request, $provider): JsonResponse
    {
        $profile = $this->availabilityService->resolveProviderProfile($provider);
        if (!$profile || !$profile->is_approved || $profile->identity_status !== 'APPROVED' || !$profile->isVerified()) {
            return response()->json(['success' => false, 'message' => 'Hizmet veren bulunamadı.'], 404);
        }

        $package = null;
        if ($request->filled('provider_package_id')) {
            $package = $profile->packages()->with('services')->whereKey($request->query('provider_package_id'))->first();
        }

        $rawServices = $request->query('service_ids') ?: $request->query('service_id');
        $serviceIds = $this->parseIds($rawServices);
        $date = $request->query('date');

        $staffList = $this->availabilityService->getEligibleStaff(
            $profile,
            $serviceIds,
            $package,
            customerVisibleOnly: true
        );
        $staffList->loadMissing('staffServices.service');

        $data = $staffList->map(function (ProviderStaff $staff) use ($profile, $serviceIds, $package, $date) {
            $item = [
                'id' => $staff->id,
                'first_name' => $staff->first_name,
                'last_name' => $staff->last_name,
                'full_name' => $staff->full_name,
                'photo_url' => MediaUrl::resolve($staff->photo_url),
                'title' => $staff->title,
                'specialty' => $staff->specialty,
                'accepts_appointments' => (bool) $staff->accepts_appointments,
                'services' => $staff->staffServices->where('is_active', true)->values()->map(fn ($ss) => [
                    'service_id' => (int) $ss->service_id,
                    'service_name' => $ss->service?->name,
                    'custom_duration_minutes' => $ss->custom_duration_minutes,
                ]),
            ];

            if ($date && preg_match('/^\d{4}-\d{2}-\d{2}$/', (string) $date)) {
                $slots = $this->availabilityService->getAvailableSlotsForStaff(
                    $profile,
                    $staff,
                    $serviceIds,
                    (string) $date,
                    null,
                    $package
                );
                $item['available_slots_count'] = count($slots);
                $item['is_available'] = count($slots) > 0;
            }

            return $item;
        })->values();

        return response()->json([
            'success' => true,
            'data' => $data,
        ]);
    }

    private function validateStaffPayload(Request $request, bool $isCreate): array
    {
        $reqRule = $isCreate ? 'required' : 'sometimes|required';

        $validated = $request->validate([
            'first_name' => "{$reqRule}|string|max:80",
            'last_name' => "{$reqRule}|string|max:80",
            'title' => 'nullable|string|max:100',
            'specialty' => 'nullable|string|max:160',
            'is_active' => 'sometimes|boolean',
            'accepts_appointments' => 'sometimes|boolean',
            'visible_to_customers' => 'sometimes|boolean',
            'sort_order' => 'sometimes|integer|min:0|max:9999',
            'service_ids' => 'nullable|array',
            'service_ids.*' => 'integer|exists:services,id',
            'services' => 'nullable|array',
            'services.*.service_id' => 'required|integer|exists:services,id',
            'services.*.custom_duration_minutes' => 'nullable|integer|min:5|max:480',
            'services.*.is_active' => 'sometimes|boolean',
            'schedule' => 'nullable|array',
        ]);

        $this->contentPolicy->validateFields([
            'first_name' => $validated['first_name'] ?? null,
            'last_name' => $validated['last_name'] ?? null,
            'title' => $validated['title'] ?? null,
            'specialty' => $validated['specialty'] ?? null,
        ]);

        return $validated;
    }

    private function syncServices(ProviderStaff $staff, ?array $services, ?array $serviceIds): void
    {
        $staff->staffServices()->delete();

        if (is_array($services)) {
            $seen = [];
            foreach ($services as $row) {
                $sId = (int) $row['service_id'];
                if (in_array($sId, $seen, true)) {
                    continue;
                }
                $seen[] = $sId;
                ProviderStaffService::create([
                    'provider_staff_id' => $staff->id,
                    'service_id' => $sId,
                    'custom_duration_minutes' => $row['custom_duration_minutes'] ?? null,
                    'is_active' => array_key_exists('is_active', $row) ? (bool) $row['is_active'] : true,
                ]);
            }
            return;
        }

        if (is_array($serviceIds)) {
            foreach (array_values(array_unique(array_map('intval', $serviceIds))) as $sId) {
                ProviderStaffService::create([
                    'provider_staff_id' => $staff->id,
                    'service_id' => $sId,
                    'is_active' => true,
                ]);
            }
        }
    }

    private function syncSchedule(ProviderStaff $staff, array $days): void
    {
        $staff->weeklySchedules()->delete();

        foreach ($days as $dayData) {
            $dayName = strtolower($dayData['day'] ?? $dayData['day_of_week']);
            $enabled = (bool) ($dayData['enabled'] ?? $dayData['is_enabled'] ?? false);
            $startTime = $dayData['start_time'] ?? '09:00';
            $endTime = $dayData['end_time'] ?? '19:00';

            $schedule = ProviderStaffWeeklySchedule::create([
                'provider_staff_id' => $staff->id,
                'day_of_week' => $dayName,
                'is_enabled' => $enabled,
                'start_time' => $startTime,
                'end_time' => $endTime,
            ]);

            if ($enabled && !empty($dayData['breaks']) && is_array($dayData['breaks'])) {
                foreach ($dayData['breaks'] as $brk) {
                    ProviderStaffScheduleBreak::create([
                        'staff_weekly_schedule_id' => $schedule->id,
                        'start_time' => $brk['start_time'],
                        'end_time' => $brk['end_time'],
                    ]);
                }
            }
        }
    }

    private function presentStaff(ProviderStaff $staff): array
    {
        return [
            'id' => $staff->id,
            'provider_profile_id' => $staff->provider_profile_id,
            'first_name' => $staff->first_name,
            'last_name' => $staff->last_name,
            'full_name' => $staff->full_name,
            'photo_url' => MediaUrl::resolve($staff->photo_url),
            'title' => $staff->title,
            'specialty' => $staff->specialty,
            'is_active' => (bool) $staff->is_active,
            'accepts_appointments' => (bool) $staff->accepts_appointments,
            'visible_to_customers' => (bool) $staff->visible_to_customers,
            'sort_order' => (int) $staff->sort_order,
            'archived_at' => $staff->archived_at?->toISOString(),
            'services' => $staff->staffServices->map(fn (ProviderStaffService $ss) => [
                'service_id' => (int) $ss->service_id,
                'service_name' => $ss->service?->name,
                'custom_duration_minutes' => $ss->custom_duration_minutes,
                'is_active' => (bool) $ss->is_active,
            ])->values(),
            'schedule' => $staff->weeklySchedules->map(fn (ProviderStaffWeeklySchedule $day) => [
                'day_of_week' => $day->day_of_week,
                'is_enabled' => (bool) $day->is_enabled,
                'start_time' => $day->start_time ? substr($day->start_time, 0, 5) : null,
                'end_time' => $day->end_time ? substr($day->end_time, 0, 5) : null,
                'breaks' => $day->breaks->map(fn (ProviderStaffScheduleBreak $b) => [
                    'start_time' => substr($b->start_time, 0, 5),
                    'end_time' => substr($b->end_time, 0, 5),
                ])->values(),
            ])->values(),
            'time_offs' => $staff->timeOffs->map(fn (ProviderStaffTimeOff $t) => [
                'id' => $t->id,
                'start_date' => $t->start_date->format('Y-m-d'),
                'end_date' => $t->end_date->format('Y-m-d'),
                'start_time' => $t->start_time ? substr($t->start_time, 0, 5) : null,
                'end_time' => $t->end_time ? substr($t->end_time, 0, 5) : null,
                'reason' => $t->reason,
                'note' => $t->note,
            ])->values(),
        ];
    }

    private function parseIds(mixed $raw): array
    {
        $flat = [];
        foreach ((array) ($raw ?: []) as $item) {
            if (is_string($item) && str_contains($item, ',')) {
                $flat = array_merge($flat, explode(',', $item));
            } else {
                $flat[] = $item;
            }
        }
        return array_values(array_filter(array_map('intval', $flat), fn ($v) => $v > 0));
    }
}
