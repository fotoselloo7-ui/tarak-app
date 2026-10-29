<?php

namespace App\Http\Controllers;

use App\Http\Resources\AppointmentResource;
use App\Models\Appointment;
use App\Models\AppointmentAlternativeSlot;
use App\Models\AppointmentService;
use App\Models\CustomerAddress;
use App\Models\LocationShareGrant;
use App\Models\ProviderProfile;
use App\Models\User;
use App\Services\ListingAdService;
use App\Services\ProviderAvailabilityService;
use App\Services\ServiceLifecycleService;
use App\Support\Geo;
use App\Support\MediaUrl;
use App\Support\ProviderListFilters;
use Carbon\Carbon;
use Illuminate\Database\Eloquent\Collection as EloquentCollection;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class CustomerAppointmentController extends Controller
{
    public function __construct(
        protected ProviderAvailabilityService $availabilityService,
        protected ListingAdService $listingAds
    ) {}

    /**
     * Provider discovery for scheduled appointments.
     * Returns approved, identity-verified providers.
     */
    public function providers(Request $request): JsonResponse
    {
        $query = ProviderProfile::with(['user', 'services', 'documents'])
            ->discoverable();

        if ($request->filled('provider_type')) {
            $query->where('provider_type', $request->query('provider_type'));
        }

        if ($request->filled('category')) {
            $cat = $request->query('category');
            if ($cat === 'cat-1') {
                $query->where('provider_type', 'barber');
            } elseif ($cat === 'cat-2') {
                $query->where('provider_type', 'coiffeur');
            }
        }

        if ($request->filled('service_id')) {
            $sId = $request->query('service_id');
            $query->whereHas('providerServices', function ($q) use ($sId) {
                $q->where('service_id', $sId)->where('is_active', true);
            });
        }

        // Multi-service discovery: provider must actively offer EVERY requested service
        foreach ($this->parseServiceIds($request->query('service_ids')) as $sId) {
            $query->whereHas('providerServices', function ($q) use ($sId) {
                $q->where('service_id', $sId)->where('is_active', true);
            });
        }

        // Search / stars / distance / sort, plus the sponsored "Liste Reklamı" slots (see ListingAdService).
        $serviceIds = array_merge(
            $request->filled('service_id') ? [(int) $request->query('service_id')] : [],
            $this->parseServiceIds($request->query('service_ids'))
        );
        $type = $request->filled('provider_type') ? $request->query('provider_type') : match ($request->query('category')) {
            'cat-1' => 'barber',
            'cat-2' => 'coiffeur',
            default => null,
        };
        $filters = ProviderListFilters::fromRequest($request, $type, $serviceIds);
        $origin = $filters['origin'];

        $sponsored = $this->listingAds->sponsored($filters);
        $sponsored = new EloquentCollection($sponsored->all());
        $sponsored->load(['services', 'documents']);
        if ($request->boolean('sponsored_only')) {
            // Just the cards of the rotating slots: the clients ask again every `rotation_seconds`.
            $reviewTotals = \App\Models\ProviderReview::query()
                ->whereIn('provider_user_id', $sponsored->pluck('user_id'))
                ->selectRaw('provider_user_id, COUNT(*) as review_count, AVG(rating) as average_rating')
                ->groupBy('provider_user_id')->get()->keyBy('provider_user_id');

            $discounts = app(\App\Services\ProviderDiscountService::class)->percentsFor($sponsored->pluck('user_id'));

            return response()->json([
                'success' => true,
                'sponsored' => $sponsored->map(fn ($p) => $this->presentListedProvider($p, $reviewTotals->get($p->user_id), $origin, $discounts) + ['is_sponsored' => true, 'sponsored_label' => ListingAdService::LABEL])->values(),
                'meta' => ['has_origin' => $origin !== null] + $this->listingAds->meta(),
            ]);
        }

        $allApproved = $query->get();

        // Directory completeness and verification are separate: every approved
        // identity-reviewed provider is visible; is_verified below controls the blue tick.
        $directoryProviders = $allApproved;

        $reviewTotals = \App\Models\ProviderReview::query()
            ->whereIn('provider_user_id', $directoryProviders->pluck('user_id')->merge($sponsored->pluck('user_id')))
            ->selectRaw('provider_user_id, COUNT(*) as review_count, AVG(rating) as average_rating')
            ->groupBy('provider_user_id')->get()->keyBy('provider_user_id');

        // The list is not thinned: the clients hide the providers currently in the rotating slots.
        $organic = $directoryProviders;

        if ($filters['term'] !== null) {
            $needle = mb_strtolower($filters['term']);
            $organic = $organic->filter(fn ($p) => str_contains(mb_strtolower(implode(' ', array_filter([$p->business_name, $p->user?->name, $p->city, $p->district]))), $needle));
        }
        if ($filters['min_rating'] > 0) {
            $organic = $organic->filter(fn ($p) => (float) ($reviewTotals->get($p->user_id)?->average_rating ?? 0) >= $filters['min_rating']);
        }
        if ($origin) {
            $km = fn ($p) => Geo::distanceKm($origin[0], $origin[1], $p->latitude, $p->longitude);
            if ($filters['max_distance_km']) {
                $organic = $organic->filter(fn ($p) => ($d = $km($p)) !== null && $d <= $filters['max_distance_km']);
            }
        }

        $sort = $filters['sort'];
        if ($sort === 'distance' && !$origin) {
            $sort = 'rating';
        }
        $rating = fn ($p) => (float) ($reviewTotals->get($p->user_id)?->average_rating ?? 0);
        $organic = match ($sort) {
            'distance' => $organic->sortBy(fn ($p) => Geo::distanceKm($origin[0], $origin[1], $p->latitude, $p->longitude) ?? PHP_FLOAT_MAX),
            'rating' => $organic->sortByDesc(fn ($p) => [$rating($p), (int) ($reviewTotals->get($p->user_id)?->review_count ?? 0)]),
            'reviews' => $organic->sortByDesc(fn ($p) => (int) ($reviewTotals->get($p->user_id)?->review_count ?? 0)),
            'newest' => $organic->sortByDesc(fn ($p) => $p->approved_at ?? $p->created_at),
            default => $organic, // relevance: the order the endpoint always returned
        };

        // Running campaign discounts of everyone in the list: one query.
        $discounts = app(\App\Services\ProviderDiscountService::class)->percentsFor($organic->pluck('user_id')->merge($sponsored->pluck('user_id')));

        $present = fn ($p, bool $isSponsored = false) => $this->presentListedProvider($p, $reviewTotals->get($p->user_id), $origin, $discounts) + ($isSponsored
            ? ['is_sponsored' => true, 'sponsored_label' => ListingAdService::LABEL]
            : []);

        return response()->json([
            'success' => true,
            'data' => $organic->values()->map(fn ($p) => $present($p)),
            'sponsored' => $sponsored->map(fn ($p) => $present($p, true))->values(),
            'meta' => [
                'total' => $organic->count(),
                'has_origin' => $origin !== null,
            ] + $this->listingAds->meta(),
        ]);
    }

    /** One row of the customer's provider list (shared by organic and sponsored entries). */
    private function presentListedProvider(ProviderProfile $p, $reviews, ?array $origin, array $discounts = []): array
    {
        $u = $p->user;
        $discountPercent = (int) ($discounts[(int) $p->user_id] ?? 0);

        return [
            'id' => (string) $p->id,
            'user_id' => (string) $p->user_id,
            'provider_type' => $p->provider_type,
            'business_name' => $p->business_name ?: $u?->name,
            'name' => $u?->name,
            'avatar_url' => MediaUrl::resolve($u?->avatar_url),
            'city' => $p->city,
            'district' => $p->district,
            'rating' => $reviews ? round((float) $reviews->average_rating, 2) : null,
            'review_count' => $reviews ? (int) $reviews->review_count : 0,
            'experience_years' => $p->experience_years,
            'is_demo' => false,
            'is_approved' => (bool) $p->is_approved,
            'identity_status' => $p->identity_status,
            'is_verified' => $p->isVerified(),
            // Presentation fields the web dashboard used to fetch with one extra request per provider.
            'cover_url' => MediaUrl::resolve($p->cover_url),
            'gallery' => array_values(array_filter(array_map(fn ($url) => MediaUrl::resolve($url), $p->gallery ?? []))),
            'bio' => $p->bio,
            'title' => $p->title,
            'is_online' => (bool) $p->is_online,
            // A running campaign discount (percent), 0 when none; the service prices below already include it.
            'discount_percent' => $discountPercent,
            // Distance from the customer's position (null when either side has no coordinates).
            'distance_km' => $origin ? Geo::distanceKm($origin[0], $origin[1], $p->latitude, $p->longitude) : null,
            // Active offerings only, with the provider_service row id, so clients need no per-provider offerings call.
            'services' => $p->services->filter(fn ($s) => (bool) $s->pivot->is_active)->values()->map(function ($s) use ($discountPercent) {
                $base = $s->pivot->custom_price !== null ? (float) $s->pivot->custom_price : (float) $s->base_price;

                return [
                    'provider_service_id' => (int) $s->pivot->id,
                    'id' => (string) $s->id,
                    'name' => $s->name,
                    'category_id' => (string) $s->category_id,
                    'custom_price' => \App\Services\ProviderDiscountService::discounted($base, $discountPercent),
                    'original_price' => $discountPercent > 0 ? round($base, 2) : null,
                    'discount_percent' => $discountPercent,
                    'custom_duration_minutes' => $s->pivot->custom_duration_minutes !== null ? (int) $s->pivot->custom_duration_minutes : (int) $s->duration_minutes,
                ];
            }),
        ];
    }

    /**
     * Get available slots for a specific provider, date, and selected services.
     */
    public function availability(Request $request, $provider): JsonResponse
    {
        $profile = $this->availabilityService->resolveProviderProfile($provider);
        if (!$profile) {
            return response()->json([
                'success' => false,
                'message' => 'Hizmet veren bulunamadı.',
            ], 404);
        }

        $date = $request->query('date', Carbon::tomorrow()->format('Y-m-d'));

        $package = null;
        if ($request->filled('provider_package_id')) {
            $package = $profile->packages()->with('services')->whereKey($request->query('provider_package_id'))->first();
            if (!$package || !$package->is_active) {
                return response()->json([
                    'success' => false,
                    'message' => 'Seçilen paket bu uzmana ait değil veya aktif değil.',
                ], 422);
            }
        }

        $serviceIds = $package
            ? $package->services->pluck('id')->all()
            : $this->parseServiceIds($request->query('service_ids') ?: $request->query('service_id'));

        $slots = $this->availabilityService->getAvailableSlots($profile, $serviceIds, $date, null, $package);
        if ($package) {
            $discount = app(\App\Services\ProviderDiscountService::class)->apply((int) $profile->user_id, (float) $package->price);
            $calc = [
                'total_duration_minutes' => (int) $package->duration_minutes,
                'total_price' => $discount['price'],
                'original_total_price' => $discount['original_price'],
                'discount_percent' => $discount['discount_percent'],
            ];
        } else {
            $calc = $this->availabilityService->calculateDurationAndPrice($profile, $serviceIds);
        }

        return response()->json([
            'success' => true,
            'data' => [
                'provider_id' => (string) $profile->user_id,
                'date' => $date,
                'provider_package_id' => $package?->id,
                'total_duration_minutes' => $calc['total_duration_minutes'],
                'total_price' => $calc['total_price'],
                // A running campaign discount is already in total_price; these let the client show the saving.
                'original_total_price' => $calc['original_total_price'] ?? null,
                'discount_percent' => $calc['discount_percent'] ?? 0,
                'available_slots' => $slots,
            ],
        ]);
    }

    /**
     * Accepts service_ids as an array (service_ids[]=1&service_ids[]=2) or a comma-separated string (service_ids=1,2).
     *
     * @return array<int, string>
     */
    private function parseServiceIds(mixed $raw): array
    {
        $flattened = [];
        foreach ((array) ($raw ?: []) as $item) {
            if (is_string($item) && str_contains($item, ',')) {
                $flattened = array_merge($flattened, explode(',', $item));
            } else {
                $flattened[] = $item;
            }
        }

        return array_values(array_filter(array_unique(array_map(fn ($v) => trim((string) $v), $flattened))));
    }

    /**
     * List authenticated customer's appointments.
     */
    public function index(Request $request): JsonResponse
    {
        $user = $request->user();

        $appointments = Appointment::with(['provider.providerProfile', 'services', 'alternativeSlots', 'address', 'disputeCase', 'servicePayment.refunds'])
            ->where('customer_user_id', $user->id)
            ->orderByDesc('requested_at')
            ->get();

        return response()->json([
            'success' => true,
            'data' => AppointmentResource::collection($appointments),
        ]);
    }

    /**
     * Create a new scheduled appointment request.
     */
    public function store(Request $request): JsonResponse
    {
        $customer = $request->user();

        $validated = $request->validate([
            'provider_id' => 'required',
            'provider_package_id' => 'nullable|integer',
            'service_ids' => 'required_without:provider_package_id|array|min:1',
            'service_ids.*' => 'required|integer',
            'date' => 'required|date_format:Y-m-d',
            'time' => 'required|date_format:H:i',
            'customer_address_id' => 'nullable|integer',
            'customer_note' => 'nullable|string|max:1000',
            'payment_method' => 'nullable|string|in:CASH,ONLINE,cash,online',
            // Optional fallback location if customer has no saved address
            'approx_province' => 'nullable|string|max:100',
            'approx_district' => 'nullable|string|max:100',
            'approx_neighborhood' => 'nullable|string|max:100',
        ]);

        $profile = $this->availabilityService->resolveProviderProfile($validated['provider_id']);
        if (!$profile || !$profile->is_approved || $profile->identity_status !== 'APPROVED' || !$profile->isVerified()) {
            return response()->json([
                'success' => false,
                'message' => 'Yalnızca mesleki belgesi onaylı uzmanlardan randevu alınabilir.',
            ], 422);
        }

        $offering = null;
        if (!empty($validated['provider_package_id'])) {
            $offering = app(\App\Services\ProviderOfferingService::class)->resolveOffering(null, (int) $validated['provider_package_id']);
            if ((int) $offering['profile']->id !== (int) $profile->id) {
                return response()->json([
                    'success' => false,
                    'message' => 'Seçilen paket bu uzmana ait değil.',
                ], 422);
            }
            $validated['service_ids'] = $offering['service_ids'];
        } elseif (!$this->availabilityService->providerOffersAllServices($profile, $validated['service_ids'])) {
            // Verify provider offers all requested services
            return response()->json([
                'success' => false,
                'message' => 'Seçilen uzman istenen hizmetlerin tamamını sunmamaktadır.',
            ], 422);
        }
        $package = $offering ? \App\Models\ProviderPackage::find($offering['provider_package_id']) : null;

        // Verify customer address ownership if provided
        $address = null;
        if (!empty($validated['customer_address_id'])) {
            $customerProfile = $customer->customerProfile;
            $address = CustomerAddress::where('id', $validated['customer_address_id'])
                ->where('customer_profile_id', $customerProfile?->id)
                ->first();

            if (!$address) {
                return response()->json([
                    'success' => false,
                    'message' => 'Seçilen adres size ait değil veya bulunamadı.',
                ], 403);
            }
        }

        // Concurrency Protection & Race Condition Safety via DB Transaction
        $appointment = DB::transaction(function () use ($customer, $profile, $validated, $address, $offering, $package) {
            // Lock active appointments for this provider and date to prevent concurrent double-booking
            DB::table('appointments')
                ->where('provider_user_id', $profile->user_id)
                ->where('appointment_date', $validated['date'])
                ->whereIn('status', ['PENDING', 'ALTERNATIVE_PROPOSED', 'CONFIRMED'])
                ->lockForUpdate()
                ->get();

            // Re-verify availability within locked transaction
            $isAvailable = $this->availabilityService->isSlotAvailable(
                $profile,
                $validated['service_ids'],
                $validated['date'],
                $validated['time'],
                null,
                $package
            );

            if (!$isAvailable) {
                abort(409, 'Bu saat artık müsait değil. Lütfen başka bir saat seçin.');
            }

            // Package: the provider's bundle price/duration is canonical; items are recorded with a zero line price.
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
                : $this->availabilityService->calculateDurationAndPrice($profile, $validated['service_ids']);

            // Calculate start and end times
            [$sH, $sM] = explode(':', substr($validated['time'], 0, 5));
            $sMinutes = (int)$sH * 60 + (int)$sM;
            $eMinutes = $sMinutes + $calc['total_duration_minutes'];

            $startTimeStr = sprintf('%02d:%02d:00', floor($sMinutes / 60), $sMinutes % 60);
            $endTimeStr = sprintf('%02d:%02d:00', floor($eMinutes / 60), $eMinutes % 60);

            // Determine approx location
            $province = $address?->province ?: ($validated['approx_province'] ?? $customer->customerProfile?->city ?: 'İstanbul');
            $district = $address?->district ?: ($validated['approx_district'] ?? $customer->customerProfile?->district ?: 'Kadıköy');
            $neighborhood = $address?->neighborhood ?: ($validated['approx_neighborhood'] ?? null);

            $paymentMethod = strtoupper($validated['payment_method'] ?? 'CASH');

            $appt = Appointment::create([
                'customer_user_id' => $customer->id,
                'provider_user_id' => $profile->user_id,
                'customer_address_id' => $address?->id,
                'status' => 'PENDING',
                'appointment_date' => $validated['date'],
                'start_time' => $startTimeStr,
                'end_time' => $endTimeStr,
                'payment_method' => $paymentMethod,
                'total_price' => $calc['total_price'],
                'total_duration_minutes' => $calc['total_duration_minutes'],
                'provider_package_id' => $offering['provider_package_id'] ?? null,
                'offering_snapshot' => $offering['snapshot'] ?? null,
                'approx_province' => $province,
                'approx_district' => $district,
                'approx_neighborhood' => $neighborhood,
                'private_latitude' => $address?->latitude,
                'private_longitude' => $address?->longitude,
                'customer_note' => $validated['customer_note'] ?? null,
                'requested_at' => now(),
            ]);

            // Save Snapshot of each selected service
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

        $appointment->load(['provider.providerProfile', 'services', 'address', 'alternativeSlots']);

        app(\App\Services\NotificationService::class)->notifyUser(
            $appointment->provider_user_id,
            \App\Models\UserNotification::TYPE_APPOINTMENT_REQUESTED,
            'Yeni Randevu Talebi',
            'Yeni bir randevu talebiniz var.',
            \App\Models\UserNotification::RESOURCE_SCHEDULED_APPOINTMENT,
            $appointment->id,
            '/barber',
            [
                'appointment_id' => $appointment->id,
                'appointment_date' => $appointment->appointment_date?->format('Y-m-d') ?: (string) $appointment->appointment_date,
                'start_time' => (string) $appointment->start_time,
            ],
            "APPOINTMENT_REQUESTED:{$appointment->id}:{$appointment->provider_user_id}"
        );

        return response()->json([
            'success' => true,
            'message' => 'Randevu talebiniz başarıyla oluşturuldu. Uzmanın onayı bekleniyor.',
            'data' => new AppointmentResource($appointment),
        ], 201);
    }

    /**
     * Show appointment details for customer.
     */
    public function show(Request $request, $appointment): JsonResponse
    {
        $user = $request->user();

        $appt = Appointment::with(['provider.providerProfile', 'services', 'address', 'alternativeSlots'])
            ->where('id', $appointment)
            ->where('customer_user_id', $user->id)
            ->first();

        if (!$appt) {
            return response()->json([
                'success' => false,
                'message' => 'Randevu bulunamadı veya yetkiniz yok.',
            ], 404);
        }

        return response()->json([
            'success' => true,
            'data' => new AppointmentResource($appt),
        ]);
    }

    /**
     * Cancel appointment by customer.
     */
    public function cancel(Request $request, $appointment): JsonResponse
    {
        $user = $request->user();

        $appt = Appointment::where('id', $appointment)
            ->where('customer_user_id', $user->id)
            ->first();

        if (!$appt) {
            return response()->json([
                'success' => false,
                'message' => 'Randevu bulunamadı veya yetkiniz yok.',
            ], 404);
        }

        if (in_array($appt->status, ['CANCELLED', 'REJECTED', 'COMPLETED'])) {
            return response()->json([
                'success' => false,
                'message' => 'Bu randevu zaten sonlandırılmış.',
            ], 422);
        }

        $appt->update([
            'status' => 'CANCELLED',
            'cancelled_at' => now(),
        ]);

        // Release commission reservation or cancel online payment
        $paymentMethod = strtoupper($appt->payment_method ?? 'CASH');
        if ($paymentMethod === 'CASH') {
            app(\App\Services\FinancialService::class)->releaseCashCommission(
                LocationShareGrant::RESOURCE_SCHEDULED_APPOINTMENT,
                $appt->id,
                'APPOINTMENT_CANCELLED'
            );
        } else {
            app(\App\Services\FinancialService::class)->cancelOnlinePayment(
                LocationShareGrant::RESOURCE_SCHEDULED_APPOINTMENT,
                $appt->id
            );
        }

        // Cancel any active verification
        app(ServiceLifecycleService::class)->cancelVerificationForResource(LocationShareGrant::RESOURCE_SCHEDULED_APPOINTMENT, $appt->id);
        app(\App\Services\LocationGrantService::class)->expireGrantsForResource(LocationShareGrant::RESOURCE_SCHEDULED_APPOINTMENT, $appt->id, 'APPOINTMENT_CANCELLED');

        // Expire any pending alternative slots
        $appt->alternativeSlots()->where('status', 'PENDING')->update(['status' => 'EXPIRED']);

        return response()->json([
            'success' => true,
            'message' => 'Randevunuz iptal edildi.',
            'data' => new AppointmentResource($appt->fresh(['provider.providerProfile', 'services', 'alternativeSlots'])),
        ]);
    }

    /**
     * Accept an alternative slot proposed by provider.
     */
    public function acceptAlternative(Request $request, $appointment, $slot): JsonResponse
    {
        $user = $request->user();

        $appt = Appointment::with(['services'])
            ->where('id', $appointment)
            ->where('customer_user_id', $user->id)
            ->first();

        if (!$appt) {
            return response()->json([
                'success' => false,
                'message' => 'Randevu bulunamadı veya yetkiniz yok.',
            ], 404);
        }

        $altSlot = AppointmentAlternativeSlot::where('id', $slot)
            ->where('appointment_id', $appt->id)
            ->first();

        if (!$altSlot || $altSlot->status !== 'PENDING') {
            return response()->json([
                'success' => false,
                'message' => 'Geçerli bir alternatif saat bulunamadı.',
            ], 422);
        }

        // Concurrency Protection: Re-check availability in transaction
        $updated = DB::transaction(function () use ($appt, $altSlot) {
            DB::table('appointments')
                ->where('provider_user_id', $appt->provider_user_id)
                ->where('appointment_date', $altSlot->date->format('Y-m-d'))
                ->whereIn('status', ['PENDING', 'ALTERNATIVE_PROPOSED', 'CONFIRMED'])
                ->lockForUpdate()
                ->get();

            $serviceIds = $appt->services->pluck('id')->toArray();
            $providerProfile = ProviderProfile::where('user_id', $appt->provider_user_id)->first();

            $isAvailable = $this->availabilityService->isSlotAvailable(
                $providerProfile,
                $serviceIds,
                $altSlot->date->format('Y-m-d'),
                substr($altSlot->start_time, 0, 5),
                $appt->id,
                // Package bookings are validated against the package itself.
                $appt->provider_package_id
                    ? \App\Models\ProviderPackage::find($appt->provider_package_id)
                    : null
            );

            if (!$isAvailable) {
                abort(409, 'Bu saat artık dolu. Diğer önerilerden birini seçin.');
            }

            // Financial Setup (Atomic Commission Reservation or Pending Online Payment)
            $paymentMethod = strtoupper($appt->payment_method ?? 'CASH');
            $financialService = app(\App\Services\FinancialService::class);

            if ($paymentMethod === 'CASH') {
                $financialService->reserveCashCommission(
                    LocationShareGrant::RESOURCE_SCHEDULED_APPOINTMENT,
                    $appt->id,
                    $appt->provider_user_id,
                    (string) $appt->total_price
                );
            } else {
                $financialService->createPendingOnlinePayment(
                    LocationShareGrant::RESOURCE_SCHEDULED_APPOINTMENT,
                    $appt->id,
                    $appt->customer_user_id,
                    $appt->provider_user_id,
                    (string) $appt->total_price
                );
            }

            // Update appointment date & times
            $appt->update([
                'appointment_date' => $altSlot->date->format('Y-m-d'),
                'start_time' => $altSlot->start_time,
                'end_time' => $altSlot->end_time,
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

            // Mark this slot as ACCEPTED, and others as EXPIRED
            $altSlot->update(['status' => 'ACCEPTED']);
            $appt->alternativeSlots()
                ->where('id', '!=', $altSlot->id)
                ->update(['status' => 'EXPIRED']);

            return $appt;
        });

        app(\App\Services\NotificationService::class)->notifyUser(
            $updated->provider_user_id,
            \App\Models\UserNotification::TYPE_APPOINTMENT_ALTERNATIVE_ACCEPTED,
            'Alternatif Saat Kabul Edildi',
            'Müşteri önerdiğiniz alternatif randevu saatini kabul etti.',
            \App\Models\UserNotification::RESOURCE_SCHEDULED_APPOINTMENT,
            $updated->id,
            '/barber',
            [
                'appointment_id' => $updated->id,
                'appointment_date' => $updated->appointment_date?->format('Y-m-d') ?: (string) $updated->appointment_date,
                'start_time' => (string) $updated->start_time,
            ],
            "APPOINTMENT_ALTERNATIVE_ACCEPTED:{$updated->id}:{$updated->provider_user_id}"
        );

        return response()->json([
            'success' => true,
            'message' => 'Alternatif randevu saati onaylandı!',
            'data' => new AppointmentResource($updated->fresh(['provider.providerProfile', 'services', 'alternativeSlots'])),
        ]);
    }

    /**
     * Reject all alternative slots (Customer says "Bu saatler bana uymuyor").
     */
    public function rejectAlternative(Request $request, $appointment): JsonResponse
    {
        $user = $request->user();

        $appt = Appointment::where('id', $appointment)
            ->where('customer_user_id', $user->id)
            ->first();

        if (!$appt) {
            return response()->json([
                'success' => false,
                'message' => 'Randevu bulunamadı veya yetkiniz yok.',
            ], 404);
        }

        $appt->update([
            'status' => 'CANCELLED',
            'cancelled_at' => now(),
            'rejection_reason' => 'Alternatif saatler müşteriye uymadı.',
        ]);

        $appt->alternativeSlots()->update(['status' => 'EXPIRED']);

        return response()->json([
            'success' => true,
            'message' => 'Alternatif saatler reddedildi ve randevu iptal edildi.',
            'data' => new AppointmentResource($appt->fresh(['provider.providerProfile', 'services', 'alternativeSlots'])),
        ]);
    }
}
