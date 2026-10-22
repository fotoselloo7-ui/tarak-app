<?php

namespace App\Services;

use App\Models\Appointment;
use App\Models\ProviderClosedDate;
use App\Models\ProviderPackage;
use App\Models\ProviderProfile;
use App\Models\ProviderWeeklySchedule;
use App\Models\Service;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Validation\ValidationException;

class ProviderAvailabilityService
{
    public const SLOT_INTERVAL_MINUTES = 30;

    /**
     * Resolve ProviderProfile model from User or ProviderProfile.
     */
    public function resolveProviderProfile(User|ProviderProfile|int $provider): ?ProviderProfile
    {
        if ($provider instanceof ProviderProfile) {
            return $provider;
        }

        if ($provider instanceof User) {
            return $provider->providerProfile;
        }

        return ProviderProfile::where('id', $provider)
            ->orWhere('user_id', $provider)
            ->first();
    }

    /**
     * Calculate canonical duration and total price based on provider's custom prices/durations or catalog base prices.
     */
    public function calculateDurationAndPrice(ProviderProfile $providerProfile, array $serviceIds): array
    {
        if (empty($serviceIds)) {
            return [
                'total_duration_minutes' => 30,
                'total_price' => 0.0,
                'services_data' => [],
            ];
        }

        $catalogServices = Service::whereIn('id', $serviceIds)->get()->keyBy('id');
        $providerServices = $providerProfile->providerServices()
            ->whereIn('service_id', $serviceIds)
            ->get()
            ->keyBy('service_id');

        $totalDuration = 0;
        $totalPrice = 0.0;
        $originalTotal = 0.0;
        $servicesData = [];
        // A running campaign discount ("bildirim reklamı") is part of the price snapshot.
        $discountPercent = app(ProviderDiscountService::class)->percentFor((int) $providerProfile->user_id);

        foreach ($serviceIds as $sId) {
            $catalog = $catalogServices->get($sId);
            if (!$catalog) {
                continue;
            }

            $pService = $providerServices->get($sId);

            // Price snapshot rule: custom_price if present, otherwise base_price, minus the running campaign discount
            $basePrice = ($pService && $pService->custom_price !== null)
                ? (float) $pService->custom_price
                : (float) $catalog->base_price;
            $price = ProviderDiscountService::discounted($basePrice, $discountPercent);

            // Duration snapshot rule: custom_duration_minutes if present, otherwise duration_minutes
            $duration = ($pService && $pService->custom_duration_minutes !== null)
                ? (int) $pService->custom_duration_minutes
                : (int) $catalog->duration_minutes;

            $duration = max(15, $duration);

            $totalPrice += $price;
            $originalTotal += $basePrice;
            $totalDuration += $duration;

            $servicesData[] = [
                'service_id' => $catalog->id,
                'service_name' => $catalog->name,
                'price_snapshot' => $price,
                'duration_minutes_snapshot' => $duration,
            ];
        }

        return [
            'total_duration_minutes' => max(15, $totalDuration),
            'total_price' => round($totalPrice, 2),
            'original_total_price' => $discountPercent > 0 ? round($originalTotal, 2) : null,
            'discount_percent' => $discountPercent,
            'services_data' => $servicesData,
        ];
    }

    /**
     * Check if all requested services are offered and active by provider.
     */
    public function providerOffersAllServices(ProviderProfile $providerProfile, array $serviceIds): bool
    {
        if (empty($serviceIds)) {
            return false;
        }

        $activeCount = $providerProfile->providerServices()
            ->whereIn('service_id', $serviceIds)
            ->where('is_active', true)
            ->count();

        return $activeCount === count(array_unique($serviceIds));
    }

    /**
     * Central Availability Calculation.
     *
     * Returns list of available slots:
     * [
     *   ['start_time' => '14:00', 'end_time' => '15:00']
     * ]
     */
    public function getAvailableSlots(
        User|ProviderProfile|int $provider,
        array $serviceIds,
        string $date,
        ?int $excludeAppointmentId = null,
        ?ProviderPackage $package = null
    ): array {
        $profile = $this->resolveProviderProfile($provider);
        if (!$profile) {
            return [];
        }

        // 1. Provider must be APPROVED, identity_status APPROVED, and isVerified (approved documents)
        if (!$profile->is_approved || $profile->identity_status !== 'APPROVED' || !$profile->isVerified()) {
            return [];
        }

        // 2. Provider must actively offer all requested services (or own the active package)
        if ($package) {
            if (!$package->is_active || $package->provider_profile_id !== $profile->id) {
                return [];
            }
        } elseif (!$this->providerOffersAllServices($profile, $serviceIds)) {
            return [];
        }

        // 3. Date cannot be in the past
        $carbonDate = Carbon::parse($date)->startOfDay();
        $today = Carbon::today();
        if ($carbonDate->lt($today)) {
            return [];
        }

        // 4. Special closed dates check
        $isClosed = $profile->closedDates()->where('date', $carbonDate->format('Y-m-d'))->exists();
        if ($isClosed) {
            return [];
        }

        // 5. Day of week schedule check
        $dayOfWeek = strtolower($carbonDate->format('l')); // monday, tuesday, etc.
        $schedule = $profile->weeklySchedules()
            ->with('breaks')
            ->where('day_of_week', $dayOfWeek)
            ->first();

        if (!$schedule || !$schedule->is_enabled || !$schedule->start_time || !$schedule->end_time) {
            return [];
        }

        // Parse shift hours into minutes from midnight
        [$startH, $startM] = explode(':', substr($schedule->start_time, 0, 5));
        [$endH, $endM] = explode(':', substr($schedule->end_time, 0, 5));
        $shiftStartMin = (int)$startH * 60 + (int)$startM;
        $shiftEndMin = (int)$endH * 60 + (int)$endM;

        if ($shiftStartMin >= $shiftEndMin) {
            return [];
        }

        // 6. Calculate total service duration
        $durationMinutes = $package
            ? max(15, (int) $package->duration_minutes)
            : $this->calculateDurationAndPrice($profile, $serviceIds)['total_duration_minutes'];

        // 7. Parse breaks
        $breaks = [];
        foreach ($schedule->breaks as $brk) {
            [$bSH, $bSM] = explode(':', substr($brk->start_time, 0, 5));
            [$bEH, $bEM] = explode(':', substr($brk->end_time, 0, 5));
            $bStart = (int)$bSH * 60 + (int)$bSM;
            $bEnd = (int)$bEH * 60 + (int)$bEM;
            if ($bStart < $bEnd) {
                $breaks[] = ['start' => $bStart, 'end' => $bEnd];
            }
        }

        // 8. Blocking appointments: PENDING, ALTERNATIVE_PROPOSED, CONFIRMED
        $blockingStatuses = ['PENDING', 'ALTERNATIVE_PROPOSED', 'CONFIRMED'];
        $query = Appointment::where('provider_user_id', $profile->user_id)
            ->where('appointment_date', $carbonDate->format('Y-m-d'))
            ->whereIn('status', $blockingStatuses);

        if ($excludeAppointmentId) {
            $query->where('id', '!=', $excludeAppointmentId);
        }

        $existingAppts = $query->get();
        $busyIntervals = [];

        foreach ($existingAppts as $appt) {
            [$aSH, $aSM] = explode(':', substr($appt->start_time, 0, 5));
            [$aEH, $aEM] = explode(':', substr($appt->end_time, 0, 5));
            $aStart = (int)$aSH * 60 + (int)$aSM;
            $aEnd = (int)$aEH * 60 + (int)$aEM;
            if ($aEnd <= $aStart) {
                $aEnd = $aStart + ($appt->total_duration_minutes ?: 30);
            }
            $busyIntervals[] = ['start' => $aStart, 'end' => $aEnd];
        }

        // 9. Past slots if date is today
        $isToday = $carbonDate->isToday();
        $now = Carbon::now();
        $currentMin = (int)$now->format('H') * 60 + (int)$now->format('i');

        // 10. Generate slots in 30-minute intervals
        $step = self::SLOT_INTERVAL_MINUTES;
        $slots = [];

        for ($slotStart = $shiftStartMin; $slotStart < $shiftEndMin; $slotStart += $step) {
            $slotEnd = $slotStart + $durationMinutes;

            // Cannot exceed shift end
            if ($slotEnd > $shiftEndMin) {
                continue;
            }

            // Past time check for today
            if ($isToday && $slotStart <= $currentMin) {
                continue;
            }

            // Break overlap check: newStart < breakEnd && newEnd > breakStart
            $overlapsBreak = false;
            foreach ($breaks as $b) {
                if ($slotStart < $b['end'] && $slotEnd > $b['start']) {
                    $overlapsBreak = true;
                    break;
                }
            }
            if ($overlapsBreak) {
                continue;
            }

            // Appointment overlap check: newStart < existingEnd && newEnd > existingStart
            $overlapsAppt = false;
            foreach ($busyIntervals as $b) {
                if ($slotStart < $b['end'] && $slotEnd > $b['start']) {
                    $overlapsAppt = true;
                    break;
                }
            }
            if ($overlapsAppt) {
                continue;
            }

            $startStr = sprintf('%02d:%02d', floor($slotStart / 60), $slotStart % 60);
            $endStr = sprintf('%02d:%02d', floor($slotEnd / 60), $slotEnd % 60);

            $slots[] = [
                'start_time' => $startStr,
                'end_time' => $endStr,
            ];
        }

        return $slots;
    }

    /**
     * Check if a specific time slot is available for booking.
     */
    public function isSlotAvailable(
        User|ProviderProfile|int $provider,
        array $serviceIds,
        string $date,
        string $startTime,
        ?int $excludeAppointmentId = null,
        ?ProviderPackage $package = null
    ): bool {
        $slots = $this->getAvailableSlots($provider, $serviceIds, $date, $excludeAppointmentId, $package);
        $normalizedTime = substr($startTime, 0, 5);

        foreach ($slots as $slot) {
            if ($slot['start_time'] === $normalizedTime) {
                return true;
            }
        }

        return false;
    }

    /**
     * Whether an instant (right-now) job of the given duration fits the provider's working window,
     * using the same weekly schedule, breaks, closed dates and blocking appointments as slot booking.
     *
     * @return array{available: bool, reason: ?string}
     */
    public function instantWindowCheck(ProviderProfile $profile, int $durationMinutes, ?Carbon $now = null): array
    {
        $now = $now ?: Carbon::now();
        $today = $now->copy()->startOfDay();
        $durationMinutes = max(15, $durationMinutes);

        if ($profile->closedDates()->where('date', $today->format('Y-m-d'))->exists()) {
            return ['available' => false, 'reason' => 'Hizmet veren bugün izinli.'];
        }

        $schedule = $profile->weeklySchedules()
            ->with('breaks')
            ->where('day_of_week', strtolower($today->format('l')))
            ->first();

        if (!$schedule || !$schedule->is_enabled || !$schedule->start_time || !$schedule->end_time) {
            return ['available' => false, 'reason' => 'Hizmet veren bugün çalışmıyor.'];
        }

        $toMin = static function (string $time): int {
            [$h, $m] = explode(':', substr($time, 0, 5));
            return (int) $h * 60 + (int) $m;
        };

        $shiftStart = $toMin($schedule->start_time);
        $shiftEnd = $toMin($schedule->end_time);
        $jobStart = (int) $now->format('H') * 60 + (int) $now->format('i');
        $jobEnd = $jobStart + $durationMinutes;

        if ($jobStart < $shiftStart || $jobEnd > $shiftEnd) {
            return ['available' => false, 'reason' => 'Hizmet veren şu anda çalışma saatleri dışında.'];
        }

        foreach ($schedule->breaks as $brk) {
            if ($jobStart < $toMin($brk->end_time) && $jobEnd > $toMin($brk->start_time)) {
                return ['available' => false, 'reason' => 'Hizmet veren şu anda molada.'];
            }
        }

        $appointments = Appointment::where('provider_user_id', $profile->user_id)
            ->where('appointment_date', $today->format('Y-m-d'))
            ->whereIn('status', ['PENDING', 'ALTERNATIVE_PROPOSED', 'CONFIRMED', 'IN_PROGRESS'])
            ->get(['start_time', 'end_time', 'total_duration_minutes']);

        foreach ($appointments as $appt) {
            $aStart = $toMin($appt->start_time);
            $aEnd = $toMin($appt->end_time);
            if ($aEnd <= $aStart) {
                $aEnd = $aStart + ($appt->total_duration_minutes ?: 30);
            }
            if ($jobStart < $aEnd && $jobEnd > $aStart) {
                return ['available' => false, 'reason' => 'Hizmet verenin bu saatte randevusu var.'];
            }
        }

        return ['available' => true, 'reason' => null];
    }

    /**
     * Validate schedule data before saving.
     */
    public function validateSchedulePayload(array $days): void
    {
        $validDays = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
        $seenDays = [];

        foreach ($days as $dayData) {
            $day = strtolower($dayData['day'] ?? $dayData['day_of_week'] ?? '');
            if (!in_array($day, $validDays)) {
                throw ValidationException::withMessages(['schedule' => "Geçersiz gün adı: {$day}"]);
            }

            if (in_array($day, $seenDays)) {
                throw ValidationException::withMessages(['schedule' => "Bir güne ait birden fazla program kaydı olamaz: {$day}"]);
            }
            $seenDays[] = $day;

            $enabled = (bool)($dayData['enabled'] ?? $dayData['is_enabled'] ?? false);
            if ($enabled) {
                $start = $dayData['start_time'] ?? null;
                $end = $dayData['end_time'] ?? null;

                if (!$start || !$end) {
                    throw ValidationException::withMessages(['schedule' => "{$day} günü aktif ancak mesai saatleri belirtilmemiş."]);
                }

                [$sH, $sM] = explode(':', substr($start, 0, 5));
                [$eH, $eM] = explode(':', substr($end, 0, 5));
                $sMin = (int)$sH * 60 + (int)$sM;
                $eMin = (int)$eH * 60 + (int)$eM;

                if ($sMin >= $eMin) {
                    throw ValidationException::withMessages(['schedule' => "{$day} günü başlangıç saati ({$start}) bitiş saatinden ({$end}) önce olmalıdır."]);
                }

                // Breaks validation
                $breaks = $dayData['breaks'] ?? [];
                $parsedBreaks = [];

                foreach ($breaks as $brk) {
                    $bStart = $brk['start_time'] ?? null;
                    $bEnd = $brk['end_time'] ?? null;

                    if (!$bStart || !$bEnd) {
                        throw ValidationException::withMessages(['schedule' => "Mola saatleri eksik."]);
                    }

                    [$bSH, $bSM] = explode(':', substr($bStart, 0, 5));
                    [$bEH, $bEM] = explode(':', substr($bEnd, 0, 5));
                    $bsMin = (int)$bSH * 60 + (int)$bSM;
                    $beMin = (int)$bEH * 60 + (int)$bEM;

                    if ($bsMin >= $beMin) {
                        throw ValidationException::withMessages(['schedule' => "Mola başlangıç saati bitiş saatinden önce olmalıdır ({$bStart} - {$bEnd})."]);
                    }

                    // Must be within shift hours
                    if ($bsMin < $sMin || $beMin > $eMin) {
                        throw ValidationException::withMessages(['schedule' => "Mola ({$bStart} - {$bEnd}) mesai saatleri ({$start} - {$end}) dışında olamaz."]);
                    }

                    // Check overlap with other breaks
                    foreach ($parsedBreaks as $existingB) {
                        if ($bsMin < $existingB['end'] && $beMin > $existingB['start']) {
                            throw ValidationException::withMessages(['schedule' => "Molalar birbiriyle çakışamaz: ({$bStart} - {$bEnd})."]);
                        }
                    }

                    $parsedBreaks[] = ['start' => $bsMin, 'end' => $beMin];
                }
            }
        }
    }
}
