<?php

namespace App\Services;

use App\Models\LocationShareGrant;
use App\Models\ServiceOffer;
use App\Models\ServiceRequest;

class InstantAssignmentService
{
    public function __construct(
        protected FinancialService $financialService,
        protected ServiceLifecycleService $lifecycleService,
    ) {}

    /**
     * Assign an OPEN request to the provider of the given PENDING offer.
     * Caller must hold row locks on both records inside a DB transaction.
     */
    public function assign(ServiceRequest $serviceRequest, ServiceOffer $offer): void
    {
        $paymentMethod = strtoupper($serviceRequest->payment_method ?? 'CASH');

        if ($paymentMethod === 'CASH') {
            $this->financialService->reserveCashCommission(
                LocationShareGrant::RESOURCE_INSTANT_REQUEST,
                $serviceRequest->id,
                $offer->provider_user_id,
                (string) $offer->price
            );
        } else {
            $this->financialService->createPendingOnlinePayment(
                LocationShareGrant::RESOURCE_INSTANT_REQUEST,
                $serviceRequest->id,
                $serviceRequest->customer_user_id,
                $offer->provider_user_id,
                (string) $offer->price
            );
        }

        $serviceRequest->status = ServiceRequest::STATUS_ASSIGNED;
        $serviceRequest->assigned_provider_user_id = $offer->provider_user_id;
        $serviceRequest->accepted_offer_id = $offer->id;
        $serviceRequest->assigned_at = now();
        $serviceRequest->save();

        $this->lifecycleService->ensureStartVerificationForResource(
            LocationShareGrant::RESOURCE_INSTANT_REQUEST,
            $serviceRequest->id,
            $serviceRequest->customer_user_id,
            $serviceRequest->assigned_provider_user_id
        );

        $offer->status = ServiceOffer::STATUS_ACCEPTED;
        $offer->accepted_at = now();
        $offer->save();

        ServiceOffer::where('service_request_id', $serviceRequest->id)
            ->where('id', '!=', $offer->id)
            ->where('status', ServiceOffer::STATUS_PENDING)
            ->update([
                'status' => ServiceOffer::STATUS_REJECTED,
                'rejected_at' => now(),
            ]);
    }
}
