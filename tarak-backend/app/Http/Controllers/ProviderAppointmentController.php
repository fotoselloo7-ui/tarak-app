<?php

namespace App\Http\Controllers;

use App\Http\Resources\ProviderAppointmentResource;
use App\Models\Appointment;
use App\Models\AppointmentAlternativeSlot;
use App\Models\AppointmentService;
use App\Models\Conversation;
use App\Models\CustomerFavorite;
use App\Models\LocationShareGrant;
use App\Models\ProviderPackage;
use App\Models\ProviderProfile;
use App\Models\ServiceRequest;
use App\Models\User;
use App\Models\UserNotification;
use App\Services\NotificationService;
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

        $query = Appointment::with(['customer', 'staff', 'services', 'alternativeSlots', 'disputeCase'])
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

        $appt = Appointment::with(['customer', 'staff', 'services', 'alternativeSlots', 'disputeCase'])
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
     * Authorized past/active customers associated with THIS provider (never exposes all users or birth_date).
     */
    public function customers(Request $request): JsonResponse
    {
        $providerUserId = (int) $request->user()->id;
        $term = trim((string) $request->query('q', ''));

        $query = User::query()
            ->where('role', User::ROLE_CUSTOMER)
            ->where('status', 'active')
            ->where(function ($q) use ($providerUserId) {
                $q->whereExists(function ($sub) use ($providerUserId) {
                    $sub->select(DB::raw(1))
                        ->from('appointments')
                        ->whereColumn('appointments.customer_user_id', 'users.id')
                        ->where('appointments.provider_user_id', $providerUserId);
                })->orWhereExists(function ($sub) use ($providerUserId) {
                    $sub->select(DB::raw(1))
                        ->from('service_requests')
                        ->whereColumn('service_requests.customer_user_id', 'users.id')
                        ->where(function ($sr) use ($providerUserId) {
                            $sr->where('service_requests.assigned_provider_user_id', $providerUserId)
                                ->orWhere('service_requests.target_provider_user_id', $providerUserId);
                        });
                })->orWhereExists(function ($sub) use ($providerUserId) {
                    $sub->select(DB::raw(1))
                        ->from('conversations')
                        ->whereColumn('conversations.customer_user_id', 'users.id')
                        ->where('conversations.provider_user_id', $providerUserId);
                })->orWhereExists(function ($sub) use ($providerUserId) {
                    $sub->select(DB::raw(1))
                        ->from('customer_favorites')
                        ->whereColumn('customer_favorites.customer_user_id', 'users.id')
                        ->where('customer_favorites.provider_user_id', $providerUserId);
                });
            });

        if ($term !== '') {
            $query->where('name', 'like', '%' . $term . '%');
        }

        $customers = $query->orderBy('name')->limit(50)->get(['id', 'name', 'avatar_url']);

        return response()->json([
            'success' => true,
            'data' => $customers->map(fn (User $c) => [
                'id' => $c->id,
                'name' => $c->name,
                'avatar_url' => \App\Support\MediaUrl::resolve($c->avatar_url),
            ])->values(),
        ]);
    }

    /**
     * Provider manually creates a calendar appointment (e.g. phone booking)
     * for an authorized Tarak customer OR a consenting non-member guest.
     */
    public function storeManual(Request $request): JsonResponse
    {
        $user = $request->user();
        $profile = $user->providerProfile;
        if (!$profile) {
            return response()->json(['success' => false, 'message' => 'Hizmet veren profili bulunamadı.'], 404);
        }

        $validated = $request->validate([
            'customer_mode' => ['required', 'string', 'in:registered,guest'],
            'customer_user_id' => ['required_if:customer_mode,registered', 'nullable', 'integer', 'exists:users,id'],
            'guest_customer_name' => ['required_if:customer_mode,guest', 'nullable', 'string', 'min:2', 'max:120'],
            'guest_customer_phone' => ['nullable', 'string', 'max:30'],
            'guest_customer_consent' => ['nullable', 'boolean'],
            'provider_package_id' => ['nullable', 'integer'],
            'service_ids' => ['required_without:provider_package_id', 'array', 'min:1'],
            'service_ids.*' => ['required', 'integer'],
            'staff_id' => ['nullable', 'integer', 'min:1'],
            'date' => ['required', 'date_format:Y-m-d'],
            'time' => ['required', 'date_format:H:i'],
            'note' => ['nullable', 'string', 'max:1000'],
        ]);

        $isGuest = $validated['customer_mode'] === 'guest';
        $customer = null;

        if ($isGuest) {
            if (!filter_var($validated['guest_customer_consent'] ?? false, FILTER_VALIDATE_BOOLEAN)) {
                return response()->json([
                    'success' => false,
                    'message' => 'Misafir müşteri randevusu için müşteriden kayıt izni alındığı onaylanmalıdır.',
                ], 422);
            }
        } else {
            $customer = User::whereKey((int) $validated['customer_user_id'])
                ->where('role', User::ROLE_CUSTOMER)
                ->first();
            if (!$customer) {
                return response()->json(['success' => false, 'message' => 'Seçilen Tarak müşteri hesabı bulunamadı.'], 422);
            }
            if (!$this->isAuthorizedCustomerOfProvider((int) $customer->id, (int) $user->id)) {
                return response()->json([
                    'success' => false,
                    'message' => 'Yalnızca işletmenizle daha önce etkileşimi olan Tarak müşterilerine randevu eklenebilir.',
                ], 403);
            }
        }

        $offering = null;
        if (!empty($validated['provider_package_id'])) {
            $offering = app(\App\Services\ProviderOfferingService::class)->resolveOffering(null, (int) $validated['provider_package_id']);
            if ((int) $offering['profile']->id !== (int) $profile->id) {
                return response()->json(['success' => false, 'message' => 'Seçilen paket işletmenize ait değil.'], 422);
            }
            $validated['service_ids'] = $offering['service_ids'];
        } elseif (!$this->availabilityService->providerOffersAllServices($profile, $validated['service_ids'])) {
            return response()->json([
                'success' => false,
                'message' => 'İstenen hizmetlerin tamamı işletmenizde aktif değil.',
            ], 422);
        }

        $package = $offering ? ProviderPackage::find($offering['provider_package_id']) : null;
        $requestedStaffId = isset($validated['staff_id']) ? (int) $validated['staff_id'] : null;

        $appointment = DB::transaction(function () use ($user, $profile, $customer, $isGuest, $validated, $offering, $package, $requestedStaffId) {
            DB::table('appointments')
                ->where('provider_user_id', $profile->user_id)
                ->where('appointment_date', $validated['date'])
                ->whereIn('status', ProviderAvailabilityService::BLOCKING_STATUSES)
                ->lockForUpdate()
                ->get();

            $assignedStaff = $this->availabilityService->resolveStaffForBooking(
                $profile,
                $validated['service_ids'],
                $validated['date'],
                $validated['time'],
                $requestedStaffId,
                null,
                $package,
                customerVisibleOnly: false,
                allowUnverifiedManual: true
            );

            $calc = $offering
                ? [
                    'total_price' => $offering['price'],
                    'total_duration_minutes' => $offering['duration_minutes'],
                    'services_data' => array_map(fn ($item) => [
                        'service_id' => $item['service_id'],
                        'price_snapshot' => 0,
                        'duration_minutes_snapshot' => 0,
                    ], $offering['snapshot']['items']),
                ]
                : $this->availabilityService->calculateDurationAndPrice($profile, $validated['service_ids'], $assignedStaff);

            [$sH, $sM] = explode(':', substr($validated['time'], 0, 5));
            $sMin = (int) $sH * 60 + (int) $sM;
            $eMin = $sMin + $calc['total_duration_minutes'];

            $appt = Appointment::create([
                'customer_user_id' => $isGuest ? null : $customer->id,
                'provider_user_id' => $profile->user_id,
                'staff_id' => $assignedStaff?->id,
                'staff_name_snapshot' => $assignedStaff?->full_name,
                'staff_selection_mode' => $requestedStaffId !== null ? 'SPECIFIC' : ($assignedStaff !== null ? 'ANY_AVAILABLE' : 'LEGACY'),
                'booking_source' => 'PROVIDER_MANUAL',
                'is_guest_customer' => $isGuest,
                'guest_customer_name' => $isGuest ? trim((string) $validated['guest_customer_name']) : null,
                'guest_customer_phone' => ($isGuest && !empty($validated['guest_customer_phone']))
                    ? trim((string) $validated['guest_customer_phone'])
                    : null,
                'guest_customer_consent' => $isGuest,
                'created_by_user_id' => $user->id,
                'status' => Appointment::STATUS_CONFIRMED,
                'appointment_date' => $validated['date'],
                'start_time' => sprintf('%02d:%02d:00', intdiv($sMin, 60), $sMin % 60),
                'end_time' => sprintf('%02d:%02d:00', intdiv($eMin, 60), $eMin % 60),
                'payment_method' => 'CASH',
                'total_price' => $calc['total_price'],
                'total_duration_minutes' => $calc['total_duration_minutes'],
                'provider_package_id' => $offering['provider_package_id'] ?? null,
                'offering_snapshot' => $offering['snapshot'] ?? null,
                'approx_province' => $profile->city,
                'approx_district' => $profile->district,
                'approx_neighborhood' => $profile->neighborhood,
                'customer_note' => $validated['note'] ?? null,
                'requested_at' => now(),
                'confirmed_at' => now(),
                // Manual appointments MUST NOT be marked completed or paid automatically.
                'completed_at' => null,
            ]);

            foreach ($calc['services_data'] as $sData) {
                AppointmentService::create([
                    'appointment_id' => $appt->id,
                    'service_id' => $sData['service_id'],
                    'price_snapshot' => $sData['price_snapshot'],
                    'duration_minutes_snapshot' => $sData['duration_minutes_snapshot'],
                ]);
            }

            return $appt;
        });

        $appointment->load(['customer', 'staff', 'services', 'alternativeSlots']);
        $notificationSent = false;

        if (!$isGuest && $customer !== null) {
            $businessName = trim((string) ($profile->business_name ?: $user->name ?: 'İşletme'));
            $staffName = $appointment->staffDisplayName();
            $dateStr = $appointment->appointment_date?->format('Y-m-d') ?? $validated['date'];
            $timeHm = substr((string) $appointment->start_time, 0, 5);

            $msg = $staffName
                ? "{$businessName}, {$dateStr} saat {$timeHm} için {$staffName} adına randevunuzu oluşturdu."
                : "{$businessName}, {$dateStr} saat {$timeHm} için randevunuzu oluşturdu.";

            app(NotificationService::class)->notifyUser(
                $customer->id,
                UserNotification::TYPE_APPOINTMENT_CREATED_BY_PROVIDER,
                'Randevunuz Oluşturuldu',
                $msg,
                UserNotification::RESOURCE_SCHEDULED_APPOINTMENT,
                $appointment->id,
                '/customer',
                [
                    'appointment_id' => $appointment->id,
                    'appointment_date' => $dateStr,
                    'start_time' => $timeHm,
                    'staff_id' => $appointment->staff_id,
                    'staff_name' => $staffName,
                ],
                "APPOINTMENT_CREATED_BY_PROVIDER:{$appointment->id}:{$customer->id}"
            );
            $notificationSent = true;
        }

        return response()->json([
            'success' => true,
            'message' => 'Randevu takvime başarıyla eklendi.',
            'notification_sent' => $notificationSent,
            'data' => new ProviderAppointmentResource($appointment),
        ], 201);
    }

    /**
     * Update an active appointment's date, time, staff, or note with staff conflict checks.
     */
    public function updateManual(Request $request, $appointment): JsonResponse
    {
        $user = $request->user();
        $profile = $user->providerProfile;
        if (!$profile) {
            return response()->json(['success' => false, 'message' => 'Hizmet veren profili bulunamadı.'], 404);
        }

        $appt = Appointment::with(['services'])
            ->where('id', $appointment)
            ->where('provider_user_id', $user->id)
            ->first();

        if (!$appt) {
            return response()->json(['success' => false, 'message' => 'Randevu bulunamadı veya yetkiniz yok.'], 404);
        }

        if (in_array($appt->status, [
            Appointment::STATUS_COMPLETED,
            Appointment::STATUS_CANCELLED,
            Appointment::STATUS_REJECTED,
            Appointment::STATUS_DISPUTED,
        ], true)) {
            return response()->json(['success' => false, 'message' => 'Sonlandırılmış randevu düzenlenemez.'], 422);
        }

        $validated = $request->validate([
            'date' => ['sometimes', 'required', 'date_format:Y-m-d'],
            'time' => ['sometimes', 'required', 'date_format:H:i'],
            'staff_id' => ['sometimes', 'nullable', 'integer', 'min:1'],
            'note' => ['sometimes', 'nullable', 'string', 'max:1000'],
        ]);

        $newDate = $validated['date'] ?? $appt->appointment_date->format('Y-m-d');
        $newTime = $validated['time'] ?? substr((string) $appt->start_time, 0, 5);
        $hasStaffKey = array_key_exists('staff_id', $validated);
        $requestedStaffId = $hasStaffKey
            ? ($validated['staff_id'] !== null ? (int) $validated['staff_id'] : null)
            : ($appt->staff_id !== null ? (int) $appt->staff_id : null);

        $serviceIds = $appt->services->pluck('id')->all();
        $package = $this->appointmentPackage($appt);

        $prevDate = $appt->appointment_date->format('Y-m-d');
        $prevTime = substr((string) $appt->start_time, 0, 5);
        $prevStaffId = $appt->staff_id !== null ? (int) $appt->staff_id : null;

        $updated = DB::transaction(function () use ($appt, $profile, $serviceIds, $package, $newDate, $newTime, $requestedStaffId, $validated) {
            DB::table('appointments')
                ->where('provider_user_id', $profile->user_id)
                ->where('appointment_date', $newDate)
                ->whereIn('status', ProviderAvailabilityService::BLOCKING_STATUSES)
                ->lockForUpdate()
                ->get();

            $assignedStaff = $this->availabilityService->resolveStaffForBooking(
                $profile,
                $serviceIds,
                $newDate,
                $newTime,
                $requestedStaffId,
                $appt->id,
                $package,
                customerVisibleOnly: false,
                allowUnverifiedManual: true
            );

            $duration = max(15, (int) ($appt->total_duration_minutes ?: 30));
            if (!$package && !empty($serviceIds)) {
                $calc = $this->availabilityService->calculateDurationAndPrice($profile, $serviceIds, $assignedStaff);
                $duration = $calc['total_duration_minutes'];
            }

            [$sH, $sM] = explode(':', substr($newTime, 0, 5));
            $sMin = (int) $sH * 60 + (int) $sM;
            $eMin = $sMin + $duration;

            $appt->update([
                'appointment_date' => $newDate,
                'start_time' => sprintf('%02d:%02d:00', intdiv($sMin, 60), $sMin % 60),
                'end_time' => sprintf('%02d:%02d:00', intdiv($eMin, 60), $eMin % 60),
                'total_duration_minutes' => $duration,
                'staff_id' => $assignedStaff?->id,
                'staff_name_snapshot' => $assignedStaff?->full_name,
                'customer_note' => array_key_exists('note', $validated) ? $validated['note'] : $appt->customer_note,
            ]);

            return $appt->fresh(['customer', 'staff', 'services', 'alternativeSlots']);
        });

        $changedSchedule = $prevDate !== $newDate || $prevTime !== $newTime || $prevStaffId !== ($updated->staff_id ? (int) $updated->staff_id : null);
        if ($updated->customer_user_id !== null && $changedSchedule) {
            $businessName = trim((string) ($profile->business_name ?: $user->name ?: 'İşletme'));
            $staffName = $updated->staffDisplayName();
            $msg = $staffName
                ? "{$businessName}, randevunuzu {$newDate} saat {$newTime} ({$staffName}) olarak güncelledi."
                : "{$businessName}, randevunuzu {$newDate} saat {$newTime} olarak güncelledi.";

            app(NotificationService::class)->notifyUser(
                $updated->customer_user_id,
                UserNotification::TYPE_APPOINTMENT_STAFF_CHANGED,
                'Randevunuz Güncellendi',
                $msg,
                UserNotification::RESOURCE_SCHEDULED_APPOINTMENT,
                $updated->id,
                '/customer',
                [
                    'appointment_id' => $updated->id,
                    'appointment_date' => $newDate,
                    'start_time' => $newTime,
                    'staff_id' => $updated->staff_id,
                    'staff_name' => $staffName,
                ],
                "APPOINTMENT_UPDATED_BY_PROVIDER:{$updated->id}:" . now()->timestamp
            );
        }

        return response()->json([
            'success' => true,
            'message' => 'Randevu güncellendi.',
            'data' => new ProviderAppointmentResource($updated),
        ]);
    }

    /**
     * Reassign staff member on an existing appointment and notify customer (if Tarak member).
     */
    public function changeStaff(Request $request, $appointment): JsonResponse
    {
        $user = $request->user();
        $profile = $user->providerProfile;
        if (!$profile) {
            return response()->json(['success' => false, 'message' => 'Hizmet veren profili bulunamadı.'], 404);
        }

        $appt = Appointment::with(['services'])
            ->where('id', $appointment)
            ->where('provider_user_id', $user->id)
            ->first();

        if (!$appt) {
            return response()->json(['success' => false, 'message' => 'Randevu bulunamadı veya yetkiniz yok.'], 404);
        }

        if (in_array($appt->status, [
            Appointment::STATUS_COMPLETED,
            Appointment::STATUS_CANCELLED,
            Appointment::STATUS_REJECTED,
            Appointment::STATUS_DISPUTED,
        ], true)) {
            return response()->json(['success' => false, 'message' => 'Sonlandırılmış randevunun çalışanı değiştirilemez.'], 422);
        }

        $validated = $request->validate([
            'staff_id' => ['required', 'integer', 'exists:provider_staff,id'],
        ]);

        $newStaffId = (int) $validated['staff_id'];
        $previousStaffId = $appt->staff_id ? (int) $appt->staff_id : null;

        $staff = $profile->staff()->whereKey($newStaffId)->first();
        if (!$staff) {
            return response()->json(['success' => false, 'message' => 'Seçilen çalışan işletmenize ait değil.'], 404);
        }

        $serviceIds = $appt->services->pluck('id')->all();
        $package = $this->appointmentPackage($appt);

        $updated = DB::transaction(function () use ($appt, $profile, $staff, $serviceIds, $package) {
            $dateStr = $appt->appointment_date->format('Y-m-d');
            DB::table('appointments')
                ->where('provider_user_id', $profile->user_id)
                ->where('appointment_date', $dateStr)
                ->whereIn('status', ProviderAvailabilityService::BLOCKING_STATUSES)
                ->lockForUpdate()
                ->get();

            $this->availabilityService->assertStaffCanTakeExactWindow(
                $profile,
                $staff,
                $serviceIds,
                $dateStr,
                substr((string) $appt->start_time, 0, 5),
                (int) ($appt->total_duration_minutes ?: 30),
                $appt->id,
                $package
            );

            $appt->update([
                'staff_id' => $staff->id,
                'staff_name_snapshot' => $staff->full_name,
            ]);

            return $appt->fresh(['customer', 'staff', 'services', 'alternativeSlots']);
        });

        if ($updated->customer_user_id !== null && $previousStaffId !== $staff->id) {
            $businessName = trim((string) ($profile->business_name ?: $user->name ?: 'İşletme'));
            $dateStr = $updated->appointment_date?->format('Y-m-d') ?? '';
            $timeHm = substr((string) $updated->start_time, 0, 5);

            app(NotificationService::class)->notifyUser(
                $updated->customer_user_id,
                UserNotification::TYPE_APPOINTMENT_STAFF_CHANGED,
                'Randevu Uzmanı Güncellendi',
                "{$businessName} işletmesindeki {$dateStr} saat {$timeHm} randevunuz için ilgilenecek uzman {$staff->full_name} olarak güncellendi.",
                UserNotification::RESOURCE_SCHEDULED_APPOINTMENT,
                $updated->id,
                '/customer',
                [
                    'appointment_id' => $updated->id,
                    'appointment_date' => $dateStr,
                    'start_time' => $timeHm,
                    'staff_id' => $staff->id,
                    'staff_name' => $staff->full_name,
                ],
                "APPOINTMENT_STAFF_CHANGED:{$updated->id}:{$staff->id}:" . now()->timestamp
            );
        }

        return response()->json([
            'success' => true,
            'message' => 'Randevu çalışanı güncellendi.',
            'data' => new ProviderAppointmentResource($updated),
        ]);
    }

    /**
     * Cancel appointment by provider cleanly (suppresses reminders & frees staff calendar).
     */
    public function cancel(Request $request, $appointment): JsonResponse
    {
        $user = $request->user();
        $appt = Appointment::where('id', $appointment)
            ->where('provider_user_id', $user->id)
            ->first();

        if (!$appt) {
            return response()->json(['success' => false, 'message' => 'Randevu bulunamadı veya yetkiniz yok.'], 404);
        }

        if (in_array($appt->status, [
            Appointment::STATUS_CANCELLED,
            Appointment::STATUS_REJECTED,
            Appointment::STATUS_COMPLETED,
        ], true)) {
            return response()->json(['success' => false, 'message' => 'Bu randevu zaten sonlandırılmış.'], 422);
        }

        $appt->update([
            'status' => Appointment::STATUS_CANCELLED,
            'cancelled_at' => now(),
            'rejection_reason' => trim((string) $request->input('reason', '')) ?: $appt->rejection_reason,
        ]);

        $paymentMethod = strtoupper($appt->payment_method ?? 'CASH');
        if ($paymentMethod === 'CASH') {
            app(\App\Services\FinancialService::class)->releaseCashCommission(
                LocationShareGrant::RESOURCE_SCHEDULED_APPOINTMENT,
                $appt->id,
                'APPOINTMENT_CANCELLED_BY_PROVIDER'
            );
        } else {
            app(\App\Services\FinancialService::class)->cancelOnlinePayment(
                LocationShareGrant::RESOURCE_SCHEDULED_APPOINTMENT,
                $appt->id
            );
        }

        app(ServiceLifecycleService::class)->cancelVerificationForResource(LocationShareGrant::RESOURCE_SCHEDULED_APPOINTMENT, $appt->id);
        app(\App\Services\LocationGrantService::class)->expireGrantsForResource(LocationShareGrant::RESOURCE_SCHEDULED_APPOINTMENT, $appt->id, 'APPOINTMENT_CANCELLED_BY_PROVIDER');
        $appt->alternativeSlots()->where('status', 'PENDING')->update(['status' => 'EXPIRED']);

        if ($appt->customer_user_id !== null) {
            $businessName = trim((string) ($user->providerProfile?->business_name ?: $user->name ?: 'İşletme'));
            app(NotificationService::class)->notifyUser(
                $appt->customer_user_id,
                UserNotification::TYPE_APPOINTMENT_REJECTED,
                'Randevunuz İptal Edildi',
                "{$businessName} işletmesindeki randevunuz işletme tarafından iptal edildi.",
                UserNotification::RESOURCE_SCHEDULED_APPOINTMENT,
                $appt->id,
                '/customer',
                ['appointment_id' => $appt->id],
                "APPOINTMENT_CANCELLED_BY_PROVIDER:{$appt->id}:{$appt->customer_user_id}"
            );
        }

        return response()->json([
            'success' => true,
            'message' => 'Randevu iptal edildi.',
            'data' => new ProviderAppointmentResource($appt->fresh(['customer', 'staff', 'services', 'alternativeSlots'])),
        ]);
    }

    /**
     * Provider confirms an appointment.
     * Re-checks availability with locking to prevent double-booking.
     */
    public function confirm(Request $request, $appointment): JsonResponse
    {
        $user = $request->user();

        $appt = Appointment::with(['services', 'staff'])
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

        if (!in_array($appt->status, ['PENDING', 'ALTERNATIVE_PROPOSED'], true)) {
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
                ->whereIn('status', ['PENDING', 'ALTERNATIVE_PROPOSED', 'CONFIRMED', 'IN_PROGRESS'])
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
                $this->appointmentPackage($appt),
                $appt->staff_id,
                customerVisibleOnly: false
            );

            if (!$isAvailable) {
                abort(409, 'Bu saat artık müsait değil. Alternatif saat önerin.');
            }

            if ($appt->customer_user_id !== null) {
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

                app(ServiceLifecycleService::class)->ensureStartVerificationForResource(
                    LocationShareGrant::RESOURCE_SCHEDULED_APPOINTMENT,
                    $appt->id,
                    $appt->customer_user_id,
                    $appt->provider_user_id
                );
            }

            $appt->update([
                'status' => 'CONFIRMED',
                'confirmed_at' => now(),
            ]);

            $appt->alternativeSlots()->where('status', 'PENDING')->update(['status' => 'EXPIRED']);

            return $appt;
        });

        if ($updated->customer_user_id !== null) {
            $staffName = $updated->staffDisplayName();
            $msg = $staffName
                ? "Randevu talebiniz onaylandı. İlgilenecek uzman: {$staffName}."
                : 'Randevu talebiniz hizmet veren tarafından onaylandı.';

            app(NotificationService::class)->notifyUser(
                $updated->customer_user_id,
                UserNotification::TYPE_APPOINTMENT_CONFIRMED,
                'Randevunuz Onaylandı',
                $msg,
                UserNotification::RESOURCE_SCHEDULED_APPOINTMENT,
                $updated->id,
                '/customer',
                [
                    'appointment_id' => $updated->id,
                    'appointment_date' => $updated->appointment_date?->format('Y-m-d') ?: (string) $updated->appointment_date,
                    'start_time' => (string) $updated->start_time,
                    'staff_id' => $updated->staff_id,
                    'staff_name' => $staffName,
                ],
                "APPOINTMENT_CONFIRMED:{$updated->id}:{$updated->customer_user_id}"
            );
        }

        return response()->json([
            'success' => true,
            'message' => 'Randevu başarıyla onaylandı.',
            'data' => new ProviderAppointmentResource($updated->fresh(['customer', 'staff', 'services', 'alternativeSlots'])),
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

        if ($appt->customer_user_id !== null) {
            app(NotificationService::class)->notifyUser(
                $appt->customer_user_id,
                UserNotification::TYPE_APPOINTMENT_REJECTED,
                'Randevu Talebi Reddedildi',
                'Randevu talebiniz hizmet veren tarafından reddedildi.' . (!empty($validated['reason']) ? ' Gerekçe: ' . $validated['reason'] : ''),
                UserNotification::RESOURCE_SCHEDULED_APPOINTMENT,
                $appt->id,
                '/customer',
                [
                    'appointment_id' => $appt->id,
                    'reason' => $validated['reason'],
                ],
                "APPOINTMENT_REJECTED:{$appt->id}:{$appt->customer_user_id}"
            );
        }

        return response()->json([
            'success' => true,
            'message' => 'Randevu talebi reddedildi.',
            'data' => new ProviderAppointmentResource($appt->fresh(['customer', 'staff', 'services', 'alternativeSlots'])),
        ]);
    }

    /**
     * Provider proposes 1 to 5 alternative slots.
     */
    public function proposeAlternatives(Request $request, $appointment): JsonResponse
    {
        $user = $request->user();
        $profile = $user->providerProfile;

        $appt = Appointment::with(['services', 'staff'])
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

        $uniqueKeys = [];
        foreach ($slots as $slot) {
            $key = $slot['date'] . '_' . substr($slot['time'], 0, 5);
            if (in_array($key, $uniqueKeys, true)) {
                return response()->json([
                    'success' => false,
                    'message' => 'Aynı alternatif saat birden fazla kez eklenemez.',
                ], 422);
            }
            $uniqueKeys[] = $key;
        }

        foreach ($slots as $slot) {
            $isAvailable = $this->availabilityService->isSlotAvailable(
                $profile,
                $serviceIds,
                $slot['date'],
                $slot['time'],
                $appt->id,
                $this->appointmentPackage($appt),
                $appt->staff_id,
                customerVisibleOnly: false
            );

            if (!$isAvailable) {
                return response()->json([
                    'success' => false,
                    'message' => "{$slot['date']} {$slot['time']} saati artık müsait değil.",
                ], 422);
            }
        }

        DB::transaction(function () use ($appt, $slots, $durationMinutes) {
            $appt->alternativeSlots()->where('status', 'PENDING')->update(['status' => 'EXPIRED']);

            foreach ($slots as $slot) {
                [$sH, $sM] = explode(':', substr($slot['time'], 0, 5));
                $sMin = (int) $sH * 60 + (int) $sM;
                $eMin = $sMin + $durationMinutes;

                AppointmentAlternativeSlot::create([
                    'appointment_id' => $appt->id,
                    'date' => $slot['date'],
                    'start_time' => sprintf('%02d:%02d:00', floor($sMin / 60), $sMin % 60),
                    'end_time' => sprintf('%02d:%02d:00', floor($eMin / 60), $eMin % 60),
                    'status' => 'PENDING',
                ]);
            }

            $appt->update(['status' => 'ALTERNATIVE_PROPOSED']);
        });

        if ($appt->customer_user_id !== null) {
            app(NotificationService::class)->notifyUser(
                $appt->customer_user_id,
                UserNotification::TYPE_APPOINTMENT_ALTERNATIVE_PROPOSED,
                'Alternatif Randevu Saatleri Önerildi',
                'Hizmet veren randevunuz için alternatif saatler önerdi.',
                UserNotification::RESOURCE_SCHEDULED_APPOINTMENT,
                $appt->id,
                '/customer',
                [
                    'appointment_id' => $appt->id,
                    'slot_count' => count($slots),
                ],
                "APPOINTMENT_ALTERNATIVE_PROPOSED:{$appt->id}:{$appt->customer_user_id}"
            );
        }

        return response()->json([
            'success' => true,
            'message' => 'Alternatif saat teklifleri müşteriye iletildi.',
            'data' => new ProviderAppointmentResource($appt->fresh(['customer', 'staff', 'services', 'alternativeSlots'])),
        ]);
    }

    private function isAuthorizedCustomerOfProvider(int $customerId, int $providerUserId): bool
    {
        return Appointment::where('customer_user_id', $customerId)
            ->where('provider_user_id', $providerUserId)
            ->exists()
            || ServiceRequest::where('customer_user_id', $customerId)
                ->where(function ($q) use ($providerUserId) {
                    $q->where('assigned_provider_user_id', $providerUserId)
                        ->orWhere('target_provider_user_id', $providerUserId);
                })
                ->exists()
            || Conversation::where('customer_user_id', $customerId)
                ->where('provider_user_id', $providerUserId)
                ->exists()
            || CustomerFavorite::where('customer_user_id', $customerId)
                ->where('provider_user_id', $providerUserId)
                ->exists();
    }

    private function appointmentPackage(Appointment $appt): ?ProviderPackage
    {
        return $appt->provider_package_id
            ? ProviderPackage::find($appt->provider_package_id)
            : null;
    }
}
