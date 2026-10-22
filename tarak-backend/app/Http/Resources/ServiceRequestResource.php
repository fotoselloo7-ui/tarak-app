<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ServiceRequestResource extends JsonResource
{
    /**
     * Customer-facing projection of a ServiceRequest.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'customer_user_id' => $this->customer_user_id,
            'category_id' => $this->category_id,
            'category' => $this->whenLoaded('category', function () {
                return [
                    'id' => $this->category->id,
                    'name' => $this->category->name,
                    'slug' => $this->category->slug,
                ];
            }),
            'mode' => $this->mode,
            'status' => $this->status,
            // Lets clients hide the review CTA once this customer has reviewed the job.
            'has_review' => $this->status === \App\Models\ServiceRequest::STATUS_COMPLETED
                && \App\Models\ProviderReview::where('service_request_id', $this->id)
                    ->where('customer_user_id', $this->customer_user_id)
                    ->exists(),
            'payment_method' => $this->payment_method,
            'customer_address_id' => $this->customer_address_id,
            'location_text' => $this->location_text,
            'approx_province' => $this->approx_province,
            'approx_district' => $this->approx_district,
            'approx_neighborhood' => $this->approx_neighborhood,
            'customer_note' => \App\Support\CustomerNote::forDisplay($this->customer_note),
            'duration_preference' => $this->duration_preference,
            'urgency' => $this->urgency,
            'services' => $this->services->map(function ($s) {
                return [
                    'id' => $s->id,
                    'name' => $s->name,
                    'slug' => $s->slug,
                    'duration_minutes' => $s->duration_minutes,
                    'icon_class' => $s->icon_class,
                ];
            }),
            'is_direct' => $this->target_provider_user_id !== null,
            'target_provider_user_id' => $this->target_provider_user_id,
            'target_provider' => $this->when($this->target_provider_user_id !== null, function () {
                $target = $this->targetProvider;
                $prof = $target?->providerProfile;
                return $target ? [
                    'id' => $target->id,
                    'business_name' => $prof?->business_name ?: $target->name,
                    'avatar_url' => $target->avatar_url,
                    'provider_type' => $prof?->provider_type,
                    'is_verified' => $prof?->isVerified() ?? false,
                ] : null;
            }),
            'provider_service_id' => $this->provider_service_id,
            'provider_package_id' => $this->provider_package_id,
            'snapshot_price' => $this->snapshot_price !== null ? (float) $this->snapshot_price : null,
            'snapshot_duration_minutes' => $this->snapshot_duration_minutes,
            'offering' => $this->offering_snapshot,
            'assigned_provider_user_id' => $this->assigned_provider_user_id,
            'assigned_provider' => $this->when($this->assigned_provider_user_id && $this->assignedProvider, function () {
                $prof = $this->assignedProvider->providerProfile;
                return [
                    'id' => $this->assignedProvider->id,
                    'name' => $this->assignedProvider->name,
                    'business_name' => $prof?->business_name ?: $this->assignedProvider->name,
                    'provider_type' => $prof?->provider_type,
                    'phone' => $this->assignedProvider->phone,
                    'is_verified' => $prof?->isVerified() ?? false,
                ];
            }),
            'accepted_offer_id' => $this->accepted_offer_id,
            'offers_count' => $this->offers_count ?? $this->offers()->count(),
            'assigned_at' => $this->assigned_at?->toISOString(),
            'cancelled_at' => $this->cancelled_at?->toISOString(),
            'service_started_at' => $this->service_started_at?->toISOString(),
            'provider_completed_at' => $this->provider_completed_at?->toISOString(),
            'completed_at' => $this->completed_at?->toISOString(),
            'disputed_at' => $this->disputed_at?->toISOString(),
            'dispute_reason' => $this->dispute_reason,
            'dispute_note' => \App\Support\CustomerNote::forDisplay($this->dispute_note),
            'dispute_summary' => $this->disputeCase ? [
                'case_id' => $this->disputeCase->id,
                'status' => $this->disputeCase->status,
                'status_label' => match ($this->disputeCase->status) {
                    'OPEN' => 'Açık Uyuşmazlık',
                    'UNDER_REVIEW' => 'İnceleniyor',
                    'RESOLVED_CUSTOMER' => 'Müşteri Lehine Sonuçlandı',
                    'RESOLVED_PROVIDER' => 'Hizmet Veren Lehine Sonuçlandı',
                    default => $this->disputeCase->status,
                },
                'resolution' => $this->disputeCase->admin_resolution,
                'opened_at' => $this->disputeCase->opened_at?->toISOString(),
                'resolved_at' => $this->disputeCase->resolved_at?->toISOString(),
            ] : null,
            'payment_summary' => $this->when($this->payment_method === 'ONLINE', function () {
                $pay = $this->servicePayment;
                if (!$pay) {
                    return null;
                }
                $refundSummary = app(\App\Services\PaytrRefundService::class)->getCustomerRefundSummary($pay);
                return [
                    'id' => $pay->id,
                    'status' => $pay->status,
                    'gross_amount' => (float) $pay->gross_amount,
                    'held_at' => $pay->held_at?->toISOString(),
                    'transfer_pending_at' => $pay->transfer_pending_at?->toISOString(),
                    'refund_summary' => $refundSummary,
                ];
            }),
            'created_at' => $this->created_at?->toISOString(),
            'updated_at' => $this->updated_at?->toISOString(),
        ];
    }
}
