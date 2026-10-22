<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\ProviderDocumentResource;
use App\Http\Resources\ProviderProfileResource;
use App\Http\Resources\UserResource;
use App\Models\AdminLog;
use App\Models\ProviderDocument;
use App\Models\ProviderProfile;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\HttpFoundation\StreamedResponse;

class AdminProviderApplicationController extends Controller
{
    /**
     * List all provider applications with filtering and pagination.
     * Accessible only by ADMIN.
     */
    public function index(Request $request): JsonResponse
    {
        $status = strtoupper(trim($request->query('status', 'ALL')));
        $type = strtolower(trim($request->query('type', 'ALL')));
        $search = trim($request->query('search', ''));
        $perPage = max(1, min(100, (int) $request->query('per_page', 15)));

        $query = ProviderProfile::with([
            'user',
            'documents',
            'providerServices.service',
        ]);

        // Filter by Status
        if ($status !== 'ALL' && !empty($status)) {
            if ($status === 'APPROVED') {
                $query->where('is_approved', true)
                    ->where('identity_status', 'APPROVED');
            } elseif ($status === 'REUPLOAD_REQUIRED') {
                $query->where('identity_status', 'REUPLOAD_REQUIRED');
            } elseif ($status === 'REJECTED') {
                $query->where('identity_status', 'REJECTED');
            } elseif ($status === 'PENDING') {
                $query->where(function ($q) {
                    $q->where('identity_status', 'PENDING')
                        ->orWhere(function ($sub) {
                            $sub->where('is_approved', false)
                                ->whereNotIn('identity_status', ['REJECTED', 'REUPLOAD_REQUIRED']);
                        });
                });
            }
        }

        // Filter by Provider Type
        if ($type !== 'ALL' && in_array($type, ['barber', 'coiffeur'], true)) {
            $query->where('provider_type', $type);
        }

        // Search Filter: name, email, phone, business_name
        if (!empty($search)) {
            $query->where(function ($q) use ($search) {
                $q->where('business_name', 'like', "%{$search}%")
                    ->orWhereHas('user', function ($uQuery) use ($search) {
                        $uQuery->where('name', 'like', "%{$search}%")
                            ->orWhere('email', 'like', "%{$search}%")
                            ->orWhere('phone', 'like', "%{$search}%");
                    });
            });
        }

        // Order by priority: PENDING first, then by latest creation
        $applications = $query
            ->orderByRaw("CASE WHEN identity_status = 'PENDING' OR (is_approved = 0 AND identity_status NOT IN ('REJECTED', 'REUPLOAD_REQUIRED')) THEN 0 ELSE 1 END")
            ->latest('id')
            ->paginate($perPage);

        // Transform application items cleanly without exposing internal paths
        $transformedData = $applications->getCollection()->map(function (ProviderProfile $profile) {
            $user = $profile->user;
            $docs = $profile->documents;

            return [
                'id' => (string) $profile->id,
                'provider_profile_id' => (string) $profile->id,
                'user_id' => (string) $profile->user_id,
                'user' => $user ? [
                    'id' => (string) $user->id,
                    'name' => $user->name,
                    'first_name' => $user->first_name,
                    'last_name' => $user->last_name,
                    'email' => $user->email,
                    'phone' => $user->phone,
                    'avatar_url' => $user->avatar_url,
                    'created_at' => $user->created_at?->toISOString(),
                ] : null,
                'business_name' => $profile->business_name,
                'provider_type' => $profile->provider_type,
                'work_mode' => $profile->work_mode,
                'city' => $profile->city,
                'district' => $profile->district,
                'experience_years' => $profile->experience_years,
                'profile_completed' => (bool) $profile->profile_completed,
                'is_approved' => (bool) $profile->is_approved,
                'identity_status' => $profile->identity_status,
                'created_at' => $profile->created_at?->toISOString(),
                'reviewed_at' => $profile->reviewed_at?->toISOString(),
                'approved_at' => $profile->approved_at?->toISOString(),
                'rejection_reason' => $profile->rejection_reason,
                'reupload_reason' => $profile->reupload_reason,
                'has_received_welcome_bonus' => (bool) $profile->has_received_welcome_bonus,
                'is_verified' => $profile->isVerified(),
                'documents_count' => $docs->count(),
                'approved_documents_count' => $docs->where('status', ProviderDocument::STATUS_APPROVED)->count(),
                'documents' => ProviderDocumentResource::collection($docs),
            ];
        });

        return response()->json([
            'success' => true,
            'data' => $transformedData,
            'pagination' => [
                'current_page' => $applications->currentPage(),
                'last_page' => $applications->lastPage(),
                'per_page' => $applications->perPage(),
                'total' => $applications->total(),
            ],
            'counts' => [
                'all' => ProviderProfile::count(),
                'pending' => ProviderProfile::where(function ($q) {
                    $q->where('identity_status', 'PENDING')
                        ->orWhere(function ($sub) {
                            $sub->where('is_approved', false)
                                ->whereNotIn('identity_status', ['REJECTED', 'REUPLOAD_REQUIRED']);
                        });
                })->count(),
                'approved' => ProviderProfile::where('is_approved', true)->where('identity_status', 'APPROVED')->count(),
                'reupload_required' => ProviderProfile::where('identity_status', 'REUPLOAD_REQUIRED')->count(),
                'rejected' => ProviderProfile::where('identity_status', 'REJECTED')->count(),
            ],
        ]);
    }

    /**
     * Get comprehensive application detail for review.
     * Shows user, provider profile, catalog services, documents, and audit logs.
     */
    public function show(string|int $id): JsonResponse
    {
        $cleanId = is_numeric($id) ? (int) $id : (int) preg_replace('/[^0-9]/', '', (string) $id);

        // Support lookup by profile id or user id (prioritize profile id)
        $profile = ProviderProfile::with([
            'user',
            'providerServices.service.category',
            'documents',
        ])->find($cleanId)
        ?? ProviderProfile::with([
            'user',
            'providerServices.service.category',
            'documents',
        ])->where('user_id', $cleanId)->first();

        if (!$profile) {
            return response()->json([
                'success' => false,
                'message' => 'Hizmet veren başvurusu bulunamadı.',
            ], 404);
        }

        $user = $profile->user;

        // Fetch audit logs for this provider
        $auditLogs = AdminLog::with('adminUser')
            ->where(function ($q) use ($profile) {
                $q->where('target_type', AdminLog::TARGET_PROVIDER)
                    ->where('target_id', $profile->id);
            })
            ->orWhere(function ($q) use ($profile) {
                $docIds = $profile->documents()->pluck('id')->toArray();
                if (!empty($docIds)) {
                    $q->where('target_type', AdminLog::TARGET_PROVIDER_DOCUMENT)
                        ->whereIn('target_id', $docIds);
                }
            })
            ->latest('created_at')
            ->limit(30)
            ->get()
            ->map(function ($log) {
                return [
                    'id' => (string) $log->id,
                    'action' => $log->action,
                    'target_type' => $log->target_type,
                    'target_id' => (string) $log->target_id,
                    'metadata' => $log->metadata,
                    'note' => $log->metadata['note'] ?? $log->metadata['reason'] ?? $log->action,
                    'created_at' => $log->created_at?->toISOString(),
                    'admin_name' => $log->adminUser?->name ?? 'Admin',
                ];
            });

        return response()->json([
            'success' => true,
            'data' => [
                'id' => (string) $profile->id,
                'provider_profile_id' => (string) $profile->id,
                'user_id' => (string) $profile->user_id,
                'user' => $user ? [
                    'id' => (string) $user->id,
                    'name' => $user->name,
                    'first_name' => $user->first_name,
                    'last_name' => $user->last_name,
                    'email' => $user->email,
                    'phone' => $user->phone,
                    'gender' => $user->gender,
                    'avatar_url' => $user->avatar_url,
                    'created_at' => $user->created_at?->toISOString(),
                ] : null,
                'provider_type' => $profile->provider_type,
                'type' => $profile->provider_type, // Alias for frontend
                'work_mode' => $profile->work_mode,
                'business_name' => $profile->business_name,
                'is_approved' => (bool) $profile->is_approved,
                'identity_status' => $profile->identity_status,
                'is_online' => (bool) $profile->is_online,
                'accepts_new_clients' => (bool) $profile->accepts_new_clients,
                'service_radius_km' => (int) $profile->service_radius_km,
                'experience_years' => $profile->experience_years,
                'profile_completed' => (bool) $profile->profile_completed,
                'city' => $profile->city,
                'district' => $profile->district,
                'address_detail' => $profile->address_detail,
                'bio' => $profile->bio,
                'title' => $profile->title,
                'cover_url' => $profile->cover_url,
                'cover_position_x' => (int) $profile->cover_position_x,
                'cover_position_y' => (int) $profile->cover_position_y,
                'gallery' => $profile->gallery ?? [],
                'rejection_reason' => $profile->rejection_reason,
                'reupload_reason' => $profile->reupload_reason,
                'has_received_welcome_bonus' => (bool) $profile->has_received_welcome_bonus,
                'approved_at' => $profile->approved_at?->toISOString(),
                'reviewed_at' => $profile->reviewed_at?->toISOString(),
                'is_verified' => $profile->isVerified(),
                'services' => $profile->providerServices->map(function ($ps) {
                    return [
                        'id' => (string) $ps->id,
                        'service_id' => (string) $ps->service_id,
                        'name' => $ps->service?->name ?? 'Hizmet',
                        'category' => $ps->service?->category?->name ?? 'Genel',
                        'custom_price' => $ps->custom_price !== null ? (float) $ps->custom_price : null,
                        'custom_duration_minutes' => $ps->custom_duration_minutes,
                        'is_active' => (bool) $ps->is_active,
                    ];
                }),
                'documents' => ProviderDocumentResource::collection($profile->documents),
                'audit_logs' => $auditLogs,
            ],
        ]);
    }

    /**
     * Review overall Provider Application (APPROVE, REJECT, REUPLOAD_REQUIRED).
     * Enforces strict business rules before approving.
     */
    public function reviewApplication(Request $request, string|int $id): JsonResponse
    {
        $admin = $request->user();

        $validated = $request->validate([
            'action' => ['required', 'string', 'in:APPROVE,REJECT,REUPLOAD_REQUIRED,approve,reject,reupload,reupload_required'],
            'reason' => ['nullable', 'string', 'max:1000'],
        ]);

        $rawAction = strtoupper(trim($validated['action']));
        $action = match ($rawAction) {
            'APPROVE' => 'APPROVE',
            'REJECT' => 'REJECT',
            'REUPLOAD', 'REUPLOAD_REQUIRED' => 'REUPLOAD_REQUIRED',
            default => 'APPROVE',
        };

        $reason = trim($validated['reason'] ?? '');

        // Reason is strictly required for REJECT and REUPLOAD_REQUIRED
        if (in_array($action, ['REJECT', 'REUPLOAD_REQUIRED'], true) && empty($reason)) {
            return response()->json([
                'success' => false,
                'message' => $action === 'REJECT'
                    ? 'Başvuru reddi için gerekçe belirtilmesi zorunludur.'
                    : 'Yeniden belge talebi için gerekçe belirtilmesi zorunludur.',
                'errors' => [
                    'reason' => ['Gerekçe alanı zorunludur.'],
                ],
            ], 422);
        }

        $cleanId = is_numeric($id) ? (int) $id : (int) preg_replace('/[^0-9]/', '', (string) $id);

        $profile = ProviderProfile::find($cleanId)
            ?? ProviderProfile::where('user_id', $cleanId)->first();

        if (!$profile) {
            return response()->json([
                'success' => false,
                'message' => 'Hizmet veren başvurusu bulunamadı.',
            ], 404);
        }

        // =========================================================================
        // APPROVE VALIDATION RULES (Strict Backend Verification)
        // =========================================================================
        if ($action === 'APPROVE') {
            $errors = [];

            // 1. profile_completed === true
            if (!$profile->profile_completed) {
                $errors[] = 'Hizmet verenin profil tamamlama (onboarding) süreci tamamlanmamış (profile_completed = false).';
            }

            // 2. En az 1 mesleki belge mevcut
            $hasVocationalDoc = $profile->documents()
                ->whereIn('document_type', [
                    ProviderDocument::TYPE_DIPLOMA,
                    ProviderDocument::TYPE_MASTER_CERTIFICATE,
                    ProviderDocument::TYPE_JOURNEYMAN_CERTIFICATE,
                ])
                ->exists();

            if (!$hasVocationalDoc) {
                $errors[] = 'Hizmet verene ait en az 1 mesleki yeterlilik belgesi (Diploma, Ustalık veya Kalfalık) yüklenmiş olmalıdır.';
            }

            // 3. En az 1 mesleki belge APPROVED olmalı
            $hasApprovedDoc = $profile->hasApprovedDocument();
            if (!$hasApprovedDoc) {
                $errors[] = 'Hizmet verenin en az 1 mesleki belgesi yönetim tarafından onaylanmış (APPROVED) olmalıdır.';
            }

            // 4. Provider profile gerekli alanları dolu olmalı
            $hasRequiredFields = !empty($profile->provider_type)
                && !empty($profile->work_mode)
                && $profile->service_radius_km > 0
                && $profile->experience_years !== null
                && (!empty($profile->city) || !empty($profile->address_detail));

            if (!$hasRequiredFields) {
                $errors[] = 'Hizmet veren profilindeki zorunlu alanlar (hizmet türü, çalışma şekli, hizmet yarıçapı, deneyim yılı, konum) eksiksiz doldurulmuş olmalıdır.';
            }

            // 5. En az 1 aktif hizmet seçili olmalı
            $hasActiveService = $profile->providerServices()->where('is_active', true)->exists();
            if (!$hasActiveService) {
                $errors[] = 'Hizmet verene ait en az 1 aktif hizmet tanımlanmış olmalıdır.';
            }

            if (!empty($errors)) {
                return response()->json([
                    'success' => false,
                    'message' => 'Hizmet veren onaylama şartlarını karşılamıyor.',
                    'errors' => [
                        'approval_requirements' => $errors,
                    ],
                ], 422);
            }
        }

        // Apply Decision in a Transaction
        DB::transaction(function () use ($profile, $action, $reason, $admin) {
            $now = now();

            if ($action === 'APPROVE') {
                $profile->update([
                    'is_approved' => true,
                    'identity_status' => 'APPROVED',
                    'approved_at' => $profile->approved_at ?? $now,
                    'reviewed_at' => $now,
                    'rejection_reason' => null,
                    'reupload_reason' => null,
                ]);

                // Hook: Credit Welcome Bonus Promo (Idempotent per provider)
                app(\App\Services\FinancialService::class)->creditWelcomeBonus($profile->user_id);

                AdminLog::logAction(
                    $admin->id,
                    AdminLog::ACTION_PROVIDER_APPROVED,
                    AdminLog::TARGET_PROVIDER,
                    $profile->id,
                    [
                        'business_name' => $profile->business_name,
                        'provider_user_id' => $profile->user_id,
                        'note' => 'Hizmet veren başvurusu yönetici tarafından onaylandı.',
                    ]
                );
            } elseif ($action === 'REJECT') {
                $profile->update([
                    'is_approved' => false,
                    'identity_status' => 'REJECTED',
                    'rejection_reason' => $reason,
                    'reviewed_at' => $now,
                ]);

                AdminLog::logAction(
                    $admin->id,
                    AdminLog::ACTION_PROVIDER_REJECTED,
                    AdminLog::TARGET_PROVIDER,
                    $profile->id,
                    [
                        'reason' => $reason,
                        'provider_user_id' => $profile->user_id,
                        'note' => "Başvuru reddedildi: {$reason}",
                    ]
                );
            } elseif ($action === 'REUPLOAD_REQUIRED') {
                $profile->update([
                    'is_approved' => false,
                    'identity_status' => 'REUPLOAD_REQUIRED',
                    'reupload_reason' => $reason,
                    'rejection_reason' => $reason,
                    'reviewed_at' => $now,
                ]);

                AdminLog::logAction(
                    $admin->id,
                    AdminLog::ACTION_PROVIDER_REUPLOAD_REQUIRED,
                    AdminLog::TARGET_PROVIDER,
                    $profile->id,
                    [
                        'reason' => $reason,
                        'provider_user_id' => $profile->user_id,
                        'note' => "Yeniden belge istendi: {$reason}",
                    ]
                );
            }
        });

        $freshProfile = $profile->fresh(['user', 'documents', 'providerServices.service']);

        return response()->json([
            'success' => true,
            'message' => match ($action) {
                'APPROVE' => 'Hizmet veren başvurusu başarıyla onaylandı.',
                'REJECT' => 'Hizmet veren başvurusu reddedildi.',
                'REUPLOAD_REQUIRED' => 'Yeniden belge talebi hizmet verene iletildi.',
            },
            'data' => new ProviderProfileResource($freshProfile),
        ]);
    }

    /**
     * Review an individual Provider KYC Document (APPROVED, REJECTED, REUPLOAD_REQUIRED).
     * Enforces required reason on REJECTED and REUPLOAD_REQUIRED.
     */
    public function reviewDocument(Request $request, string|int $id): JsonResponse
    {
        $admin = $request->user();

        $validated = $request->validate([
            'action' => ['required', 'string', 'in:APPROVED,REJECTED,REUPLOAD_REQUIRED,approved,rejected,reupload,reupload_required'],
            'reason' => ['nullable', 'string', 'max:1000'],
        ]);

        $rawAction = strtoupper(trim($validated['action']));
        $action = match ($rawAction) {
            'APPROVED' => ProviderDocument::STATUS_APPROVED,
            'REJECTED' => ProviderDocument::STATUS_REJECTED,
            'REUPLOAD', 'REUPLOAD_REQUIRED' => ProviderDocument::STATUS_REUPLOAD_REQUIRED,
            default => ProviderDocument::STATUS_APPROVED,
        };

        $reason = trim($validated['reason'] ?? '');

        // Reason mandatory for REJECTED and REUPLOAD_REQUIRED
        if (in_array($action, [ProviderDocument::STATUS_REJECTED, ProviderDocument::STATUS_REUPLOAD_REQUIRED], true) && empty($reason)) {
            return response()->json([
                'success' => false,
                'message' => $action === ProviderDocument::STATUS_REJECTED
                    ? 'Belge reddi için gerekçe belirtilmesi zorunludur.'
                    : 'Belge yenileme talebi için gerekçe belirtilmesi zorunludur.',
                'errors' => [
                    'reason' => ['Gerekçe alanı zorunludur.'],
                ],
            ], 422);
        }

        $cleanId = is_numeric($id) ? (int) $id : (int) preg_replace('/[^0-9]/', '', (string) $id);
        $document = ProviderDocument::find($cleanId);

        if (!$document) {
            return response()->json([
                'success' => false,
                'message' => 'Belge bulunamadı.',
            ], 404);
        }

        DB::transaction(function () use ($document, $action, $reason, $admin) {
            $document->update([
                'status' => $action,
                'rejection_reason' => $action === ProviderDocument::STATUS_APPROVED ? null : $reason,
                'reviewed_at' => now(),
            ]);

            $logAction = match ($action) {
                ProviderDocument::STATUS_APPROVED => AdminLog::ACTION_PROVIDER_DOCUMENT_APPROVED,
                ProviderDocument::STATUS_REJECTED => AdminLog::ACTION_PROVIDER_DOCUMENT_REJECTED,
                ProviderDocument::STATUS_REUPLOAD_REQUIRED => AdminLog::ACTION_PROVIDER_DOCUMENT_REUPLOAD_REQUIRED,
            };

            // Audit log without storage_path
            AdminLog::logAction(
                $admin->id,
                $logAction,
                AdminLog::TARGET_PROVIDER_DOCUMENT,
                $document->id,
                [
                    'document_type' => $document->document_type,
                    'original_name' => $document->original_name,
                    'reason' => $reason ?: null,
                    'note' => "Belge {$action} olarak işaretlendi: {$document->original_name}",
                ]
            );
        });

        return response()->json([
            'success' => true,
            'message' => 'Belge durumu güncellendi.',
            'data' => new ProviderDocumentResource($document->fresh()),
        ]);
    }

    /**
     * Preview / Stream private document file directly to authenticated ADMIN.
     * Never exposes filesystem path.
     */
    public function previewDocument(Request $request, string|int $id): StreamedResponse|JsonResponse
    {
        $cleanId = is_numeric($id) ? (int) $id : (int) preg_replace('/[^0-9]/', '', (string) $id);
        $document = ProviderDocument::find($cleanId);

        if (!$document) {
            return response()->json([
                'success' => false,
                'message' => 'Belge bulunamadı.',
            ], 404);
        }

        if (!Storage::disk('local')->exists($document->storage_path)) {
            return response()->json([
                'success' => false,
                'message' => 'Belge dosyası depolama alanında bulunamadı.',
            ], 404);
        }

        // Return inline stream response
        return Storage::disk('local')->response(
            $document->storage_path,
            $document->original_name,
            [
                'Content-Type' => $document->mime_type ?: 'application/octet-stream',
                'Content-Disposition' => 'inline; filename="' . addslashes($document->original_name) . '"',
                'Cache-Control' => 'no-cache, private',
            ]
        );
    }
}
