<?php

namespace App\Http\Controllers;

use App\Http\Resources\ProviderAppointmentResource;
use App\Models\Appointment;
use App\Models\AppointmentAlternativeSlot;
use App\Models\LocationShareGrant;
use App\Models\ProviderPackage;
use App\Models\ProviderProfile;
use App\Services\ProviderAvailabilityService;
use App\Services\ServiceLifecycleService;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class ProviderAppointmentController extends Controller
{
    public function __construct(
        protected ProviderAvailabilityService $availabilityService
    ) {}

    /**
     * List appointments assigned to authenticated provider.
     */
    public function index(Request $request): JsonResponse
    {
        $user = $request->user();

        $query = Appointment::with(['customer', 'services', 'alternativeSlots', 'disputeCase'])
            ->where('provider_user_id', $user->id);

        if ($request->filled('status')) {
            $status = strtoupper($request->query('status'));
            $query->where('status', $status);
        }

        if ($request->query('filter') === 'today') {
            $query->where('appointment_date', Carbon::today()->format('Y-m-d'));
        } elseif ($request->query('filter') === 'upcoming') {
            $query->where('appointment_date', '>=', Carbon::today()->format('Y-m-d'));
        }

        $appointments = $query->orderBy('appointment_date')
            ->orderBy('start_time')
            ->get();

        return response()->json([
            'success' => true,
            'data' => ProviderAppointmentResource::collection($appointments),
        ]);
    }

    /**
     * Show single appointment detail for provider.
     */
    public function show(Request $request, $appointment): JsonResponse
    {
        $user = $request->user();

        $appt = Appointment::with(['customer', 'services', 'alternativeSlots'])
            ->where('id', $appointment)
            ->where('provider_user_id', $user->id)
            ->first();

        if (!$appt) {
            return response()->json([
                'success' => false,
                'message' => 'Randevu bulunamadı veya yetkiniz yok.',
            ], 404);
        }

        return response()->json([
            'success' => true,
            'data' => new ProviderAppointmentResource($appt),
        ]);
    }

    /**
     * Provider confirms an appointment.
     * Re-checks availability with locking to prevent double-booking.
     */
    public function confirm(Request $request, $appointment): JsonResponse
    {
        $user = $request->user();

        $appt = Appointment::with(['services'])
            ->where('id', $appointment)
            ->where('provider_user_id', $user->id)
            ->first();

        if (!$appt) {
            return response()->json([
                'success' => false,
                'message' => 'Randevu bulunamadı veya yetkiniz yok.',
            ], 404);
        }

        if ($appt->status === 'CONFIRMED') {
            return response()->json([
                'success' => true,
                'message' => 'Bu randevu zaten onaylanmış.',
                'data' => new ProviderAppointmentResource($appt),
            ]);
        }

        if (!in_array($appt->status, ['PENDING', 'ALTERNATIVE_PROPOSED'])) {
            return response()->json([
                'success' => false,
                'message' => "Bu durumdaki randevu onaylanamaz: {$appt->status}",
            ], 422);
        }

        $profile = $user->providerProfile;
        if (!$profile) {
            return response()->json([
                'success' => false,
                'message' => 'Hizmet veren profili bulunamadı.',
            ], 404);
        }

        // Concurrency Protection & Availability Re-check
        $updated = DB::transaction(function () use ($appt, $profile) {
            DB::table('appointments')
                ->where('provider_user_id', $profile->user_id)
                ->where('appointment_date', $appt->appointment_date->format('Y-m-d'))
                ->whereIn('status', ['PENDING', 'ALTERNATIVE_PROPOSED', 'CONFIRMED'])
                ->lockForUpdate()
                ->get();

            $serviceIds = $appt->services->pluck('id')->toArray();
            $dateStr = $appt->appointment_date->format('Y-m-d');
            $timeStr = substr($appt->start_time, 0, 5);

            $isAvailable = $this->availabilityService->isSlotAvailable(
                $profile,
                $serviceIds,
                $dateStr,
                $timeStr,
                $appt->id,
                // A package appointment is booked as the package the provider owns;
                // its individual services are not necessarily offered on their own.
                $this->appointmentPackage($appt)
            );

            if (!$isAvailable) {
                abort(409, 'Bu saat artık müsait değil. Alternatif saat önerin.');
            }

            // Financial Setup (Atomic Commission Reservation or Pending Online Payment)
            $paymentMethod = strtoupper($appt->payment_method ?? 'CASH');
            $financialService = app(\App\Services\FinancialService::class);

            if ($paymentMethod === 'CASH') {
                $financialService->reserveCashCommission(
                    LocationShareGrant::RESOURCE_SCHEDULED_APPOINTMENT,
                    $appt->id,
                    $profile->user_id,
                    (string) $appt->total_price
                );
            } else {
                $financialService->createPendingOnlinePayment(
                    LocationShareGrant::RESOURCE_SCHEDULED_APPOINTMENT,
                    $appt->id,
                    $appt->customer_user_id,
                    $profile->user_id,
                    (string) $appt->total_price
                );
            }

            $appt->update([
                'status' => 'CONFIRMED',
                'confirmed_at' => now(),
            ]);

            // Generate canonical Service Start Verification (4-digit cryptographically secure code)
            app(ServiceLifecycleService::class)->ensureStartVerificationForResource(
                LocationShareGrant::RESOURCE_SCHEDULED_APPOINTMENT,
                $appt->id,
                $appt->customer_user_id,
                $appt->provider_user_id
            );

            // Expire any lingering alternative slots
            $appt->alternativeSlots()->where('status', 'PENDING')->update(['status' => 'EXPIRED']);

            return $appt;
        });

        app(\App\Services\NotificationService::class)->notifyUser(
            $updated->customer_user_id,
            \App\Models\UserNotification::TYPE_APPOINTMENT_CONFIRMED,
            'Randevunuz Onaylandı',
            'Randevu talebiniz hizmet veren tarafından onaylandı.',
            \App\Models\UserNotification::RESOURCE_SCHEDULED_APPOINTMENT,
            $updated->id,
            '/customer',
            [
                'appointment_id' => $updated->id,
                'appointment_date' => $updated->appointment_date?->format('Y-m-d') ?: (string) $updated->appointment_date,
                'start_time' => (string) $updated->start_time,
            ],
            "APPOINTMENT_CONFIRMED:{$updated->id}:{$updated->customer_user_id}"
        );

        return response()->json([
            'success' => true,
            'message' => 'Randevu başarıyla onaylandı.',
            'data' => new ProviderAppointmentResource($updated->fresh(['customer', 'services', 'alternativeSlots'])),
        ]);
    }

    /**
     * Provider rejects an appointment with required reason.
     */
    public function reject(Request $request, $appointment): JsonResponse
    {
        $user = $request->user();

        $appt = Appointment::where('id', $appointment)
            ->where('provider_user_id', $user->id)
            ->first();

        if (!$appt) {
            return response()->json([
                'success' => false,
                'message' => 'Randevu bulunamadı veya yetkiniz yok.',
            ], 404);
        }

        $validated = $request->validate([
            'reason' => 'required|string|min:3|max:500',
        ]);

        $appt->update([
            'status' => 'REJECTED',
            'rejection_reason' => $validated['reason'],
            'rejected_at' => now(),
        ]);

        $appt->alternativeSlots()->update(['status' => 'EXPIRED']);

        app(\App\Services\NotificationService::class)->notifyUser(
            $appt->customer_user_id,
            \App\Models\UserNotification::TYPE_APPOINTMENT_REJECTED,
            'Randevu Talebi Reddedildi',
            'Randevu talebiniz hizmet veren tarafından reddedildi.' . (!empty($validated['reason']) ? ' Gerekçe: ' . $validated['reason'] : ''),
            \App\Models\UserNotification::RESOURCE_SCHEDULED_APPOINTMENT,
            $appt->id,
            '/customer',
            [
                'appointment_id' => $appt->id,
                'reason' => $validated['reason'],
            ],
            "APPOINTMENT_REJECTED:{$appt->id}:{$appt->customer_user_id}"
        );

        return response()->json([
            'success' => true,
            'message' => 'Randevu talebi reddedildi.',
            'data' => new ProviderAppointmentResource($appt->fresh(['customer', 'services', 'alternativeSlots'])),
        ]);
    }

    /**
     * Provider proposes 1 to 5 alternative slots.
     * Each slot is strictly validated via the availability engine.
     */
    public function proposeAlternatives(Request $request, $appointment): JsonResponse
    {
        $user = $request->user();
        $profile = $user->providerProfile;

        $appt = Appointment::with(['services'])
            ->where('id', $appointment)
            ->where('provider_user_id', $user->id)
            ->first();

        if (!$appt) {
            return response()->json([
                'success' => false,
                'message' => 'Randevu bulunamadı veya yetkiniz yok.',
            ], 404);
        }

        $validated = $request->validate([
            'slots' => 'required|array|min:1|max:5',
            'slots.*.date' => 'required|date_format:Y-m-d',
            'slots.*.time' => 'required|date_format:H:i',
        ]);

        $slots = $validated['slots'];
        $serviceIds = $appt->services->pluck('id')->toArray();
        $durationMinutes = $appt->total_duration_minutes ?: 30;

        // Check for duplicate slots in payload
        $uniqueKeys = [];
        foreach ($slots as $slot) {
            $key = $slot['date'] . '_' . substr($slot['time'], 0, 5);
            if (in_array($key, $uniqueKeys)) {
                return response()->json([
                    'success' => false,
                    'message' => 'Aynı alternatif saat birden fazla kez eklenemez.',
                ], 422);
            }
            $uniqueKeys[] = $key;
        }

        // Validate each slot against the central availability engine
        foreach ($slots as $slot) {
            $isAvailable = $this->availabilityService->isSlotAvailable(
                $profile,
                $serviceIds,
                $slot['date'],
                $slot['time'],
                $appt->id,
                $this->appointmentPackage($appt)
            );

            if (!$isAvailable) {
                return response()->json([
                    'success' => false,
                    'message' => "{$slot['date']} {$slot['time']} saati artık müsait değil.",
                ], 422);
            }
        }

        DB::transaction(function () use ($appt, $slots, $durationMinutes) {
            // Expire previous pending alternatives
            $appt->alternativeSlots()->where('status', 'PENDING')->update(['status' => 'EXPIRED']);

            foreach ($slots as $slot) {
                [$sH, $sM] = explode(':', substr($slot['time'], 0, 5));
                $sMin = (int)$sH * 60 + (int)$sM;
                $eMin = $sMin + $durationMinutes;

                $startStr = sprintf('%02d:%02d:00', floor($sMin / 60), $sMin % 60);
                $endStr = sprintf('%02d:%02d:00', floor($eMin / 60), $eMin % 60);

                AppointmentAlternativeSlot::create([
                    'appointment_id' => $appt->id,
                    'date' => $slot['date'],
                    'start_time' => $startStr,
                    'end_time' => $endStr,
                    'status' => 'PENDING',
                ]);
            }

            $appt->update([
                'status' => 'ALTERNATIVE_PROPOSED',
            ]);
        });

        app(\App\Services\NotificationService::class)->notifyUser(
            $appt->customer_user_id,
            \App\Models\UserNotification::TYPE_APPOINTMENT_ALTERNATIVE_PROPOSED,
            'Alternatif Randevu Saatleri Önerildi',
            'Hizmet veren randevunuz için alternatif saatler önerdi.',
            \App\Models\UserNotification::RESOURCE_SCHEDULED_APPOINTMENT,
            $appt->id,
            '/customer',
            [
                'appointment_id' => $appt->id,
                'slot_count' => count($slots),
            ],
            "APPOINTMENT_ALTERNATIVE_PROPOSED:{$appt->id}:{$appt->customer_user_id}"
        );

        return response()->json([
            'success' => true,
            'message' => 'Alternatif saat teklifleri müşteriye iletildi.',
            'data' => new ProviderAppointmentResource($appt->fresh(['customer', 'services', 'alternativeSlots'])),
        ]);
    }

    /**
     * The package an appointment was booked as, when it is a package booking.
     * Availability must be evaluated against the package the provider owns,
     * not against the individual services it bundles.
     */
    private function appointmentPackage(Appointment $appt): ?ProviderPackage
    {
        return $appt->provider_package_id
            ? ProviderPackage::find($appt->provider_package_id)
            : null;
    }
}
