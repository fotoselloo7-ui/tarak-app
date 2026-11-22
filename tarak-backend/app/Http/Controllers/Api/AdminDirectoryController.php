<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AdminLog;
use App\Models\ProviderProfile;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class AdminDirectoryController extends Controller
{
    /**
     * List directory / map businesses for admin moderation.
     * Deliberately separate from KYC / vocational verification (`identity_status`, `is_approved`).
     */
    public function index(Request $request): JsonResponse
    {
        $status = strtoupper(trim((string) $request->query('status', 'ALL')));
        $workMode = strtolower(trim((string) $request->query('work_mode', 'ALL')));
        $type = strtolower(trim((string) $request->query('type', 'ALL')));
        $search = trim((string) $request->query('search', ''));
        $perPage = max(1, min(100, (int) $request->query('per_page', 15)));

        $query = ProviderProfile::with(['user', 'documents', 'serviceAreas'])
            ->where(function ($q) {
                $q->where('directory_listed', true)
                    ->orWhere('directory_status', '!=', ProviderProfile::DIRECTORY_NOT_REQUESTED);
            });

        if ($status !== 'ALL' && in_array($status, [
            ProviderProfile::DIRECTORY_PENDING,
            ProviderProfile::DIRECTORY_APPROVED,
            ProviderProfile::DIRECTORY_REJECTED,
            ProviderProfile::DIRECTORY_SUSPENDED,
        ], true)) {
            $query->where('directory_status', $status);
        }

        if ($workMode !== 'all' && in_array($workMode, ['venue', 'mobile', 'both'], true)) {
            $query->where('work_mode', $workMode);
        }

        if ($type !== 'all' && in_array($type, ['barber', 'coiffeur'], true)) {
            $query->where('provider_type', $type);
        }

        if ($search !== '') {
            $like = '%' . str_replace(['\\', '%', '_'], ['\\\\', '\\%', '\\_'], $search) . '%';
            $query->where(function ($q) use ($like) {
                $q->where('business_name', 'like', $like)
                    ->orWhere('city', 'like', $like)
                    ->orWhere('district', 'like', $like)
                    ->orWhereHas('user', fn ($u) => $u->where('name', 'like', $like)->orWhere('email', 'like', $like));
            });
        }

        $businesses = $query
            ->orderByRaw("CASE WHEN directory_status = 'PENDING' THEN 0 ELSE 1 END")
            ->latest('id')
            ->paginate($perPage);

        $data = $businesses->getCollection()->map(fn (ProviderProfile $p) => $this->presentRow($p));

        return response()->json([
            'success' => true,
            'data' => $data,
            'pagination' => [
                'current_page' => $businesses->currentPage(),
                'last_page' => $businesses->lastPage(),
                'per_page' => $businesses->perPage(),
                'total' => $businesses->total(),
            ],
            'counts' => [
                'pending' => ProviderProfile::where('directory_status', ProviderProfile::DIRECTORY_PENDING)->count(),
                'approved' => ProviderProfile::where('directory_status', ProviderProfile::DIRECTORY_APPROVED)->count(),
                'rejected' => ProviderProfile::where('directory_status', ProviderProfile::DIRECTORY_REJECTED)->count(),
                'suspended' => ProviderProfile::where('directory_status', ProviderProfile::DIRECTORY_SUSPENDED)->count(),
            ],
        ]);
    }

    public function show(string|int $id): JsonResponse
    {
        $cleanId = is_numeric($id) ? (int) $id : (int) preg_replace('/[^0-9]/', '', (string) $id);
        $profile = ProviderProfile::with(['user', 'documents', 'serviceAreas', 'providerServices.service'])
            ->find($cleanId)
            ?? ProviderProfile::with(['user', 'documents', 'serviceAreas', 'providerServices.service'])
                ->where('user_id', $cleanId)->first();

        if (!$profile) {
            return response()->json(['success' => false, 'message' => 'İşletme kaydı bulunamadı.'], 404);
        }

        $auditLogs = AdminLog::with('adminUser')
            ->where('target_type', AdminLog::TARGET_PROVIDER)
            ->where('target_id', $profile->id)
            ->whereIn('action', [
                AdminLog::ACTION_DIRECTORY_APPROVED,
                AdminLog::ACTION_DIRECTORY_REJECTED,
                AdminLog::ACTION_DIRECTORY_SUSPENDED,
            ])
            ->latest('created_at')
            ->limit(20)
            ->get()
            ->map(fn ($log) => [
                'id' => (string) $log->id,
                'action' => $log->action,
                'note' => $log->metadata['note'] ?? $log->metadata['reason'] ?? $log->action,
                'created_at' => $log->created_at?->toISOString(),
                'admin_name' => $log->adminUser?->name ?? 'Admin',
            ]);

        return response()->json([
            'success' => true,
            'data' => $this->presentRow($profile) + [
                'bio' => $profile->bio,
                'title' => $profile->title,
                'address_detail' => $profile->address_detail,
                'has_public_pin' => $profile->hasPublicVenuePin(),
                'service_radius_km' => (int) $profile->service_radius_km,
                'service_areas' => $profile->serviceAreas->map(fn ($a) => [
                    'province' => $a->province,
                    'district' => $a->district,
                    'neighborhood' => $a->neighborhood,
                ])->values(),
                'contact_phone' => $profile->contact_phone,
                'whatsapp_phone' => $profile->whatsapp_phone,
                'instagram_handle' => $profile->instagram_handle,
                'website_url' => $profile->website_url,
                'audit_logs' => $auditLogs,
            ],
        ]);
    }

    /**
     * Moderate a business directory listing (APPROVE, REJECT, SUSPEND).
     * NEVER modifies vocational verification (`is_approved`, `identity_status`) or welcome bonus.
     */
    public function review(Request $request, string|int $id): JsonResponse
    {
        $admin = $request->user();
        $validated = $request->validate([
            'action' => ['required', 'string', 'in:APPROVE,REJECT,SUSPEND,approve,reject,suspend'],
            'reason' => ['nullable', 'string', 'max:1000'],
        ]);

        $action = strtoupper(trim($validated['action']));
        $reason = trim((string) ($validated['reason'] ?? ''));

        if (in_array($action, ['REJECT', 'SUSPEND'], true) && $reason === '') {
            return response()->json([
                'success' => false,
                'message' => $action === 'REJECT'
                    ? 'Rehber kaydı reddi için gerekçe zorunludur.'
                    : 'Rehber kaydı askıya alma için gerekçe zorunludur.',
                'errors' => ['reason' => ['Gerekçe alanı zorunludur.']],
            ], 422);
        }

        $cleanId = is_numeric($id) ? (int) $id : (int) preg_replace('/[^0-9]/', '', (string) $id);
        $profile = ProviderProfile::with('user')->find($cleanId)
            ?? ProviderProfile::with('user')->where('user_id', $cleanId)->first();

        if (!$profile) {
            return response()->json(['success' => false, 'message' => 'İşletme kaydı bulunamadı.'], 404);
        }

        DB::transaction(function () use ($profile, $action, $reason, $admin) {
            $now = now();

            if ($action === 'APPROVE') {
                $profile->ensureSlug();
                $profile->update([
                    'slug' => $profile->slug,
                    'directory_listed' => true,
                    'directory_status' => ProviderProfile::DIRECTORY_APPROVED,
                    'directory_approved_at' => $profile->directory_approved_at ?? $now,
                    'directory_reviewed_at' => $now,
                    'directory_rejection_reason' => null,
                ]);

                AdminLog::logAction(
                    $admin->id,
                    AdminLog::ACTION_DIRECTORY_APPROVED,
                    AdminLog::TARGET_PROVIDER,
                    $profile->id,
                    [
                        'provider_user_id' => $profile->user_id,
                        'business_name' => $profile->business_name,
                        'note' => 'İşletme rehber kaydı yönetici tarafından onaylandı (doğrulanmış rozet etkilenmedi).',
                    ]
                );
            } elseif ($action === 'REJECT') {
                $profile->update([
                    'directory_status' => ProviderProfile::DIRECTORY_REJECTED,
                    'directory_reviewed_at' => $now,
                    'directory_rejection_reason' => $reason,
                ]);

                AdminLog::logAction(
                    $admin->id,
                    AdminLog::ACTION_DIRECTORY_REJECTED,
                    AdminLog::TARGET_PROVIDER,
                    $profile->id,
                    [
                        'provider_user_id' => $profile->user_id,
                        'reason' => $reason,
                        'note' => "İşletme rehber kaydı reddedildi: {$reason}",
                    ]
                );
            } elseif ($action === 'SUSPEND') {
                $profile->update([
                    'directory_listed' => false,
                    'directory_status' => ProviderProfile::DIRECTORY_SUSPENDED,
                    'directory_reviewed_at' => $now,
                    'directory_rejection_reason' => $reason,
                ]);

                AdminLog::logAction(
                    $admin->id,
                    AdminLog::ACTION_DIRECTORY_SUSPENDED,
                    AdminLog::TARGET_PROVIDER,
                    $profile->id,
                    [
                        'provider_user_id' => $profile->user_id,
                        'reason' => $reason,
                        'note' => "İşletme rehber kaydı askıya alındı: {$reason}",
                    ]
                );
            }
        });

        $fresh = $profile->fresh(['user', 'documents', 'serviceAreas']);

        return response()->json([
            'success' => true,
            'message' => match ($action) {
                'APPROVE' => 'İşletme rehber kaydı onaylandı.',
                'REJECT' => 'İşletme rehber kaydı reddedildi.',
                'SUSPEND' => 'İşletme rehber kaydı askıya alındı.',
            },
            'data' => $this->presentRow($fresh),
        ]);
    }

    private function presentRow(ProviderProfile $profile): array
    {
        return [
            'id' => (string) $profile->id,
            'user_id' => (string) $profile->user_id,
            'slug' => $profile->slug,
            'business_name' => $profile->business_name ?: $profile->user?->name,
            'user_phone' => $profile->user?->phone,
            'provider_type' => $profile->provider_type,
            'work_mode' => $profile->work_mode,
            'city' => $profile->city,
            'district' => $profile->district,
            'directory_listed' => (bool) $profile->directory_listed,
            'directory_status' => $profile->directory_status,
            'directory_approved_at' => $profile->directory_approved_at?->toISOString(),
            'directory_reviewed_at' => $profile->directory_reviewed_at?->toISOString(),
            'directory_rejection_reason' => $profile->directory_rejection_reason,
            'accepts_new_clients' => (bool) $profile->accepts_new_clients,
            'is_approved' => (bool) $profile->is_approved,
            'identity_status' => $profile->identity_status,
            'is_verified' => $profile->isVerified(),
        ];
    }
}
