<?php

namespace App\Services;

use App\Models\Appointment;
use App\Models\ProviderPackage;
use App\Models\ProviderProfile;
use App\Models\ProviderStaff;
use App\Models\Service;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Database\Eloquent\Collection as EloquentCollection;
use Illuminate\Validation\ValidationException;

class ProviderAvailabilityService
{
    public const SLOT_INTERVAL_MINUTES = 30;
    public const BLOCKING_STATUSES = [
        Appointment::STATUS_PENDING,
        Appointment::STATUS_ALTERNATIVE_PROPOSED,
        Appointment::STATUS_CONFIRMED,
        Appointment::STATUS_IN_PROGRESS,
    ];

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
     * Whether this salon currently operates with at least one active staff member.
     */
    public function providerHasActiveStaff(ProviderProfile $profile): bool
    {
        return $profile->activeStaff()->exists();
    }

    /**
     * All bookable staff members who offer all requested services (or the package's services).
     *
     * @return EloquentCollection<int, ProviderStaff>
     */
    public function getEligibleStaff(
        ProviderProfile $profile,
        array $serviceIds,
        ?ProviderPackage $package = null,
        bool $customerVisibleOnly = true
    ): EloquentCollection {
        $effectiveServiceIds = $this->effectiveServiceIds($serviceIds, $package);

        $query = $profile->staff()
            ->with(['staffServices', 'weeklySchedules.breaks', 'timeOffs'])
            ->where('is_active', true)
            ->whereNull('archived_at')
            ->where('accepts_appointments', true);

        if ($customerVisibleOnly) {
            $query->where('visible_to_customers', true);
        }

        $staffList = $query->orderBy('sort_order')->orderBy('id')->get();
        if (empty($effectiveServiceIds)) {
            return $staffList;
        }

        return $staffList->filter(
            fn (ProviderStaff $staff) => $this->staffOffersAllServices($staff, $effectiveServiceIds)
        )->values();
    }

    public function staffOffersAllServices(ProviderStaff $staff, array $serviceIds): bool
    {
        $uniqueIds = array_values(array_unique(array_map('intval', $serviceIds)));
        if (empty($uniqueIds)) {
            return true;
        }

        $activeServiceIds = $staff->relationLoaded('staffServices')
            ? $staff->staffServices->where('is_active', true)->pluck('service_id')->map(fn ($v) => (int) $v)->all()
            : $staff->staffServices()->where('is_active', true)->pluck('service_id')->map(fn ($v) => (int) $v)->all();

        foreach ($uniqueIds as $id) {
            if (!in_array($id, $activeServiceIds, true)) {
                return false;
            }
        }

        return true;
    }

    private function effectiveServiceIds(array $serviceIds, ?ProviderPackage $package = null): array
    {
        if ($package) {
            $package->loadMissing('services');
            return $package->services->pluck('id')->map(fn ($v) => (int) $v)->all();
        }

        return array_values(array_unique(array_map('intval', $serviceIds)));
    }

    /**
     * Calculate canonical duration and total price based on provider's custom prices/durations,
     * optional staff duration overrides, or catalog base prices.
     */
    public function calculateDurationAndPrice(
        ProviderProfile $providerProfile,
        array $serviceIds,
        ?ProviderStaff $staff = null
    ): array {
        if (empty($serviceIds)) {
            return [
                'total_duration_minutes' => 30,
                'total_price' => 0.0,
                'original_total_price' => null,
                'discount_percent' => 0,
                'services_data' => [],
            ];
        }

        $catalogServices = Service::whereIn('id', $serviceIds)->get()->keyBy('id');
        $providerServices = $providerProfile->providerServices()
            ->whereIn('service_id', $serviceIds)
            ->get()
            ->keyBy('service_id');

        $staffServices = collect();
        if ($staff) {
            $staffServices = $staff->relationLoaded('staffServices')
                ? $staff->staffServices->keyBy('service_id')
                : $staff->staffServices()->whereIn('service_id', $serviceIds)->get()->keyBy('service_id');
        }

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
            $sService = $staffServices->get($sId);

            // Price snapshot rule: custom_price if present, otherwise base_price, minus campaign discount
            $basePrice = ($pService && $pService->custom_price !== null)
                ? (float) $pService->custom_price
                : (float) $catalog->base_price;
            $price = ProviderDiscountService::discounted($basePrice, $discountPercent);

            // Duration snapshot rule: staff custom duration -> provider custom duration -> catalog duration
            if ($sService && $sService->custom_duration_minutes !== null) {
                $duration = (int) $sService->custom_duration_minutes;
            } elseif ($pService && $pService->custom_duration_minutes !== null) {
                $duration = (int) $pService->custom_duration_minutes;
            } else {
                $duration = (int) $catalog->duration_minutes;
            }

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
     * Supports specific staff member, "any available" union across staff, and legacy single-calendar providers.
     *
     * @return array<int, array<string, mixed>>
     */
    public function getAvailableSlots(
        User|ProviderProfile|int $provider,
        array $serviceIds,
        string $date,
        ?int $excludeAppointmentId = null,
        ?ProviderPackage $package = null,
        ?int $staffId = null,
        bool $customerVisibleOnly = true,
        bool $allowUnverifiedManual = false
    ): array {
        $profile = $this->resolveProviderProfile($provider);
        if (!$profile) {
            return [];
        }

        if (!$allowUnverifiedManual) {
            if (!$profile->is_approved || $profile->identity_status !== 'APPROVED' || !$profile->isVerified()) {
                return [];
            }
        }

        if ($package) {
            if (!$package->is_active || $package->provider_profile_id !== $profile->id) {
                return [];
            }
        } elseif (!$this->providerOffersAllServices($profile, $serviceIds)) {
            return [];
        }

        if ($staffId !== null) {
            $staff = $profile->staff()
                ->with(['staffServices', 'weeklySchedules.breaks', 'timeOffs'])
                ->whereKey($staffId)
                ->first();

            if (!$staff || !$staff->is_active || $staff->archived_at !== null || !$staff->accepts_appointments) {
                return [];
            }
            if ($customerVisibleOnly && !$staff->visible_to_customers) {
                return [];
            }

            return $this->getAvailableSlotsForStaff(
                $profile,
                $staff,
                $serviceIds,
                $date,
                $excludeAppointmentId,
                $package
            );
        }

        if ($this->providerHasActiveStaff($profile)) {
            $eligibleStaff = $this->getEligibleStaff($profile, $serviceIds, $package, $customerVisibleOnly);
            if ($eligibleStaff->isEmpty()) {
                return [];
            }

            $merged = [];
            foreach ($eligibleStaff as $staff) {
                $staffSlots = $this->getAvailableSlotsForStaff(
                    $profile,
                    $staff,
                    $serviceIds,
                    $date,
                    $excludeAppointmentId,
                    $package
                );
                foreach ($staffSlots as $slot) {
                    $key = $slot['start_time'];
                    if (!isset($merged[$key])) {
                        $merged[$key] = [
                            'start_time' => $slot['start_time'],
                            'end_time' => $slot['end_time'],
                            'available_staff_ids' => [$staff->id],
                        ];
                    } else {
                        $merged[$key]['available_staff_ids'][] = $staff->id;
                    }
                }
            }

            ksort($merged);
            return array_values($merged);
        }

        // Legacy single-calendar shop without ProviderStaff records
        return $this->computeWindowSlots(
            $profile,
            null,
            $serviceIds,
            $date,
            $excludeAppointmentId,
            $package
        );
    }

    /**
     * Slots strictly for a single staff member (never blocked by sibling staff appointments).
     *
     * @return array<int, array<string, mixed>>
     */
    public function getAvailableSlotsForStaff(
        ProviderProfile $profile,
        ProviderStaff $staff,
        array $serviceIds,
        string $date,
        ?int $excludeAppointmentId = null,
        ?ProviderPackage $package = null
    ): array {
        if ((int) $staff->provider_profile_id !== (int) $profile->id) {
            return [];
        }
        if (!$staff->is_active || $staff->archived_at !== null || !$staff->accepts_appointments) {
            return [];
        }

        $effectiveServiceIds = $this->effectiveServiceIds($serviceIds, $package);
        if (!empty($effectiveServiceIds) && !$this->staffOffersAllServices($staff, $effectiveServiceIds)) {
            return [];
        }

        return $this->computeWindowSlots(
            $profile,
            $staff,
            $serviceIds,
            $date,
            $excludeAppointmentId,
            $package
        );
    }

    /**
     * Shared window + conflict solver for a specific staff member or legacy shop calendar.
     *
     * @return array<int, array<string, mixed>>
     */
    private function computeWindowSlots(
        ProviderProfile $profile,
        ?ProviderStaff $staff,
        array $serviceIds,
        string $date,
        ?int $excludeAppointmentId,
        ?ProviderPackage $package
    ): array {
        $tz = (string) config('app.timezone', 'Europe/Istanbul');
        $carbonDate = Carbon::parse($date, $tz)->startOfDay();
        $today = Carbon::today($tz);
        if ($carbonDate->lt($today)) {
            return [];
        }

        $dateStr = $carbonDate->format('Y-m-d');

        // Shop closed date always closes all staff calendars too
        if ($profile->closedDates()->where('date', $dateStr)->exists()) {
            return [];
        }

        $dayOfWeek = strtolower($carbonDate->format('l'));
        $shopSchedule = $profile->weeklySchedules()
            ->with('breaks')
            ->where('day_of_week', $dayOfWeek)
            ->first();

        if (!$shopSchedule || !$shopSchedule->is_enabled || !$shopSchedule->start_time || !$shopSchedule->end_time) {
            return [];
        }

        $shiftStartMin = $this->timeToMinutes($shopSchedule->start_time);
        $shiftEndMin = $this->timeToMinutes($shopSchedule->end_time);

        if ($shiftStartMin >= $shiftEndMin) {
            return [];
        }

        // Parse shop breaks
        $breaks = [];
        foreach ($shopSchedule->breaks as $brk) {
            $bStart = $this->timeToMinutes($brk->start_time);
            $bEnd = $this->timeToMinutes($brk->end_time);
            if ($bStart < $bEnd) {
                $breaks[] = ['start' => $bStart, 'end' => $bEnd];
            }
        }

        if ($staff !== null) {
            // Staff leave / time-off check
            $timeOffs = $staff->relationLoaded('timeOffs')
                ? $staff->timeOffs->filter(function ($off) use ($dateStr) {
                    $s = $off->start_date?->format('Y-m-d') ?? (string) $off->start_date;
                    $e = $off->end_date?->format('Y-m-d') ?? (string) $off->end_date;
                    return $s <= $dateStr && $e >= $dateStr;
                })
                : $staff->timeOffs()
                    ->whereDate('start_date', '<=', $dateStr)
                    ->whereDate('end_date', '>=', $dateStr)
                    ->get();

            foreach ($timeOffs as $off) {
                if (!$off->start_time || !$off->end_time) {
                    return []; // Full day leave / holiday
                }
                $oStart = $this->timeToMinutes($off->start_time);
                $oEnd = $this->timeToMinutes($off->end_time);
                if ($oStart < $oEnd) {
                    $breaks[] = ['start' => $oStart, 'end' => $oEnd];
                }
            }

            // Staff custom weekly hours (intersected with shop opening hours)
            $staffSchedules = $staff->relationLoaded('weeklySchedules')
                ? $staff->weeklySchedules
                : $staff->weeklySchedules()->with('breaks')->get();

            if ($staffSchedules->isNotEmpty()) {
                $staffDay = $staffSchedules->firstWhere('day_of_week', $dayOfWeek);
                if (!$staffDay || !$staffDay->is_enabled || !$staffDay->start_time || !$staffDay->end_time) {
                    return [];
                }

                $staffStartMin = $this->timeToMinutes($staffDay->start_time);
                $staffEndMin = $this->timeToMinutes($staffDay->end_time);
                $shiftStartMin = max($shiftStartMin, $staffStartMin);
                $shiftEndMin = min($shiftEndMin, $staffEndMin);

                if ($shiftStartMin >= $shiftEndMin) {
                    return [];
                }

                foreach ($staffDay->breaks as $brk) {
                    $bStart = $this->timeToMinutes($brk->start_time);
                    $bEnd = $this->timeToMinutes($brk->end_time);
                    if ($bStart < $bEnd) {
                        $breaks[] = ['start' => $bStart, 'end' => $bEnd];
                    }
                }
            }
        }

        // Calculate service duration (using staff custom durations if present)
        $durationMinutes = $package
            ? max(15, (int) $package->duration_minutes)
            : $this->calculateDurationAndPrice($profile, $serviceIds, $staff)['total_duration_minutes'];

        // Blocking appointments for this calendar (staff OR unassigned legacy shop appts)
        $apptQuery = Appointment::where('provider_user_id', $profile->user_id)
            ->where('appointment_date', $dateStr)
            ->whereIn('status', self::BLOCKING_STATUSES);

        if ($staff !== null) {
            $apptQuery->where(function ($q) use ($staff) {
                $q->where('staff_id', $staff->id)
                    ->orWhereNull('staff_id');
            });
        }

        if ($excludeAppointmentId) {
            $apptQuery->where('id', '!=', $excludeAppointmentId);
        }

        $busyIntervals = [];
        foreach ($apptQuery->get(['start_time', 'end_time', 'total_duration_minutes']) as $appt) {
            $aStart = $this->timeToMinutes($appt->start_time);
            $aEnd = $this->timeToMinutes($appt->end_time);
            if ($aEnd <= $aStart) {
                $aEnd = $aStart + ($appt->total_duration_minutes ?: 30);
            }
            $busyIntervals[] = ['start' => $aStart, 'end' => $aEnd];
        }

        $isToday = $carbonDate->isSameDay($today);
        $now = Carbon::now($tz);
        $currentMin = (int) $now->format('H') * 60 + (int) $now->format('i');

        $slots = [];
        for ($slotStart = $shiftStartMin; $slotStart < $shiftEndMin; $slotStart += self::SLOT_INTERVAL_MINUTES) {
            $slotEnd = $slotStart + $durationMinutes;

            if ($slotEnd > $shiftEndMin) {
                continue;
            }
            if ($isToday && $slotStart <= $currentMin) {
                continue;
            }

            $blocked = false;
            foreach ($breaks as $b) {
                if ($slotStart < $b['end'] && $slotEnd > $b['start']) {
                    $blocked = true;
                    break;
                }
            }
            if ($blocked) {
                continue;
            }

            foreach ($busyIntervals as $b) {
                if ($slotStart < $b['end'] && $slotEnd > $b['start']) {
                    $blocked = true;
                    break;
                }
            }
            if ($blocked) {
                continue;
            }

            $slots[] = [
                'start_time' => sprintf('%02d:%02d', intdiv($slotStart, 60), $slotStart % 60),
                'end_time' => sprintf('%02d:%02d', intdiv($slotEnd, 60), $slotEnd % 60),
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
        ?ProviderPackage $package = null,
        ?int $staffId = null,
        bool $customerVisibleOnly = true,
        bool $allowUnverifiedManual = false
    ): bool {
        $slots = $this->getAvailableSlots(
            $provider,
            $serviceIds,
            $date,
            $excludeAppointmentId,
            $package,
            $staffId,
            $customerVisibleOnly,
            $allowUnverifiedManual
        );
        $normalizedTime = substr($startTime, 0, 5);

        foreach ($slots as $slot) {
            if ($slot['start_time'] === $normalizedTime) {
                return true;
            }
        }

        return false;
    }

    /**
     * Resolve and lock-verify the target staff member inside an active DB transaction.
     * Enforces single-staff exclusivity while allowing parallel bookings across different staff.
     */
    public function resolveStaffForBooking(
        ProviderProfile $profile,
        array $serviceIds,
        string $date,
        string $startTime,
        ?int $requestedStaffId = null,
        ?int $excludeAppointmentId = null,
        ?ProviderPackage $package = null,
        bool $customerVisibleOnly = true,
        bool $allowUnverifiedManual = false
    ): ?ProviderStaff {
        $normalizedTime = substr($startTime, 0, 5);

        if ($requestedStaffId !== null) {
            $staff = $profile->staff()
                ->with(['staffServices', 'weeklySchedules.breaks', 'timeOffs'])
                ->whereKey($requestedStaffId)
                ->lockForUpdate()
                ->first();

            if (!$staff || !$staff->is_active || $staff->archived_at !== null || !$staff->accepts_appointments) {
                abort(422, 'Seçilen çalışan şu anda randevu kabul etmiyor.');
            }
            if ($customerVisibleOnly && !$staff->visible_to_customers) {
                abort(422, 'Seçilen çalışan müşterilere açık değil.');
            }

            $effectiveIds = $this->effectiveServiceIds($serviceIds, $package);
            if (!empty($effectiveIds) && !$this->staffOffersAllServices($staff, $effectiveIds)) {
                abort(422, 'Seçilen çalışan bu hizmeti vermemektedir.');
            }

            if (!$allowUnverifiedManual && (!$profile->is_approved || $profile->identity_status !== 'APPROVED' || !$profile->isVerified())) {
                abort(422, 'Yalnızca mesleki belgesi onaylı uzmanlardan randevu alınabilir.');
            }

            $slots = $this->getAvailableSlotsForStaff(
                $profile,
                $staff,
                $serviceIds,
                $date,
                $excludeAppointmentId,
                $package
            );
            foreach ($slots as $slot) {
                if ($slot['start_time'] === $normalizedTime) {
                    return $staff;
                }
            }

            abort(409, 'Seçilen çalışanın bu saatte uygunluğu bulunmuyor. Lütfen başka bir saat veya usta seçin.');
        }

        // Explicit "Fark Etmez — İlk Müsait Usta" across active staff
        if ($this->providerHasActiveStaff($profile)) {
            $eligibleStaff = $this->getEligibleStaff($profile, $serviceIds, $package, $customerVisibleOnly);
            if ($eligibleStaff->isEmpty()) {
                abort(422, 'Seçilen hizmetler için uygun çalışan bulunamadı.');
            }

            if (!$allowUnverifiedManual && (!$profile->is_approved || $profile->identity_status !== 'APPROVED' || !$profile->isVerified())) {
                abort(422, 'Yalnızca mesleki belgesi onaylı uzmanlardan randevu alınabilir.');
            }

            $dateCounts = Appointment::where('provider_user_id', $profile->user_id)
                ->where('appointment_date', $date)
                ->whereIn('status', self::BLOCKING_STATUSES)
                ->selectRaw('staff_id, COUNT(*) as cnt')
                ->groupBy('staff_id')
                ->pluck('cnt', 'staff_id');

            $candidates = [];
            foreach ($eligibleStaff as $staff) {
                $slots = $this->getAvailableSlotsForStaff(
                    $profile,
                    $staff,
                    $serviceIds,
                    $date,
                    $excludeAppointmentId,
                    $package
                );
                foreach ($slots as $slot) {
                    if ($slot['start_time'] === $normalizedTime) {
                        $candidates[] = [
                            'staff' => $staff,
                            'load' => (int) ($dateCounts[$staff->id] ?? 0),
                        ];
                        break;
                    }
                }
            }

            if (empty($candidates)) {
                abort(409, 'Bu saat artık müsait değil. Lütfen başka bir saat seçin.');
            }

            usort($candidates, function ($a, $b) {
                if ($a['load'] !== $b['load']) {
                    return $a['load'] <=> $b['load'];
                }
                if ($a['staff']->sort_order !== $b['staff']->sort_order) {
                    return $a['staff']->sort_order <=> $b['staff']->sort_order;
                }
                return $a['staff']->id <=> $b['staff']->id;
            });

            return $candidates[0]['staff'];
        }

        // Legacy salon without configured staff
        $isAvailable = $this->isSlotAvailable(
            $profile,
            $serviceIds,
            $date,
            $normalizedTime,
            $excludeAppointmentId,
            $package,
            null,
            $customerVisibleOnly,
            $allowUnverifiedManual
        );
        if (!$isAvailable) {
            abort(409, 'Bu saat artık müsait değil. Lütfen başka bir saat seçin.');
        }

        return null;
    }

    /**
     * Verify whether reassigning an existing appointment to $staff causes any calendar conflict.
     */
    public function assertStaffCanTakeExactWindow(
        ProviderProfile $profile,
        ProviderStaff $staff,
        array $serviceIds,
        string $date,
        string $startTime,
        int $durationMinutes,
        int $excludeAppointmentId,
        ?ProviderPackage $package = null
    ): void {
        if ((int) $staff->provider_profile_id !== (int) $profile->id) {
            abort(404, 'Çalışan bulunamadı.');
        }
        if (!$staff->is_active || $staff->archived_at !== null || !$staff->accepts_appointments) {
            abort(422, 'Seçilen çalışan randevu kabul etmiyor.');
        }

        $effectiveIds = $this->effectiveServiceIds($serviceIds, $package);
        if (!empty($effectiveIds) && !$this->staffOffersAllServices($staff, $effectiveIds)) {
            abort(422, 'Seçilen çalışan bu randevunun hizmetlerini vermemektedir.');
        }

        $startMin = $this->timeToMinutes($startTime);
        $endMin = $startMin + max(15, $durationMinutes);
        $tz = (string) config('app.timezone', 'Europe/Istanbul');
        $dateStr = Carbon::parse($date, $tz)->format('Y-m-d');
        $dayOfWeek = strtolower(Carbon::parse($date, $tz)->format('l'));

        if ($profile->closedDates()->where('date', $dateStr)->exists()) {
            abort(409, 'İşletme bu tarihte kapalı görünüyor.');
        }

        $shopDay = $profile->weeklySchedules()->with('breaks')->where('day_of_week', $dayOfWeek)->first();
        if (!$shopDay || !$shopDay->is_enabled || !$shopDay->start_time || !$shopDay->end_time) {
            abort(409, 'İşletme bu günde çalışmıyor.');
        }
        if ($startMin < $this->timeToMinutes($shopDay->start_time) || $endMin > $this->timeToMinutes($shopDay->end_time)) {
            abort(409, 'Randevu saati işletme mesai saatleri dışında.');
        }
        foreach ($shopDay->breaks as $brk) {
            if ($startMin < $this->timeToMinutes($brk->end_time) && $endMin > $this->timeToMinutes($brk->start_time)) {
                abort(409, 'Randevu işletme molası ile çakışıyor.');
            }
        }

        $staffSchedules = $staff->weeklySchedules()->with('breaks')->get();
        if ($staffSchedules->isNotEmpty()) {
            $staffDay = $staffSchedules->firstWhere('day_of_week', $dayOfWeek);
            if (!$staffDay || !$staffDay->is_enabled || !$staffDay->start_time || !$staffDay->end_time) {
                abort(409, 'Seçilen çalışan bu günde çalışmıyor.');
            }
            if ($startMin < $this->timeToMinutes($staffDay->start_time) || $endMin > $this->timeToMinutes($staffDay->end_time)) {
                abort(409, 'Randevu saati çalışanın mesai saatleri dışında.');
            }
            foreach ($staffDay->breaks as $brk) {
                if ($startMin < $this->timeToMinutes($brk->end_time) && $endMin > $this->timeToMinutes($brk->start_time)) {
                    abort(409, 'Randevu çalışanın molası ile çakışıyor.');
                }
            }
        }

        $timeOffs = $staff->timeOffs()
            ->whereDate('start_date', '<=', $dateStr)
            ->whereDate('end_date', '>=', $dateStr)
            ->get();
        foreach ($timeOffs as $off) {
            if (!$off->start_time || !$off->end_time) {
                abort(409, 'Seçilen çalışan bu tarihte izinli.');
            }
            if ($startMin < $this->timeToMinutes($off->end_time) && $endMin > $this->timeToMinutes($off->start_time)) {
                abort(409, 'Randevu saati çalışanın izin saatleriyle çakışıyor.');
            }
        }

        $existing = Appointment::where('provider_user_id', $profile->user_id)
            ->where('appointment_date', $dateStr)
            ->where('id', '!=', $excludeAppointmentId)
            ->whereIn('status', self::BLOCKING_STATUSES)
            ->where(function ($q) use ($staff) {
                $q->where('staff_id', $staff->id)->orWhereNull('staff_id');
            })
            ->get(['start_time', 'end_time', 'total_duration_minutes']);

        foreach ($existing as $appt) {
            $aStart = $this->timeToMinutes($appt->start_time);
            $aEnd = $this->timeToMinutes($appt->end_time);
            if ($aEnd <= $aStart) {
                $aEnd = $aStart + ($appt->total_duration_minutes ?: 30);
            }
            if ($startMin < $aEnd && $endMin > $aStart) {
                abort(409, 'Seçilen çalışanın bu saatte başka bir randevusu var.');
            }
        }
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

        $shiftStart = $this->timeToMinutes($schedule->start_time);
        $shiftEnd = $this->timeToMinutes($schedule->end_time);
        $jobStart = (int) $now->format('H') * 60 + (int) $now->format('i');
        $jobEnd = $jobStart + $durationMinutes;

        if ($jobStart < $shiftStart || $jobEnd > $shiftEnd) {
            return ['available' => false, 'reason' => 'Hizmet veren şu anda çalışma saatleri dışında.'];
        }

        foreach ($schedule->breaks as $brk) {
            if ($jobStart < $this->timeToMinutes($brk->end_time) && $jobEnd > $this->timeToMinutes($brk->start_time)) {
                return ['available' => false, 'reason' => 'Hizmet veren şu anda molada.'];
            }
        }

        $appointments = Appointment::where('provider_user_id', $profile->user_id)
            ->where('appointment_date', $today->format('Y-m-d'))
            ->whereIn('status', self::BLOCKING_STATUSES)
            ->get(['start_time', 'end_time', 'total_duration_minutes']);

        foreach ($appointments as $appt) {
            $aStart = $this->timeToMinutes($appt->start_time);
            $aEnd = $this->timeToMinutes($appt->end_time);
            if ($aEnd <= $aStart) {
                $aEnd = $aStart + ($appt->total_duration_minutes ?: 30);
            }
            if ($jobStart < $aEnd && $jobEnd > $aStart) {
                return ['available' => false, 'reason' => 'Hizmet verenin bu saatte randevusu var.'];
            }
        }

        return ['available' => true, 'reason' => null];
    }

    private function timeToMinutes(string $time): int
    {
        [$h, $m] = explode(':', substr($time, 0, 5));
        return (int) $h * 60 + (int) $m;
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
            if (!in_array($day, $validDays, true)) {
                throw ValidationException::withMessages(['schedule' => "Geçersiz gün adı: {$day}"]);
            }

            if (in_array($day, $seenDays, true)) {
                throw ValidationException::withMessages(['schedule' => "Bir güne ait birden fazla program kaydı olamaz: {$day}"]);
            }
            $seenDays[] = $day;

            $enabled = (bool) ($dayData['enabled'] ?? $dayData['is_enabled'] ?? false);
            if ($enabled) {
                $start = $dayData['start_time'] ?? null;
                $end = $dayData['end_time'] ?? null;

                if (!$start || !$end) {
                    throw ValidationException::withMessages(['schedule' => "{$day} günü aktif ancak mesai saatleri belirtilmemiş."]);
                }

                $sMin = $this->timeToMinutes((string) $start);
                $eMin = $this->timeToMinutes((string) $end);

                if ($sMin >= $eMin) {
                    throw ValidationException::withMessages(['schedule' => "{$day} günü başlangıç saati ({$start}) bitiş saatinden ({$end}) önce olmalıdır."]);
                }

                $breaks = $dayData['breaks'] ?? [];
                $parsedBreaks = [];

                foreach ($breaks as $brk) {
                    $bStart = $brk['start_time'] ?? null;
                    $bEnd = $brk['end_time'] ?? null;

                    if (!$bStart || !$bEnd) {
                        throw ValidationException::withMessages(['schedule' => 'Mola saatleri eksik.']);
                    }

                    $bsMin = $this->timeToMinutes((string) $bStart);
                    $beMin = $this->timeToMinutes((string) $bEnd);

                    if ($bsMin >= $beMin) {
                        throw ValidationException::withMessages(['schedule' => "Mola başlangıç saati bitiş saatinden önce olmalıdır ({$bStart} - {$bEnd})."]);
                    }

                    if ($bsMin < $sMin || $beMin > $eMin) {
                        throw ValidationException::withMessages(['schedule' => "Mola ({$bStart} - {$bEnd}) mesai saatleri ({$start} - {$end}) dışında olamaz."]);
                    }

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
