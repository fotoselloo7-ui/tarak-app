<?php

namespace App\Http\Controllers;

use App\Http\Resources\ProviderScheduleResource;
use App\Models\ProviderClosedDate;
use App\Models\ProviderScheduleBreak;
use App\Models\ProviderWeeklySchedule;
use App\Services\ProviderAvailabilityService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class ProviderScheduleController extends Controller
{
    public function __construct(
        protected ProviderAvailabilityService $availabilityService
    ) {}

    /**
     * Get authenticated provider's weekly schedule.
     */
    public function getSchedule(Request $request): JsonResponse
    {
        $user = $request->user();
        $profile = $user->providerProfile;

        if (!$profile) {
            return response()->json([
                'success' => false,
                'message' => 'Hizmet veren profili bulunamadı.',
            ], 404);
        }

        $schedules = $profile->weeklySchedules()
            ->with('breaks')
            ->orderBy('id')
            ->get();

        return response()->json([
            'success' => true,
            'data' => ProviderScheduleResource::collection($schedules),
        ]);
    }

    /**
     * Update authenticated provider's weekly schedule.
     */
    public function updateSchedule(Request $request): JsonResponse
    {
        $user = $request->user();
        $profile = $user->providerProfile;

        if (!$profile) {
            return response()->json([
                'success' => false,
                'message' => 'Hizmet veren profili bulunamadı.',
            ], 404);
        }

        $days = $request->input('schedule') ?: $request->all();
        if (!is_array($days)) {
            return response()->json([
                'success' => false,
                'message' => 'Geçersiz program verisi.',
            ], 422);
        }

        // Central validation
        $this->availabilityService->validateSchedulePayload($days);

        DB::transaction(function () use ($profile, $days) {
            foreach ($days as $dayData) {
                $dayName = strtolower($dayData['day'] ?? $dayData['day_of_week']);
                $enabled = (bool)($dayData['enabled'] ?? $dayData['is_enabled'] ?? false);
                $startTime = $dayData['start_time'] ?? '09:00';
                $endTime = $dayData['end_time'] ?? '19:00';

                $schedule = ProviderWeeklySchedule::updateOrCreate(
                    [
                        'provider_profile_id' => $profile->id,
                        'day_of_week' => $dayName,
                    ],
                    [
                        'is_enabled' => $enabled,
                        'start_time' => $startTime,
                        'end_time' => $endTime,
                    ]
                );

                // Update breaks
                $schedule->breaks()->delete();

                if ($enabled && !empty($dayData['breaks'])) {
                    foreach ($dayData['breaks'] as $brk) {
                        ProviderScheduleBreak::create([
                            'weekly_schedule_id' => $schedule->id,
                            'start_time' => $brk['start_time'],
                            'end_time' => $brk['end_time'],
                        ]);
                    }
                }
            }
        });

        $updatedSchedules = $profile->weeklySchedules()->with('breaks')->get();

        return response()->json([
            'success' => true,
            'message' => 'Çalışma programı başarıyla güncellendi.',
            'data' => ProviderScheduleResource::collection($updatedSchedules),
        ]);
    }

    /**
     * Get authenticated provider's special closed dates.
     */
    public function getClosedDates(Request $request): JsonResponse
    {
        $user = $request->user();
        $profile = $user->providerProfile;

        if (!$profile) {
            return response()->json([
                'success' => false,
                'message' => 'Hizmet veren profili bulunamadı.',
            ], 404);
        }

        $closedDates = $profile->closedDates()
            ->orderBy('date')
            ->get()
            ->map(function ($cd) {
                return [
                    'id' => (string) $cd->id,
                    'date' => $cd->date->format('Y-m-d'),
                    'reason' => $cd->reason,
                    'note' => $cd->note,
                ];
            });

        return response()->json([
            'success' => true,
            'data' => $closedDates,
        ]);
    }

    /**
     * Add a special closed date for authenticated provider.
     */
    public function storeClosedDate(Request $request): JsonResponse
    {
        $user = $request->user();
        $profile = $user->providerProfile;

        if (!$profile) {
            return response()->json([
                'success' => false,
                'message' => 'Hizmet veren profili bulunamadı.',
            ], 404);
        }

        $validated = $request->validate([
            'date' => 'required|date_format:Y-m-d',
            'reason' => 'required|string|max:50',
            'note' => 'nullable|string|max:500',
        ]);

        // Duplicate check
        $exists = $profile->closedDates()->where('date', $validated['date'])->exists();
        if ($exists) {
            return response()->json([
                'success' => false,
                'message' => 'Bu tarih için zaten kapalı gün kaydı bulunmaktadır.',
            ], 422);
        }

        $closedDate = ProviderClosedDate::create([
            'provider_profile_id' => $profile->id,
            'date' => $validated['date'],
            'reason' => $validated['reason'],
            'note' => $validated['note'] ?? null,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Kapalı gün başarıyla eklendi.',
            'data' => [
                'id' => (string) $closedDate->id,
                'date' => $closedDate->date->format('Y-m-d'),
                'reason' => $closedDate->reason,
                'note' => $closedDate->note,
            ],
        ], 201);
    }

    /**
     * Delete a special closed date for authenticated provider.
     */
    public function destroyClosedDate(Request $request, $id): JsonResponse
    {
        $user = $request->user();
        $profile = $user->providerProfile;

        if (!$profile) {
            return response()->json([
                'success' => false,
                'message' => 'Hizmet veren profili bulunamadı.',
            ], 404);
        }

        $closedDate = $profile->closedDates()->where('id', $id)->first();
        if (!$closedDate) {
            return response()->json([
                'success' => false,
                'message' => 'Kapalı gün kaydı bulunamadı veya yetkiniz yok.',
            ], 404);
        }

        $closedDate->delete();

        return response()->json([
            'success' => true,
            'message' => 'Kapalı gün kaydı silindi.',
        ]);
    }
}
