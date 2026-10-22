<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AdminLog;
use App\Models\ContentReport;
use App\Models\ProviderProfile;
use App\Models\ProviderReview;
use App\Models\User;
use App\Services\AccountDeletionService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Password;

/**
 * Admin member management: find, inspect, edit, suspend, reset the password of,
 * or close any customer/provider account, and moderate reviews. Every change is
 * written to the admin audit log (field names only, never values).
 */
class AdminUserController extends Controller
{
    private const STATUSES = ['active', 'pending', 'suspended'];

    public function __construct(protected AccountDeletionService $deletion)
    {
    }

    /** GET /api/admin/users */
    public function index(Request $request): JsonResponse
    {
        $perPage = min(50, max(5, (int) $request->query('per_page', 20)));
        $term = trim((string) $request->query('q', ''));
        $role = strtoupper((string) $request->query('role', ''));
        $status = (string) $request->query('status', '');
        $demo = $request->query('demo');

        $paginator = User::query()
            ->when(in_array($role, [User::ROLE_CUSTOMER, User::ROLE_PROVIDER, User::ROLE_ADMIN], true), fn ($q) => $q->where('role', $role))
            ->when($status !== '', fn ($q) => $q->where('status', $status))
            ->when($demo === '1' || $demo === 'true', fn ($q) => $q->where('is_demo', true))
            ->when($demo === '0' || $demo === 'false', fn ($q) => $q->where('is_demo', false))
            ->when($term !== '', fn ($q) => $q->where(fn ($w) => $w
                ->where('name', 'like', "%$term%")
                ->orWhere('email', 'like', "%$term%")
                ->orWhere('phone', 'like', "%$term%")
                ->when(ctype_digit($term), fn ($x) => $x->orWhere('id', (int) $term))))
            ->orderByDesc('id')
            ->paginate($perPage);

        $ids = $paginator->getCollection()->pluck('id');
        $profiles = ProviderProfile::whereIn('user_id', $ids)->get()->keyBy('user_id');
        $stats = ProviderReview::query()->whereIn('provider_user_id', $ids)
            ->selectRaw('provider_user_id, COUNT(*) as c, AVG(rating) as a')->groupBy('provider_user_id')->get()->keyBy('provider_user_id');

        $rows = $paginator->getCollection()->map(function (User $user) use ($profiles, $stats) {
            $profile = $profiles->get($user->id);
            $stat = $stats->get($user->id);

            return $this->summary($user) + [
                'provider' => $profile ? [
                    'business_name' => $profile->business_name,
                    'provider_type' => $profile->provider_type,
                    'city' => $profile->city,
                    'district' => $profile->district,
                    'is_approved' => (bool) $profile->is_approved,
                    'identity_status' => $profile->identity_status,
                    'is_online' => (bool) $profile->is_online,
                    'review_count' => (int) ($stat->c ?? 0),
                    'rating' => $stat ? round((float) $stat->a, 2) : null,
                ] : null,
            ];
        });

        return response()->json([
            'success' => true,
            'data' => $rows,
            'pagination' => [
                'current_page' => $paginator->currentPage(),
                'last_page' => $paginator->lastPage(),
                'per_page' => $paginator->perPage(),
                'total' => $paginator->total(),
            ],
        ]);
    }

    /** GET /api/admin/users/{id} */
    public function show(int $id): JsonResponse
    {
        $user = User::query()->with(['customerProfile.addresses', 'providerProfile.providerServices.service', 'providerProfile.documents', 'wallet'])->find($id);
        if (!$user) {
            return $this->notFound();
        }

        $profile = $user->providerProfile;
        $reviewQuery = ProviderReview::query()->where('provider_user_id', $user->id);

        return response()->json([
            'success' => true,
            'data' => $this->summary($user) + [
                'customer' => $user->customerProfile ? [
                    'profile_completed' => (bool) $user->customerProfile->profile_completed,
                    'birth_date' => $user->customerProfile->birth_date?->toDateString(),
                    'addresses' => $user->customerProfile->addresses->map(fn ($a) => [
                        'id' => $a->id,
                        'title' => $a->title,
                        'province' => $a->province,
                        'district' => $a->district,
                        'neighborhood' => $a->neighborhood,
                        'street' => $a->street,
                        'is_default' => (bool) $a->is_default,
                    ])->values(),
                ] : null,
                'provider' => $profile ? [
                    'business_name' => $profile->business_name,
                    'title' => $profile->title,
                    'bio' => $profile->bio,
                    'provider_type' => $profile->provider_type,
                    'work_mode' => $profile->work_mode,
                    'city' => $profile->city,
                    'district' => $profile->district,
                    'address_detail' => $profile->address_detail,
                    'service_radius_km' => (int) $profile->service_radius_km,
                    'experience_years' => $profile->experience_years,
                    'is_approved' => (bool) $profile->is_approved,
                    'identity_status' => $profile->identity_status,
                    'is_online' => (bool) $profile->is_online,
                    'accepts_new_clients' => (bool) $profile->accepts_new_clients,
                    'commission_rate_override' => $profile->commission_rate_override !== null ? (float) $profile->commission_rate_override : null,
                    'cover_url' => $profile->cover_url,
                    'gallery' => $profile->gallery ?? [],
                    'services' => $profile->providerServices->map(fn ($ps) => [
                        'name' => $ps->service?->name,
                        'price' => round($ps->effectivePrice(), 2),
                        'duration_minutes' => $ps->effectiveDurationMinutes(),
                        'is_active' => (bool) $ps->is_active,
                    ])->values(),
                    'documents' => $profile->documents->map(fn ($d) => [
                        'id' => $d->id,
                        'document_type' => $d->document_type,
                        'status' => $d->status,
                    ])->values(),
                    'review_count' => (clone $reviewQuery)->count(),
                    'rating' => (clone $reviewQuery)->count() ? round((float) (clone $reviewQuery)->avg('rating'), 2) : null,
                ] : null,
                'counts' => [
                    'reviews_received' => (clone $reviewQuery)->count(),
                    'reviews_given' => ProviderReview::query()->where('customer_user_id', $user->id)->count(),
                    'reports_against' => ContentReport::query()->where('reported_user_id', $user->id)->count(),
                ],
            ],
        ]);
    }

    /** PATCH /api/admin/users/{id} */
    public function update(Request $request, int $id): JsonResponse
    {
        $user = User::query()->with(['providerProfile', 'customerProfile'])->find($id);
        if (!$user) {
            return $this->notFound();
        }

        $validated = $request->validate([
            'first_name' => ['sometimes', 'string', 'max:50'],
            'last_name' => ['sometimes', 'string', 'max:50'],
            'email' => ['sometimes', 'nullable', 'email:rfc', 'max:150', Rule::unique('users', 'email')->ignore($user->id)],
            'phone' => ['sometimes', 'nullable', 'string', 'max:30', Rule::unique('users', 'phone')->ignore($user->id)],
            'gender' => ['sometimes', 'nullable', 'in:male,female,other,unspecified'],
            'status' => ['sometimes', 'in:' . implode(',', self::STATUSES)],
            'birth_date' => ['sometimes', 'nullable', 'date', 'before:today'],
            'provider' => ['sometimes', 'array'],
            'provider.business_name' => ['nullable', 'string', 'max:150'],
            'provider.title' => ['nullable', 'string', 'max:150'],
            'provider.bio' => ['nullable', 'string', 'max:1000'],
            'provider.provider_type' => ['sometimes', 'in:barber,coiffeur'],
            'provider.work_mode' => ['sometimes', 'in:venue,mobile,both'],
            'provider.city' => ['nullable', 'string', 'max:100'],
            'provider.district' => ['nullable', 'string', 'max:100'],
            'provider.address_detail' => ['nullable', 'string', 'max:500'],
            'provider.service_radius_km' => ['sometimes', 'integer', 'min:1', 'max:100'],
            'provider.experience_years' => ['sometimes', 'nullable', 'integer', 'min:0', 'max:60'],
            'provider.is_online' => ['sometimes', 'boolean'],
            'provider.accepts_new_clients' => ['sometimes', 'boolean'],
            'provider.commission_rate_override' => ['sometimes', 'nullable', 'numeric', 'min:0', 'max:100'],
        ]);

        $adminId = (int) $request->user()->id;
        if (isset($validated['status']) && $validated['status'] !== 'active'
            && ($user->role === User::ROLE_ADMIN || $user->id === $adminId)) {
            return response()->json(['success' => false, 'message' => 'Yönetici hesapları pasife alınamaz.'], 422);
        }
        if (array_key_exists('provider', $validated) && !$user->providerProfile) {
            return response()->json(['success' => false, 'message' => 'Bu üyenin hizmet veren profili yok.'], 422);
        }

        $changed = [];
        DB::transaction(function () use ($user, $validated, &$changed) {
            $account = array_intersect_key($validated, array_flip(['first_name', 'last_name', 'email', 'phone', 'gender', 'status']));
            if (isset($account['email'])) {
                $account['email'] = strtolower(trim($account['email']));
            }
            if (isset($account['first_name']) || isset($account['last_name'])) {
                $account['name'] = trim(($account['first_name'] ?? $user->first_name) . ' ' . ($account['last_name'] ?? $user->last_name));
            }
            if ($account) {
                $user->update($account);
                $changed = array_merge($changed, array_keys($account));
            }
            if (($account['status'] ?? null) === 'suspended') {
                $user->tokens()->delete();
            }

            if (array_key_exists('birth_date', $validated) && $user->customerProfile) {
                $user->customerProfile->update(['birth_date' => $validated['birth_date']]);
                $changed[] = 'birth_date';
            }
            if (!empty($validated['provider']) && $user->providerProfile) {
                $user->providerProfile->update($validated['provider']);
                $changed = array_merge($changed, array_map(fn ($k) => "provider.$k", array_keys($validated['provider'])));
            }
        });

        AdminLog::logAction($adminId, AdminLog::ACTION_USER_UPDATED, AdminLog::TARGET_USER, (int) $user->id, ['fields' => array_values(array_unique($changed))]);

        return response()->json(['success' => true, 'message' => 'Üye bilgileri güncellendi.']);
    }

    /** POST /api/admin/users/{id}/password */
    public function resetPassword(Request $request, int $id): JsonResponse
    {
        $user = User::query()->find($id);
        if (!$user) {
            return $this->notFound();
        }
        $validated = $request->validate([
            'password' => ['required', 'string', Password::min(8)->letters()->numbers()],
        ], ['password.min' => 'Şifre en az 8 karakter olmalıdır.']);

        $user->update(['password' => $validated['password']]);
        $user->tokens()->delete();

        AdminLog::logAction((int) $request->user()->id, AdminLog::ACTION_USER_PASSWORD_RESET, AdminLog::TARGET_USER, (int) $user->id);

        return response()->json(['success' => true, 'message' => 'Şifre güncellendi. Üyenin açık oturumları kapatıldı.']);
    }

    /** DELETE /api/admin/users/{id}/avatar */
    public function destroyAvatar(Request $request, int $id): JsonResponse
    {
        $user = User::query()->find($id);
        if (!$user) {
            return $this->notFound();
        }

        $oldPath = ProfileMediaController::managedPublicPath($user->avatar_url);
        $user->update(['avatar_url' => null]);
        if ($oldPath) {
            Storage::disk('public')->delete($oldPath);
        }

        AdminLog::logAction((int) $request->user()->id, AdminLog::ACTION_USER_AVATAR_REMOVED, AdminLog::TARGET_USER, (int) $user->id);

        return response()->json(['success' => true, 'message' => 'Profil fotoğrafı kaldırıldı.']);
    }

    /** DELETE /api/admin/users/{id} */
    public function destroy(Request $request, int $id): JsonResponse
    {
        $user = User::withTrashed()->find($id);
        if (!$user) {
            return $this->notFound();
        }
        if ($user->role === User::ROLE_ADMIN || $user->id === (int) $request->user()->id) {
            return response()->json(['success' => false, 'message' => 'Yönetici hesapları silinemez.'], 422);
        }

        if ($user->is_demo) {
            // Demo accounts hold no real history: remove them (and everything attached) for good.
            $user->forceDelete();
        } else {
            if ($user->trashed()) {
                return response()->json(['success' => false, 'message' => 'Hesap zaten kapatılmış.'], 409);
            }
            if ($reason = $this->deletion->blockingReason($user)) {
                return response()->json(['success' => false, 'message' => $reason], 409);
            }
            $this->deletion->anonymizeAndDelete($user);
        }

        AdminLog::logAction((int) $request->user()->id, AdminLog::ACTION_USER_DELETED, AdminLog::TARGET_USER, $id, ['role' => $user->role, 'demo' => (bool) $user->is_demo]);

        return response()->json(['success' => true, 'message' => 'Hesap kapatıldı.']);
    }

    /** GET /api/admin/users/{id}/reviews */
    public function reviews(int $id): JsonResponse
    {
        if (!User::query()->whereKey($id)->exists()) {
            return $this->notFound();
        }

        $map = fn (ProviderReview $r) => [
            'id' => $r->id,
            'rating' => $r->rating,
            'comment' => $r->comment,
            'created_at' => $r->created_at?->toIso8601String(),
            'provider' => ['id' => $r->provider_user_id, 'name' => $r->provider?->name],
            'customer' => ['id' => $r->customer_user_id, 'name' => $r->customer?->name],
        ];

        return response()->json([
            'success' => true,
            'data' => [
                'received' => ProviderReview::with(['provider:id,name', 'customer:id,name'])->where('provider_user_id', $id)->latest()->limit(100)->get()->map($map)->values(),
                'given' => ProviderReview::with(['provider:id,name', 'customer:id,name'])->where('customer_user_id', $id)->latest()->limit(100)->get()->map($map)->values(),
            ],
        ]);
    }

    /** DELETE /api/admin/reviews/{id} */
    public function destroyReview(Request $request, int $id): JsonResponse
    {
        $review = ProviderReview::query()->find($id);
        if (!$review) {
            return response()->json(['success' => false, 'message' => 'Değerlendirme bulunamadı.'], 404);
        }
        $meta = ['provider_user_id' => $review->provider_user_id, 'customer_user_id' => $review->customer_user_id, 'rating' => $review->rating];
        $review->delete();

        AdminLog::logAction((int) $request->user()->id, AdminLog::ACTION_REVIEW_DELETED, AdminLog::TARGET_REVIEW, $id, $meta);

        return response()->json(['success' => true, 'message' => 'Değerlendirme silindi.']);
    }

    private function summary(User $user): array
    {
        return [
            'id' => $user->id,
            'role' => $user->role,
            'name' => $user->name,
            'first_name' => $user->first_name,
            'last_name' => $user->last_name,
            'email' => $user->email,
            'phone' => $user->phone,
            'gender' => $user->gender,
            'status' => $user->status,
            'is_demo' => (bool) $user->is_demo,
            'avatar_url' => $user->avatar_url,
            'created_at' => $user->created_at?->toIso8601String(),
            'last_login_at' => $user->last_login_at?->toIso8601String(),
            'deleted_at' => $user->deleted_at?->toIso8601String(),
        ];
    }

    private function notFound(): JsonResponse
    {
        return response()->json(['success' => false, 'message' => 'Üye bulunamadı.'], 404);
    }
}
