<?php

namespace App\Services;

use App\Models\Appointment;
use App\Models\LocationShareGrant;
use App\Models\ServiceLifecycleEvent;
use App\Models\ServiceRequest;
use App\Models\ServiceStartVerification;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;
use Symfony\Component\HttpKernel\Exception\UnprocessableEntityHttpException;

class ServiceLifecycleService
{
    public function __construct(
        protected LocationGrantService $locationGrantService
    ) {}

    public function getTtlMinutes(): int
    {
        return (int) config('services.service_start.ttl_minutes', 1440);
    }

    public function getMaxAttempts(): int
    {
        return (int) config('services.service_start.max_attempts', 5);
    }

    public function getLockMinutes(): int
    {
        return (int) config('services.service_start.lock_minutes', 5);
    }

    /**
     * Ensure or create an active 4-digit start verification for the resource.
     * Cryptographically secure random generation (random_int).
     * Plaintext code is never stored directly in the database.
     */
    public function ensureStartVerificationForResource(
        string $resourceType,
        int $resourceId,
        int $customerUserId,
        int $providerUserId
    ): ServiceStartVerification {
        return DB::transaction(function () use ($resourceType, $resourceId, $customerUserId, $providerUserId) {
            // Lock and check for existing active verification
            $existing = ServiceStartVerification::where('resource_type', $resourceType)
                ->where('resource_id', $resourceId)
                ->where('status', ServiceStartVerification::STATUS_ACTIVE)
                ->lockForUpdate()
                ->first();

            if ($existing) {
                if (!$existing->isExpired()) {
                    return $existing;
                }
                // Mark expired if TTL passed
                $existing->status = ServiceStartVerification::STATUS_EXPIRED;
                $existing->save();
            }

            // Generate cryptographically secure 4-digit code (1000 - 9999)
            $code = (string) random_int(1000, 9999);
            $codeHash = Hash::make($code);
            $now = Carbon::now();
            $expiresAt = $now->copy()->addMinutes($this->getTtlMinutes());

            $verification = new ServiceStartVerification();
            $verification->resource_type = $resourceType;
            $verification->resource_id = $resourceId;
            $verification->customer_user_id = $customerUserId;
            $verification->provider_user_id = $providerUserId;
            $verification->code_hash = $codeHash;
            // encrypted_code uses Laravel's 'encrypted' cast on model
            $verification->encrypted_code = $code;
            $verification->status = ServiceStartVerification::STATUS_ACTIVE;
            $verification->failed_attempts = 0;
            $verification->generated_at = $now;
            $verification->expires_at = $expiresAt;
            $verification->save();

            $this->logEvent(
                $resourceType,
                $resourceId,
                ServiceLifecycleEvent::EVENT_START_CODE_GENERATED,
                $customerUserId,
                ['expires_at' => $expiresAt->toISOString()]
            );

            return $verification;
        });
    }

    /**
     * Customer retrieves the 4-digit start verification code.
     * Only the customer owning the resource can access this.
     */
    public function getStartCodeForCustomer(
        User $customer,
        string $resourceType,
        int $resourceId
    ): array {
        $resource = $this->validateAndGetResourceForCustomer($customer, $resourceType, $resourceId);

        // Financial Readiness Gate: CASH requires RESERVED, ONLINE requires HELD
        app(\App\Services\FinancialService::class)->ensureFinanciallyReadyForService(
            $resourceType,
            $resourceId,
            $resource->payment_method ?? 'CASH'
        );

        // Idempotently ensure verification exists if in valid pre-start state
        if ($resourceType === LocationShareGrant::RESOURCE_INSTANT_REQUEST) {
            if ($resource->status === ServiceRequest::STATUS_ASSIGNED) {
                $this->ensureStartVerificationForResource(
                    $resourceType,
                    $resourceId,
                    $resource->customer_user_id,
                    $resource->assigned_provider_user_id
                );
            }
        } elseif ($resourceType === LocationShareGrant::RESOURCE_SCHEDULED_APPOINTMENT) {
            if ($resource->status === Appointment::STATUS_CONFIRMED) {
                $this->ensureStartVerificationForResource(
                    $resourceType,
                    $resourceId,
                    $resource->customer_user_id,
                    $resource->provider_user_id
                );
            }
        }

        $verification = ServiceStartVerification::where('resource_type', $resourceType)
            ->where('resource_id', $resourceId)
            ->where('customer_user_id', $customer->id)
            ->latest('id')
            ->first();

        if (!$verification) {
            throw new NotFoundHttpException('Bu hizmet için başlangıç kodu bulunamadı.');
        }

        // Auto-expire if expired
        if ($verification->status === ServiceStartVerification::STATUS_ACTIVE && $verification->isExpired()) {
            $verification->status = ServiceStartVerification::STATUS_EXPIRED;
            $verification->save();
        }

        // Only return decrypted code if still ACTIVE and pre-service
        $code = null;
        if ($verification->status === ServiceStartVerification::STATUS_ACTIVE && !$verification->isExpired()) {
            $code = $verification->encrypted_code;
        }

        return [
            'resource_type' => $resourceType,
            'resource_id' => $resourceId,
            'code' => $code,
            'status' => $verification->status,
            'is_expired' => $verification->isExpired(),
            'generated_at' => $verification->generated_at?->toISOString(),
            'expires_at' => $verification->expires_at?->toISOString(),
        ];
    }

    /**
     * Customer regenerates start code if expired.
     * Can only be called while resource is still ASSIGNED or CONFIRMED.
     */
    public function regenerateStartCodeForCustomer(
        User $customer,
        string $resourceType,
        int $resourceId
    ): array {
        $resource = $this->validateAndGetResourceForCustomer($customer, $resourceType, $resourceId);

        // Financial Readiness Gate
        app(\App\Services\FinancialService::class)->ensureFinanciallyReadyForService(
            $resourceType,
            $resourceId,
            $resource->payment_method ?? 'CASH'
        );

        // Guard: Allowed only in pre-service state
        $isPreService = false;
        $providerUserId = null;

        if ($resourceType === LocationShareGrant::RESOURCE_INSTANT_REQUEST) {
            $isPreService = ($resource->status === ServiceRequest::STATUS_ASSIGNED);
            $providerUserId = $resource->assigned_provider_user_id;
        } elseif ($resourceType === LocationShareGrant::RESOURCE_SCHEDULED_APPOINTMENT) {
            $isPreService = ($resource->status === Appointment::STATUS_CONFIRMED);
            $providerUserId = $resource->provider_user_id;
        }

        if (!$isPreService) {
            throw new UnprocessableEntityHttpException(
                "Bu aşamada ({$resource->status}) yeni başlangıç kodu üretilemez."
            );
        }

        return DB::transaction(function () use ($resourceType, $resourceId, $customer, $providerUserId) {
            // Expire all previous active verifications
            ServiceStartVerification::where('resource_type', $resourceType)
                ->where('resource_id', $resourceId)
                ->where('status', ServiceStartVerification::STATUS_ACTIVE)
                ->update(['status' => ServiceStartVerification::STATUS_EXPIRED]);

            $newVerification = $this->ensureStartVerificationForResource(
                $resourceType,
                $resourceId,
                $customer->id,
                $providerUserId
            );

            return [
                'resource_type' => $resourceType,
                'resource_id' => $resourceId,
                'code' => $newVerification->encrypted_code,
                'status' => $newVerification->status,
                'is_expired' => false,
                'generated_at' => $newVerification->generated_at?->toISOString(),
                'expires_at' => $newVerification->expires_at?->toISOString(),
            ];
        });
    }

    /**
     * Provider verifies 4-digit code and starts the service (IN_PROGRESS).
     * Enforces brute-force lockout (5 failed attempts -> 5 min lock).
     * Never exposes raw code or hash in response.
     */
    public function verifyStartCodeForProvider(
        User $provider,
        string $resourceType,
        int $resourceId,
        string $inputCode
    ): array {
        $cleanCode = trim($inputCode);
        if (strlen($cleanCode) !== 4 || !ctype_digit($cleanCode)) {
            throw ValidationException::withMessages([
                'code' => ['Lütfen 4 haneli sayısal doğrulama kodunu giriniz.'],
            ]);
        }

        $resource = $this->validateAndGetResourceForProvider($provider, $resourceType, $resourceId);

        // Financial Readiness Gate: CASH requires RESERVED, ONLINE requires HELD
        app(\App\Services\FinancialService::class)->ensureFinanciallyReadyForService(
            $resourceType,
            $resourceId,
            $resource->payment_method ?? 'CASH'
        );

        // Idempotency check: If already IN_PROGRESS or COMPLETED
        if ($resource->status === 'IN_PROGRESS') {
            return [
                'success' => true,
                'message' => 'Hizmet zaten başlatılmış durumda.',
                'status' => 'IN_PROGRESS',
                'service_started_at' => $resource->service_started_at?->toISOString(),
            ];
        }

        // Status guard: ONLY ASSIGNED (instant) or CONFIRMED (appointment) can be verified
        if ($resourceType === LocationShareGrant::RESOURCE_INSTANT_REQUEST && $resource->status !== ServiceRequest::STATUS_ASSIGNED) {
            throw new UnprocessableEntityHttpException(
                "Yalnızca teklifi kabul edilmiş (ASSIGNED) hizmetler başlatılabilir. Mevcut durum: {$resource->status}"
            );
        }

        if ($resourceType === LocationShareGrant::RESOURCE_SCHEDULED_APPOINTMENT && $resource->status !== Appointment::STATUS_CONFIRMED) {
            throw new UnprocessableEntityHttpException(
                "Yalnızca onaylanmış (CONFIRMED) randevular başlatılabilir. Mevcut durum: {$resource->status}"
            );
        }

        $verification = ServiceStartVerification::where('resource_type', $resourceType)
            ->where('resource_id', $resourceId)
            ->where('provider_user_id', $provider->id)
            ->where('status', ServiceStartVerification::STATUS_ACTIVE)
            ->first();

        if (!$verification) {
            throw new UnprocessableEntityHttpException('Bu hizmet için aktif bir başlangıç kodu bulunamadı.');
        }

        // 1. Lock check: If currently locked, REJECT even if the code would have been correct!
        if ($verification->isLocked()) {
            $remSeconds = $verification->getRemainingLockSeconds();
            $remMinutes = (int) ceil($remSeconds / 60);

            $this->logEvent(
                $resourceType,
                $resourceId,
                ServiceLifecycleEvent::EVENT_START_CODE_LOCKED,
                $provider->id,
                ['lock_remaining_seconds' => $remSeconds]
            );

            throw new UnprocessableEntityHttpException(
                "Çok fazla hatalı deneme yapıldı. Lütfen {$remMinutes} dakika sonra tekrar deneyin."
            );
        }

        // 2. Expiry check
        if ($verification->isExpired()) {
            $verification->status = ServiceStartVerification::STATUS_EXPIRED;
            $verification->save();

            throw new UnprocessableEntityHttpException('Hizmet başlangıç kodunun süresi dolmuş. Müşteriden kodu yenilemesini isteyiniz.');
        }

        // 3. Verify Code Hash
        if (!Hash::check($cleanCode, $verification->code_hash)) {
            $verification->failed_attempts += 1;

            if ($verification->failed_attempts >= $this->getMaxAttempts()) {
                $lockUntil = Carbon::now()->addMinutes($this->getLockMinutes());
                $verification->locked_until = $lockUntil;
                $verification->save();

                $this->logEvent(
                    $resourceType,
                    $resourceId,
                    ServiceLifecycleEvent::EVENT_START_CODE_LOCKED,
                    $provider->id,
                    ['locked_until' => $lockUntil->toISOString()]
                );

                throw new UnprocessableEntityHttpException(
                    "Çok fazla hatalı deneme yapıldı. Güvenliğiniz için işlem {$this->getLockMinutes()} dakika kilitlendi."
                );
            }

            $verification->save();

            $this->logEvent(
                $resourceType,
                $resourceId,
                ServiceLifecycleEvent::EVENT_START_CODE_FAILED,
                $provider->id,
                ['failed_attempts' => $verification->failed_attempts]
            );

            $remaining = $this->getMaxAttempts() - $verification->failed_attempts;
            throw new UnprocessableEntityHttpException(
                "Kod hatalı. Lütfen müşteriden aldığınız kodu kontrol edin. (Kalan deneme hakkı: {$remaining})"
            );
        }

        // 4. Code Correct -> ATOMIC SUCCESS TRANSACTION
        return DB::transaction(function () use ($verification, $resource, $resourceType, $resourceId, $provider) {
            $now = Carbon::now();
            $verification->status = ServiceStartVerification::STATUS_VERIFIED;
            $verification->verified_at = $now;
            $verification->failed_attempts = 0;
            $verification->locked_until = null;
            $verification->save();

            // Transition resource to IN_PROGRESS
            $resource->status = 'IN_PROGRESS';
            $resource->service_started_at = $now;
            $resource->save();

            $this->logEvent(
                $resourceType,
                $resourceId,
                ServiceLifecycleEvent::EVENT_SERVICE_STARTED,
                $provider->id,
                ['started_at' => $now->toISOString()]
            );

            $customerId = $resource->customer_user_id;
            app(\App\Services\NotificationService::class)->notifyUser(
                $customerId,
                \App\Models\UserNotification::TYPE_SERVICE_STARTED,
                'Hizmet Başladı',
                'Hizmet veren 4 haneli başlangıç kodunu doğruladı ve işlem başladı.',
                $resourceType,
                $resourceId,
                '/customer',
                ['resource_type' => $resourceType, 'resource_id' => $resourceId],
                "SERVICE_STARTED:{$resourceType}:{$resourceId}:{$customerId}"
            );

            return [
                'success' => true,
                'message' => 'Hizmet başarıyla başlatıldı.',
                'status' => 'IN_PROGRESS',
                'service_started_at' => $now->toISOString(),
            ];
        });
    }

    /**
     * Provider marks the service as finished.
     * Transitions resource to AWAITING_CUSTOMER_CONFIRMATION (NEVER directly COMPLETED).
     */
    public function providerMarkFinished(
        User $provider,
        string $resourceType,
        int $resourceId
    ): array {
        $resource = $this->validateAndGetResourceForProvider($provider, $resourceType, $resourceId);

        if ($resource->status === 'AWAITING_CUSTOMER_CONFIRMATION') {
            return [
                'success' => true,
                'message' => 'Hizmet tamamlandı bildirimi zaten yapılmış. Müşteri onayı bekleniyor.',
                'status' => 'AWAITING_CUSTOMER_CONFIRMATION',
            ];
        }

        if ($resource->status !== 'IN_PROGRESS') {
            throw new UnprocessableEntityHttpException(
                "Hizmetin tamamlanabilmesi için önce başlatılmış (IN_PROGRESS) olması gerekir. Mevcut durum: {$resource->status}"
            );
        }

        $now = Carbon::now();
        $resource->status = 'AWAITING_CUSTOMER_CONFIRMATION';
        $resource->provider_completed_at = $now;
        $resource->save();

        $this->logEvent(
            $resourceType,
            $resourceId,
            ServiceLifecycleEvent::EVENT_PROVIDER_MARKED_FINISHED,
            $provider->id,
            ['provider_completed_at' => $now->toISOString()]
        );

        $customerId = $resource->customer_user_id;
        app(\App\Services\NotificationService::class)->notifyUser(
            $customerId,
            \App\Models\UserNotification::TYPE_PROVIDER_MARKED_FINISHED,
            'Hizmet Tamamlandı Bildirimi',
            'Hizmet veren işlemin tamamlandığını bildirdi. Lütfen hizmeti onaylayın veya sorun bildirin.',
            $resourceType,
            $resourceId,
            '/customer',
            ['resource_type' => $resourceType, 'resource_id' => $resourceId],
            "PROVIDER_MARKED_FINISHED:{$resourceType}:{$resourceId}:{$customerId}"
        );

        return [
            'success' => true,
            'message' => 'Hizmet tamamlama bildirimi yapıldı. Müşteri onayı bekleniyor.',
            'status' => 'AWAITING_CUSTOMER_CONFIRMATION',
            'provider_completed_at' => $now->toISOString(),
        ];
    }

    /**
     * Customer confirms service completion.
     * Transitions resource to COMPLETED + completed_at.
     * Automatically expires active Location Grants for the resource.
     * Financial settlement intentionally deferred.
     */
    public function customerConfirmCompletion(
        User $customer,
        string $resourceType,
        int $resourceId
    ): array {
        $resource = $this->validateAndGetResourceForCustomer($customer, $resourceType, $resourceId);

        if ($resource->status === 'COMPLETED') {
            return [
                'success' => true,
                'message' => 'Hizmet zaten tamamlanmış durumda.',
                'status' => 'COMPLETED',
                'completed_at' => $resource->completed_at?->toISOString(),
            ];
        }

        if ($resource->status !== 'AWAITING_CUSTOMER_CONFIRMATION') {
            throw new UnprocessableEntityHttpException(
                "Yalnızca hizmet verenin tamamladığını bildirdiği (AWAITING_CUSTOMER_CONFIRMATION) hizmetler onaylanabilir. Mevcut durum: {$resource->status}"
            );
        }

        $now = Carbon::now();
        $resource->status = 'COMPLETED';
        $resource->completed_at = $now;
        $resource->save();

        // Financial Settlement / Commission Capture
        $paymentMethod = strtoupper($resource->payment_method ?? 'CASH');
        $financialService = app(\App\Services\FinancialService::class);
        if ($paymentMethod === 'CASH') {
            $financialService->captureCashCommission($resourceType, $resourceId);
        } else {
            $financialService->completeOnlinePayment($resourceType, $resourceId);
        }

        // Invalidate start verification
        ServiceStartVerification::where('resource_type', $resourceType)
            ->where('resource_id', $resourceId)
            ->where('status', ServiceStartVerification::STATUS_ACTIVE)
            ->update(['status' => ServiceStartVerification::STATUS_EXPIRED]);

        // CRITICAL HOOK: Expire exact location sharing grants immediately
        $this->locationGrantService->expireGrantsForResource($resourceType, $resourceId, 'SERVICE_COMPLETED');

        $this->logEvent(
            $resourceType,
            $resourceId,
            ServiceLifecycleEvent::EVENT_CUSTOMER_CONFIRMED_COMPLETION,
            $customer->id,
            ['completed_at' => $now->toISOString()]
        );

        $providerId = $resource->assigned_provider_user_id ?? $resource->provider_user_id;
        if ($providerId) {
            app(\App\Services\NotificationService::class)->notifyUser(
                $providerId,
                \App\Models\UserNotification::TYPE_SERVICE_COMPLETED,
                'Hizmet Müşteri Tarafından Onaylandı',
                'Müşteri hizmetin başarıyla tamamlandığını onayladı.',
                $resourceType,
                $resourceId,
                '/barber',
                ['resource_type' => $resourceType, 'resource_id' => $resourceId],
                "SERVICE_COMPLETED:{$resourceType}:{$resourceId}:{$providerId}"
            );
        }

        return [
            'success' => true,
            'message' => 'Hizmet tamamlanması başarıyla onaylandı.',
            'status' => 'COMPLETED',
            'completed_at' => $now->toISOString(),
        ];
    }

    /**
     * Customer reports a problem/dispute on an AWAITING_CUSTOMER_CONFIRMATION resource.
     * Transitions resource to DISPUTED + timestamps + reason + note.
     * Automatically expires active Location Grants for the resource.
     */
    public function customerReportProblem(
        User $customer,
        string $resourceType,
        int $resourceId,
        string $reason,
        ?string $note = null
    ): array {
        $cleanReason = trim($reason);
        if (empty($cleanReason)) {
            throw ValidationException::withMessages([
                'reason' => ['Sorun gerekçesi belirtilmesi zorunludur.'],
            ]);
        }

        $resource = $this->validateAndGetResourceForCustomer($customer, $resourceType, $resourceId);

        if ($resource->status === 'DISPUTED') {
            return [
                'success' => true,
                'message' => 'Bu hizmet için sorun bildirimi zaten yapılmış.',
                'status' => 'DISPUTED',
                'disputed_at' => $resource->disputed_at?->toISOString(),
            ];
        }

        if ($resource->status !== 'AWAITING_CUSTOMER_CONFIRMATION') {
            throw new UnprocessableEntityHttpException(
                "Yalnızca tamamlama onayı beklenen (AWAITING_CUSTOMER_CONFIRMATION) hizmetler için sorun bildirilebilir. Mevcut durum: {$resource->status}"
            );
        }

        $now = Carbon::now();
        $cleanNote = $note !== null ? trim($note) : null;

        $resource->status = 'DISPUTED';
        $resource->disputed_at = $now;
        $resource->dispute_reason = $cleanReason;
        $resource->dispute_note = $cleanNote;
        $resource->save();

        // Financial Dispute: Hold cash commission or online payment for admin dispute resolution
        $paymentMethod = strtoupper($resource->payment_method ?? 'CASH');
        $financialService = app(\App\Services\FinancialService::class);
        if ($paymentMethod === 'CASH') {
            $financialService->holdCashCommissionForDispute($resourceType, $resourceId);
        } else {
            $financialService->holdOnlinePaymentForDispute($resourceType, $resourceId);
        }

        // Canonical Dispute Case creation
        $providerUserId = ($resourceType === LocationShareGrant::RESOURCE_INSTANT_REQUEST)
            ? $resource->assigned_provider_user_id
            : $resource->provider_user_id;

        $disputeCase = app(\App\Services\DisputeService::class)->ensureDisputeCaseForResource(
            $resourceType,
            $resourceId,
            $customer->id,
            $providerUserId,
            $paymentMethod,
            $cleanReason,
            $cleanNote
        );

        // Invalidate start verification
        ServiceStartVerification::where('resource_type', $resourceType)
            ->where('resource_id', $resourceId)
            ->where('status', ServiceStartVerification::STATUS_ACTIVE)
            ->update(['status' => ServiceStartVerification::STATUS_EXPIRED]);

        // CRITICAL HOOK: Expire exact location sharing grants immediately
        $this->locationGrantService->expireGrantsForResource($resourceType, $resourceId, 'SERVICE_DISPUTED');

        $this->logEvent(
            $resourceType,
            $resourceId,
            ServiceLifecycleEvent::EVENT_CUSTOMER_REPORTED_PROBLEM,
            $customer->id,
            [
                'reason' => $cleanReason,
                'disputed_at' => $now->toISOString(),
            ]
        );

        if ($providerUserId) {
            app(\App\Services\NotificationService::class)->notifyUser(
                $providerUserId,
                \App\Models\UserNotification::TYPE_DISPUTE_OPENED,
                'Uyuşmazlık Bildirimi',
                'Müşteri bu hizmet ile ilgili sorun bildirdi, inceleme başlatıldı.',
                \App\Models\UserNotification::RESOURCE_DISPUTE_CASE,
                $disputeCase->id,
                '/barber',
                [
                    'case_id' => $disputeCase->id,
                    'resource_type' => $resourceType,
                    'resource_id' => $resourceId,
                ],
                "DISPUTE_OPENED:{$disputeCase->id}:PROVIDER:{$providerUserId}"
            );
        }

        app(\App\Services\NotificationService::class)->notifyAdmins(
            \App\Models\UserNotification::TYPE_DISPUTE_OPENED,
            'Yeni Uyuşmazlık İnceleme Bekliyor',
            'Yeni bir uyuşmazlık inceleme bekliyor.',
            \App\Models\UserNotification::RESOURCE_DISPUTE_CASE,
            $disputeCase->id,
            '/admin',
            [
                'case_id' => $disputeCase->id,
                'resource_type' => $resourceType,
                'resource_id' => $resourceId,
            ],
            "DISPUTE_OPENED:{$disputeCase->id}:ADMIN"
        );

        return [
            'success' => true,
            'message' => 'Sorun bildirimi kaydedildi. Hizmet inceleme sürecine alındı.',
            'status' => 'DISPUTED',
            'disputed_at' => $now->toISOString(),
            'dispute_reason' => $cleanReason,
        ];
    }

    /**
     * Expire verification if resource is cancelled or rejected.
     */
    public function cancelVerificationForResource(string $resourceType, int $resourceId): void
    {
        ServiceStartVerification::where('resource_type', $resourceType)
            ->where('resource_id', $resourceId)
            ->where('status', ServiceStartVerification::STATUS_ACTIVE)
            ->update(['status' => ServiceStartVerification::STATUS_EXPIRED]);
    }

    /**
     * Validate customer resource ownership.
     */
    protected function validateAndGetResourceForCustomer(User $customer, string $resourceType, int $resourceId): mixed
    {
        if ($resourceType === LocationShareGrant::RESOURCE_INSTANT_REQUEST) {
            $req = ServiceRequest::find($resourceId);
            if (!$req) {
                throw new NotFoundHttpException('Hizmet talebi bulunamadı.');
            }
            if ((int) $req->customer_user_id !== (int) $customer->id) {
                throw new AccessDeniedHttpException('Bu hizmet talebine erişim yetkiniz yok.');
            }
            return $req;
        }

        if ($resourceType === LocationShareGrant::RESOURCE_SCHEDULED_APPOINTMENT) {
            $appt = Appointment::find($resourceId);
            if (!$appt) {
                throw new NotFoundHttpException('Randevu bulunamadı.');
            }
            if ((int) $appt->customer_user_id !== (int) $customer->id) {
                throw new AccessDeniedHttpException('Bu randevuya erişim yetkiniz yok.');
            }
            return $appt;
        }

        throw new UnprocessableEntityHttpException('Geçersiz kaynak türü.');
    }

    /**
     * Validate provider resource ownership.
     */
    protected function validateAndGetResourceForProvider(User $provider, string $resourceType, int $resourceId): mixed
    {
        if ($resourceType === LocationShareGrant::RESOURCE_INSTANT_REQUEST) {
            $req = ServiceRequest::find($resourceId);
            if (!$req) {
                throw new NotFoundHttpException('Hizmet talebi bulunamadı.');
            }
            if ((int) $req->assigned_provider_user_id !== (int) $provider->id) {
                throw new AccessDeniedHttpException('Bu hizmet talebine erişim yetkiniz yok.');
            }
            return $req;
        }

        if ($resourceType === LocationShareGrant::RESOURCE_SCHEDULED_APPOINTMENT) {
            $appt = Appointment::find($resourceId);
            if (!$appt) {
                throw new NotFoundHttpException('Randevu bulunamadı.');
            }
            if ((int) $appt->provider_user_id !== (int) $provider->id) {
                throw new AccessDeniedHttpException('Bu randevuya erişim yetkiniz yok.');
            }
            return $appt;
        }

        throw new UnprocessableEntityHttpException('Geçersiz kaynak türü.');
    }

    /**
     * Log canonical lifecycle audit event.
     * NEVER logs raw code or plain text passwords.
     */
    protected function logEvent(
        string $resourceType,
        int $resourceId,
        string $eventType,
        ?int $actorUserId,
        ?array $metadata = null
    ): void {
        ServiceLifecycleEvent::create([
            'resource_type' => $resourceType,
            'resource_id' => $resourceId,
            'event_type' => $eventType,
            'actor_user_id' => $actorUserId,
            'metadata' => $metadata,
            'created_at' => Carbon::now(),
        ]);
    }
}
