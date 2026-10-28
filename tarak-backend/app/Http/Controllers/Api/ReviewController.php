<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Appointment;
use App\Models\ProviderReview;
use App\Models\ServiceRequest;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ReviewController extends Controller
{
    /**
     * Public: a provider's rating summary + recent reviews.
     */
    public function providerSummary(int $provider): JsonResponse
    {
        $providerUser = User::query()->where('id', $provider)->where('role', User::ROLE_PROVIDER)->first();
        if (! $providerUser) {
            return response()->json(['success' => false, 'message' => 'Hizmet veren bulunamadı.'], 404);
        }

        $query = ProviderReview::query()->where('provider_user_id', $provider)
            ->whereHas('customer', fn ($customer) => $customer->where('is_demo', false));
        if ($providerUser->is_demo) {
            $query->whereRaw('1 = 0'); // Synthetic rows remain for admin purge; public summaries stay real.
        }
        $count = (clone $query)->count();
        $average = $count > 0 ? round((float) (clone $query)->avg('rating'), 2) : 0.0;

        $reviews = (clone $query)->with('customer:id,name,is_demo')
            ->latest()
            ->limit(30)
            ->get()
            ->map(fn (ProviderReview $r) => [
                'id' => $r->id,
                'rating' => $r->rating,
                'comment' => \App\Support\CustomerNote::forDisplay($r->comment),
                'customer_name' => $r->customer?->name ?? 'Müşteri',
                'is_demo' => false,
                'created_at' => $r->created_at?->toIso8601String(),
            ]);

        return response()->json([
            'success' => true,
            'data' => [
                'average' => $average,
                'count' => $count,
                'is_demo' => (bool) $providerUser->is_demo,
                'reviews' => $reviews,
            ],
        ]);
    }

    /**
     * Customer: create a review for a COMPLETED appointment or service request.
     */
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'appointment_id' => ['nullable', 'integer', 'required_without:service_request_id'],
            'service_request_id' => ['nullable', 'integer', 'required_without:appointment_id'],
            'rating' => ['required', 'integer', 'min:1', 'max:5'],
            'comment' => ['nullable', 'string', 'max:1000'],
        ]);

        $userId = $request->user()->id;
        $providerUserId = null;
        $appointmentId = null;
        $serviceRequestId = null;

        if (! empty($validated['appointment_id'])) {
            $appt = Appointment::query()
                ->where('id', $validated['appointment_id'])
                ->where('customer_user_id', $userId)
                ->first();
            if (! $appt) {
                return response()->json(['success' => false, 'message' => 'Randevu bulunamadı.'], 404);
            }
            if ($appt->status !== Appointment::STATUS_COMPLETED) {
                return response()->json(['success' => false, 'message' => 'Yalnızca tamamlanan randevular değerlendirilebilir.'], 422);
            }
            $providerUserId = $appt->provider_user_id;
            $appointmentId = $appt->id;
        } else {
            $req = ServiceRequest::query()
                ->where('id', $validated['service_request_id'])
                ->where('customer_user_id', $userId)
                ->first();
            if (! $req) {
                return response()->json(['success' => false, 'message' => 'Talep bulunamadı.'], 404);
            }
            if ($req->status !== ServiceRequest::STATUS_COMPLETED) {
                return response()->json(['success' => false, 'message' => 'Yalnızca tamamlanan hizmetler değerlendirilebilir.'], 422);
            }
            $providerUserId = $req->assigned_provider_user_id;
            $serviceRequestId = $req->id;
        }

        if (! $providerUserId) {
            return response()->json(['success' => false, 'message' => 'Bu kayıt için hizmet veren bulunamadı.'], 422);
        }
        if ($request->user()->is_demo || User::query()->whereKey($providerUserId)->where('is_demo', true)->exists()) {
            return response()->json(['success' => false, 'message' => 'Demo hesaplar gerçek değerlendirme oluşturamaz.'], 422);
        }

        $exists = ProviderReview::query()
            ->where('customer_user_id', $userId)
            ->when($appointmentId, fn ($q) => $q->where('appointment_id', $appointmentId))
            ->when($serviceRequestId, fn ($q) => $q->where('service_request_id', $serviceRequestId))
            ->exists();
        if ($exists) {
            return response()->json(['success' => false, 'message' => 'Bu hizmet için zaten değerlendirme yaptınız.'], 409);
        }

        $review = ProviderReview::create([
            'provider_user_id' => $providerUserId,
            'customer_user_id' => $userId,
            'appointment_id' => $appointmentId,
            'service_request_id' => $serviceRequestId,
            'rating' => $validated['rating'],
            'comment' => $validated['comment'] ?? null,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Değerlendirmeniz kaydedildi.',
            'data' => ['id' => $review->id],
        ], 201);
    }

    /**
     * Provider: my own rating summary + reviews.
     */
    public function mine(Request $request): JsonResponse
    {
        return $this->providerSummary($request->user()->id);
    }

    /**
     * Customer: the reviews THIS customer has written, with the provider and
     * the resource each one belongs to.
     *
     * Read-only on purpose — the backend has no edit/delete capability for
     * reviews, so the clients must not render such actions.
     * GET /api/customer/reviews
     */
    public function myGivenReviews(Request $request): JsonResponse
    {
        $reviews = ProviderReview::query()
            ->where('customer_user_id', $request->user()->id)
            ->with(['provider:id,name,is_demo', 'provider.providerProfile:id,user_id,business_name,provider_type,is_approved,identity_status', 'provider.providerProfile.documents:id,provider_profile_id,document_type,status'])
            ->latest()
            ->limit(100)
            ->get()
            ->map(function (ProviderReview $r) use ($request) {
                $profile = $r->provider?->providerProfile;

                return [
                    'id' => $r->id,
                    'rating' => $r->rating,
                    'comment' => \App\Support\CustomerNote::forDisplay($r->comment),
                    'is_demo' => (bool) ($request->user()->is_demo || $r->provider?->is_demo),
                    'created_at' => $r->created_at?->toIso8601String(),
                    'provider' => [
                        'user_id' => $r->provider_user_id,
                        'name' => $profile?->business_name ?: ($r->provider?->name ?? 'Hizmet Veren'),
                        'provider_type' => $profile?->provider_type,
                        'is_demo' => (bool) ($r->provider?->is_demo ?? false),
                        'is_verified' => (bool) ($profile?->isVerified() ?? false),
                    ],
                    'resource' => $r->appointment_id
                        ? ['type' => 'SCHEDULED_APPOINTMENT', 'id' => $r->appointment_id]
                        : ($r->service_request_id
                            ? ['type' => 'INSTANT_REQUEST', 'id' => $r->service_request_id]
                            : null),
                ];
            });

        return response()->json([
            'success' => true,
            'data' => [
                'count' => $reviews->count(),
                'reviews' => $reviews,
            ],
        ]);
    }
}
