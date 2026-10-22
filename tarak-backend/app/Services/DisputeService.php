<?php

namespace App\Services;

use App\Models\AdminLog;
use App\Models\Appointment;
use App\Models\CommissionReservation;
use App\Models\DisputeCase;
use App\Models\LocationShareGrant;
use App\Models\PaymentRefund;
use App\Models\ServiceLifecycleEvent;
use App\Models\ServicePayment;
use App\Models\ServiceRequest;
use App\Models\ServiceStartVerification;
use App\Models\User;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
use LogicException;
use Symfony\Component\HttpKernel\Exception\ConflictHttpException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;
use Symfony\Component\HttpKernel\Exception\UnprocessableEntityHttpException;

class DisputeService
{
    public function __construct(
        protected FinancialService $financialService,
        protected ?PaytrRefundService $refundService = null
    ) {
        $this->refundService = $refundService ?: app(PaytrRefundService::class);
    }

    /**
     * Ensure a dispute case exists for the given resource. Idempotent.
     */
    public function ensureDisputeCaseForResource(
        string $resourceType,
        int $resourceId,
        ?int $customerId = null,
        ?int $providerId = null,
        ?string $paymentMethod = null,
        ?string $reason = null,
        ?string $note = null
    ): DisputeCase {
        $case = DisputeCase::where('resource_type', $resourceType)
            ->where('resource_id', $resourceId)
            ->first();

        if ($case) {
            return $case;
        }

        // Resolve missing attributes from the underlying resource
        if ($resourceType === LocationShareGrant::RESOURCE_INSTANT_REQUEST) {
            $req = ServiceRequest::find($resourceId);
            if (!$req) {
                throw new NotFoundHttpException("Service request #{$resourceId} not found");
            }
            $customerId = $customerId ?? $req->customer_user_id;
            $providerId = $providerId ?? $req->assigned_provider_user_id;
            $paymentMethod = $paymentMethod ?? $req->payment_method ?? 'CASH';
            $reason = $reason ?? $req->dispute_reason ?? 'Sorun bildirildi';
            $note = $note ?? $req->dispute_note;
        } elseif ($resourceType === LocationShareGrant::RESOURCE_SCHEDULED_APPOINTMENT) {
            $appt = Appointment::find($resourceId);
            if (!$appt) {
                throw new NotFoundHttpException("Appointment #{$resourceId} not found");
            }
            $customerId = $customerId ?? $appt->customer_user_id;
            $providerId = $providerId ?? $appt->provider_user_id;
            $paymentMethod = $paymentMethod ?? $appt->payment_method ?? 'CASH';
            $reason = $reason ?? $appt->dispute_reason ?? 'Sorun bildirildi';
            $note = $note ?? $appt->dispute_note;
        } else {
            throw new LogicException("Unknown resource type: {$resourceType}");
        }

        if (!$providerId) {
            throw new LogicException("Cannot create dispute case without an assigned provider for resource #{$resourceId}");
        }

        return DisputeCase::create([
            'resource_type' => $resourceType,
            'resource_id' => $resourceId,
            'customer_user_id' => $customerId,
            'provider_user_id' => $providerId,
            'payment_method' => strtoupper($paymentMethod),
            'status' => DisputeCase::STATUS_OPEN,
            'customer_reason' => $reason,
            'customer_note' => $note,
            'opened_at' => now(),
        ]);
    }

    /**
     * List dispute cases with filtering and pagination. SENSITIVE ADDRESS/GPS/RAW CODES OMITTED.
     */
    public function listDisputes(array $filters = [], int $perPage = 15): LengthAwarePaginator
    {
        $query = DisputeCase::query()
            ->with([
                'customer',
                'provider.providerProfile',
                'reviewedByAdmin',
            ])
            ->latest('opened_at');

        // Status filter
        if (!empty($filters['status']) && strtoupper($filters['status']) !== 'ALL') {
            $status = strtoupper($filters['status']);
            $query->where('status', $status);
        }

        // Resource type filter
        if (!empty($filters['resource_type']) && strtoupper($filters['resource_type']) !== 'ALL') {
            $query->where('resource_type', strtoupper($filters['resource_type']));
        }

        // Payment method filter
        if (!empty($filters['payment_method']) && strtoupper($filters['payment_method']) !== 'ALL') {
            $query->where('payment_method', strtoupper($filters['payment_method']));
        }

        // Search filter (case id, customer name/email, provider name/email)
        if (!empty($filters['search'])) {
            $search = trim($filters['search']);
            $query->where(function ($q) use ($search) {
                if (is_numeric($search)) {
                    $q->orWhere('id', (int) $search)
                      ->orWhere('resource_id', (int) $search);
                }
                $q->orWhereHas('customer', function ($cq) use ($search) {
                    $cq->where('name', 'like', "%{$search}%")
                       ->orWhere('email', 'like', "%{$search}%");
                })->orWhereHas('provider', function ($pq) use ($search) {
                    $pq->where('name', 'like', "%{$search}%")
                       ->orWhere('email', 'like', "%{$search}%")
                       ->orWhereHas('providerProfile', function ($ppq) use ($search) {
                           $ppq->where('business_name', 'like', "%{$search}%");
                       });
                });
            });
        }

        $paginator = $query->paginate($perPage);

        // Transform collection to safe summary projection
        $paginator->getCollection()->transform(function (DisputeCase $case) {
            return $this->formatCaseSummary($case);
        });

        return $paginator;
    }

    /**
     * Get detailed dispute case projection for admin review.
     * Raw start codes, exact GPS coordinates, exact address lines, and encryption keys are strictly omitted.
     */
    public function getDisputeDetail(int $caseId): array
    {
        $case = DisputeCase::with([
            'customer',
            'provider.providerProfile',
            'reviewedByAdmin',
        ])->find($caseId);

        if (!$case) {
            throw new NotFoundHttpException("Dispute case #{$caseId} not found");
        }

        $resource = $case->getResource();
        $financialSummary = $this->financialService->getResourceFinanceSummary(
            $case->resource_type,
            $case->resource_id,
            $case->payment_method
        );

        // Safe Start Code verification audit (WITHOUT raw 4-digit code, without hash, without encrypted payload)
        $startVerification = ServiceStartVerification::where('resource_type', $case->resource_type)
            ->where('resource_id', $case->resource_id)
            ->latest('id')
            ->first();

        $startCodeAudit = [
            'verified' => (bool) ($startVerification?->verified_at !== null),
            'verified_at' => $startVerification?->verified_at?->toISOString(),
            'status' => $startVerification?->status,
        ];

        // Safe Lifecycle events audit (descriptions, event types, timestamps)
        $lifecycleEvents = ServiceLifecycleEvent::where('resource_type', $case->resource_type)
            ->where('resource_id', $case->resource_id)
            ->orderBy('created_at', 'asc')
            ->get()
            ->map(function ($ev) {
                return [
                    'event_type' => $ev->event_type,
                    'actor_user_id' => $ev->actor_user_id,
                    'created_at' => $ev->created_at?->toISOString(),
                ];
            });

        // Safe Services list
        $services = [];
        if ($case->resource_type === LocationShareGrant::RESOURCE_INSTANT_REQUEST && $resource) {
            $services = $resource->services->map(fn($s) => [
                'id' => $s->id,
                'name' => $s->name,
            ])->toArray();
        } elseif ($case->resource_type === LocationShareGrant::RESOURCE_SCHEDULED_APPOINTMENT && $resource) {
            $services = $resource->services->map(fn($s) => [
                'id' => $s->id,
                'name' => $s->name,
                'price' => (float) ($s->pivot->price_snapshot ?? 0),
            ])->toArray();
        }

        return [
            'id' => $case->id,
            'resource_type' => $case->resource_type,
            'resource_id' => $case->resource_id,
            'status' => $case->status,
            'payment_method' => $case->payment_method,
            'customer' => [
                'id' => $case->customer?->id,
                'name' => $case->customer?->name,
                'email' => $case->customer?->email,
                'phone' => $case->customer?->phone,
            ],
            'provider' => [
                'id' => $case->provider?->id,
                'name' => $case->provider?->name,
                'business_name' => $case->provider?->providerProfile?->business_name ?: $case->provider?->name,
                'email' => $case->provider?->email,
                'phone' => $case->provider?->phone,
            ],
            'services' => $services,
            'customer_reason' => $case->customer_reason,
            'customer_note' => \App\Support\CustomerNote::forDisplay($case->customer_note),
            'admin_resolution' => $case->admin_resolution,
            'admin_note' => $case->admin_note,
            'opened_at' => $case->opened_at?->toISOString(),
            'review_started_at' => $case->review_started_at?->toISOString(),
            'resolved_at' => $case->resolved_at?->toISOString(),
            'reviewed_by' => $case->reviewedByAdmin ? [
                'id' => $case->reviewedByAdmin->id,
                'name' => $case->reviewedByAdmin->name,
            ] : null,
            'lifecycle_status' => $resource?->status,
            'service_started_at' => $resource?->service_started_at?->toISOString(),
            'provider_completed_at' => $resource?->provider_completed_at?->toISOString(),
            'disputed_at' => $resource?->disputed_at?->toISOString(),
            'financial' => [
                'payment_method' => $case->payment_method,
                'gross_amount' => $financialSummary['gross_amount'] ?? null,
                'commission_amount' => $financialSummary['commission_amount'] ?? null,
                'provider_net_amount' => $financialSummary['provider_net_amount'] ?? null,
                'status' => $financialSummary['commission_status'] ?? $financialSummary['payment_status'] ?? null,
            ],
            'refunds' => PaymentRefund::where(function ($q) use ($case, $resource) {
                $q->where('dispute_case_id', $case->id);
                $servicePayment = ServicePayment::where('resource_type', $case->resource_type)
                    ->where('resource_id', $case->resource_id)
                    ->first();
                if ($servicePayment) {
                    $q->orWhere('service_payment_id', $servicePayment->id);
                }
            })->orderByDesc('id')->get()->map(function ($r) {
                return [
                    'id' => $r->id,
                    'status' => $r->status,
                    'refund_amount' => $r->refund_amount,
                    'reference_no' => $r->reference_no,
                    'failure_reason' => $r->failure_reason,
                    'created_at' => $r->created_at?->toISOString(),
                    'completed_at' => $r->completed_at?->toISOString(),
                    'can_retry' => in_array($r->status, [PaymentRefund::STATUS_FAILED, PaymentRefund::STATUS_MANUAL_REVIEW], true),
                ];
            })->values()->toArray(),
            'start_code_audit' => $startCodeAudit,
            'lifecycle_events' => $lifecycleEvents,
        ];
    }

    /**
     * Start review on an open dispute case (OPEN -> UNDER_REVIEW).
     */
    public function startReview(int $caseId, User $admin): DisputeCase
    {
        return DB::transaction(function () use ($caseId, $admin) {
            $case = DisputeCase::where('id', $caseId)->lockForUpdate()->first();
            if (!$case) {
                throw new NotFoundHttpException("Dispute case #{$caseId} not found");
            }

            if ($case->isResolved()) {
                throw new UnprocessableEntityHttpException("Çözümlenmiş bir uyuşmazlık tekrar incelemeye alınamaz.");
            }

            // Idempotent: already under review
            if ($case->status === DisputeCase::STATUS_UNDER_REVIEW) {
                return $case;
            }

            $case->status = DisputeCase::STATUS_UNDER_REVIEW;
            $case->review_started_at = now();
            $case->reviewed_by_admin_user_id = $admin->id;
            $case->save();

            // Log admin audit action
            $financeStatus = ($case->payment_method === 'CASH')
                ? CommissionReservation::STATUS_HELD_DISPUTE
                : ServicePayment::STATUS_DISPUTED;

            AdminLog::create([
                'admin_user_id' => $admin->id,
                'action' => AdminLog::ACTION_DISPUTE_REVIEW_STARTED,
                'target_type' => AdminLog::TARGET_DISPUTE_CASE,
                'target_id' => $case->id,
                'metadata' => [
                    'case_id' => $case->id,
                    'resource_type' => $case->resource_type,
                    'resource_id' => $case->resource_id,
                    'payment_method' => $case->payment_method,
                    'old_finance_status' => $financeStatus,
                    'new_finance_status' => $financeStatus,
                ],
                'created_at' => now(),
            ]);

            return $case;
        });
    }

    /**
     * Final resolution of dispute case by Admin.
     * Atomically executes financial resolution, updates case state, and logs admin audit.
     *
     * @param string $resolution CUSTOMER_FAVOR or PROVIDER_FAVOR
     */
    public function resolve(int $caseId, User $admin, string $resolution, string $adminNote): DisputeCase
    {
        $cleanNote = trim($adminNote);
        if ($cleanNote === '') {
            throw ValidationException::withMessages([
                'admin_note' => ['Karar gerekçesi ve çözüm açıklaması girilmesi zorunludur.'],
            ]);
        }

        $canonicalResolution = $this->normalizeResolution($resolution);

        return DB::transaction(function () use ($caseId, $admin, $canonicalResolution, $cleanNote) {
            $case = DisputeCase::where('id', $caseId)->lockForUpdate()->first();
            if (!$case) {
                throw new NotFoundHttpException("Dispute case #{$caseId} not found");
            }

            // Idempotency and conflict checks
            if ($case->isResolved()) {
                if ($case->admin_resolution === $canonicalResolution) {
                    return $case; // Idempotent success
                }
                throw new ConflictHttpException("Bu uyuşmazlık zaten farklı bir nihai kararla ({$case->admin_resolution}) çözümlenmiştir.");
            }

            $paymentMethod = strtoupper($case->payment_method);
            $resourceType = $case->resource_type;
            $resourceId = $case->resource_id;

            // Execute Financial State Transition
            $oldFinanceStatus = null;
            $newFinanceStatus = null;

            if ($paymentMethod === 'CASH') {
                $oldFinanceStatus = CommissionReservation::STATUS_HELD_DISPUTE;
                if ($canonicalResolution === DisputeCase::RESOLUTION_CUSTOMER_FAVOR) {
                    $finRes = $this->financialService->resolveCashDisputeForCustomer($resourceType, $resourceId);
                    $newFinanceStatus = CommissionReservation::STATUS_RELEASED;
                } else {
                    $finRes = $this->financialService->resolveCashDisputeForProvider($resourceType, $resourceId);
                    $newFinanceStatus = CommissionReservation::STATUS_CAPTURED;
                }
            } elseif ($paymentMethod === 'ONLINE') {
                $oldFinanceStatus = ServicePayment::STATUS_DISPUTED;
                if ($canonicalResolution === DisputeCase::RESOLUTION_CUSTOMER_FAVOR) {
                    $finRes = $this->financialService->resolveOnlineDisputeForCustomer($resourceType, $resourceId);
                    $newFinanceStatus = ServicePayment::STATUS_REFUND_REQUIRED;
                    try {
                        $refund = $this->refundService->createRefund($finRes, null, $case, $admin);
                        $newFinanceStatus = $finRes->fresh()->status;
                    } catch (UnprocessableEntityHttpException $e) {
                        \Illuminate\Support\Facades\Log::warning('Online dispute refund auto-creation deferred: ' . $e->getMessage(), [
                            'case_id' => $case->id,
                            'payment_id' => $finRes->id,
                        ]);
                    }
                } else {
                    $finRes = $this->financialService->resolveOnlineDisputeForProvider($resourceType, $resourceId);
                    $newFinanceStatus = ServicePayment::STATUS_TRANSFER_PENDING;
                }
            } else {
                throw new LogicException("Unsupported payment method: {$paymentMethod}");
            }

            // Update Dispute Case state
            $newStatus = ($canonicalResolution === DisputeCase::RESOLUTION_CUSTOMER_FAVOR)
                ? DisputeCase::STATUS_RESOLVED_CUSTOMER
                : DisputeCase::STATUS_RESOLVED_PROVIDER;

            $case->status = $newStatus;
            $case->admin_resolution = $canonicalResolution;
            $case->admin_note = $cleanNote;
            $case->resolved_at = now();
            $case->reviewed_by_admin_user_id = $admin->id;
            $case->save();

            // Admin Audit Log
            $action = ($canonicalResolution === DisputeCase::RESOLUTION_CUSTOMER_FAVOR)
                ? AdminLog::ACTION_DISPUTE_RESOLVED_CUSTOMER
                : AdminLog::ACTION_DISPUTE_RESOLVED_PROVIDER;

            AdminLog::create([
                'admin_user_id' => $admin->id,
                'action' => $action,
                'target_type' => AdminLog::TARGET_DISPUTE_CASE,
                'target_id' => $case->id,
                'metadata' => [
                    'case_id' => $case->id,
                    'resource_type' => $resourceType,
                    'resource_id' => $resourceId,
                    'payment_method' => $paymentMethod,
                    'old_finance_status' => $oldFinanceStatus,
                    'new_finance_status' => $newFinanceStatus,
                    'resolution' => $canonicalResolution,
                ],
                'created_at' => now(),
            ]);

            // Notifications to Customer & Provider (admin_note is NOT leaked)
            $isCustomerFavor = ($canonicalResolution === DisputeCase::RESOLUTION_CUSTOMER_FAVOR);
            $notifType = $isCustomerFavor
                ? \App\Models\UserNotification::TYPE_DISPUTE_RESOLVED_CUSTOMER
                : \App\Models\UserNotification::TYPE_DISPUTE_RESOLVED_PROVIDER;

            $customerMsg = $isCustomerFavor
                ? 'Uyuşmazlık incelemesi lehinize karara bağlandı.'
                : 'Uyuşmazlık incelemesi hizmet veren lehine sonuçlandırıldı.';

            $providerMsg = $isCustomerFavor
                ? 'Uyuşmazlık incelemesi müşteri lehine sonuçlandırıldı.'
                : 'Uyuşmazlık incelemesi lehinize sonuçlandırıldı.';

            app(\App\Services\NotificationService::class)->notifyUser(
                $case->customer_user_id,
                $notifType,
                'Uyuşmazlık Karara Bağlandı',
                $customerMsg,
                \App\Models\UserNotification::RESOURCE_DISPUTE_CASE,
                $case->id,
                '/customer',
                [
                    'case_id' => $case->id,
                    'resource_type' => $resourceType,
                    'resource_id' => $resourceId,
                ],
                "DISPUTE_RESOLVED:{$case->id}:CUSTOMER:{$case->customer_user_id}"
            );

            app(\App\Services\NotificationService::class)->notifyUser(
                $case->provider_user_id,
                $notifType,
                'Uyuşmazlık Sonuçlandı',
                $providerMsg,
                \App\Models\UserNotification::RESOURCE_DISPUTE_CASE,
                $case->id,
                '/barber',
                [
                    'case_id' => $case->id,
                    'resource_type' => $resourceType,
                    'resource_id' => $resourceId,
                ],
                "DISPUTE_RESOLVED:{$case->id}:PROVIDER:{$case->provider_user_id}"
            );

            return $case;
        });
    }

    /**
     * Get safe, minimal dispute summary for Customer / Provider resource views.
     * Admin internal notes and private audit details are NOT leaked.
     */
    public function getDisputeSummaryForResource(string $resourceType, int $resourceId): ?array
    {
        $case = DisputeCase::where('resource_type', $resourceType)
            ->where('resource_id', $resourceId)
            ->first();

        if (!$case) {
            return null;
        }

        $label = match ($case->status) {
            DisputeCase::STATUS_OPEN => 'Açık Uyuşmazlık',
            DisputeCase::STATUS_UNDER_REVIEW => 'İnceleniyor',
            DisputeCase::STATUS_RESOLVED_CUSTOMER => 'Müşteri Lehine Sonuçlandı',
            DisputeCase::STATUS_RESOLVED_PROVIDER => 'Hizmet Veren Lehine Sonuçlandı',
            default => $case->status,
        };

        return [
            'case_id' => $case->id,
            'status' => $case->status,
            'status_label' => $label,
            'resolution' => $case->admin_resolution,
            'opened_at' => $case->opened_at?->toISOString(),
            'resolved_at' => $case->resolved_at?->toISOString(),
        ];
    }

    /**
     * Format a safe summary projection of a dispute case.
     */
    private function formatCaseSummary(DisputeCase $case): array
    {
        $fin = $this->financialService->getResourceFinanceSummary(
            $case->resource_type,
            $case->resource_id,
            $case->payment_method
        );

        return [
            'id' => $case->id,
            'resource_type' => $case->resource_type,
            'resource_id' => $case->resource_id,
            'customer' => [
                'id' => $case->customer?->id,
                'name' => $case->customer?->name,
                'email' => $case->customer?->email,
                'phone' => $case->customer?->phone,
            ],
            'provider' => [
                'id' => $case->provider?->id,
                'name' => $case->provider?->name,
                'business_name' => $case->provider?->providerProfile?->business_name ?: $case->provider?->name,
                'email' => $case->provider?->email,
                'phone' => $case->provider?->phone,
            ],
            'payment_method' => $case->payment_method,
            'gross_amount' => $fin['gross_amount'] ?? null,
            'commission_amount' => $fin['commission_amount'] ?? null,
            'customer_reason' => $case->customer_reason,
            'status' => $case->status,
            'admin_resolution' => $case->admin_resolution,
            'opened_at' => $case->opened_at?->toISOString(),
            'resolved_at' => $case->resolved_at?->toISOString(),
        ];
    }

    /**
     * Normalize resolution string.
     */
    private function normalizeResolution(string $resolution): string
    {
        $upper = strtoupper(trim($resolution));
        if ($upper === DisputeCase::RESOLUTION_CUSTOMER_FAVOR || $upper === DisputeCase::STATUS_RESOLVED_CUSTOMER) {
            return DisputeCase::RESOLUTION_CUSTOMER_FAVOR;
        }

        if ($upper === DisputeCase::RESOLUTION_PROVIDER_FAVOR || $upper === DisputeCase::STATUS_RESOLVED_PROVIDER) {
            return DisputeCase::RESOLUTION_PROVIDER_FAVOR;
        }

        throw ValidationException::withMessages([
            'resolution' => ["Geçersiz karar: {$resolution}. Yalnızca CUSTOMER_FAVOR veya PROVIDER_FAVOR kabul edilir."],
        ]);
    }
}
