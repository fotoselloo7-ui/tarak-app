<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class AppointmentResource extends JsonResource
{
    /**
     * Transform the resource into an array for Customer.
     */
    public function toArray(Request $request): array
    {
        $providerUser = $this->provider;
        $providerProfile = $providerUser?->providerProfile;

        return [
            'id' => (string) $this->id,
            'public_id' => 'APT' . str_pad((string)$this->id, 6, '0', STR_PAD_LEFT),
            'customer_user_id' => (string) $this->customer_user_id,
            'provider_user_id' => (string) $this->provider_user_id,
            'provider' => $providerProfile ? [
                'id' => (string) $providerProfile->id,
                'user_id' => (string) $providerUser->id,
                'business_name' => $providerProfile->business_name ?: $providerUser->name,
                'name' => $providerUser->name,
                'phone' => $providerUser->phone,
                'avatar_url' => $providerUser->avatar_url,
                'district' => $providerProfile->district,
                'city' => $providerProfile->city,
                'is_verified' => $providerProfile->isVerified(),
            ] : null,
            'customer_address_id' => $this->customer_address_id ? (string) $this->customer_address_id : null,
            'address' => $this->address ? [
                'id' => (string) $this->address->id,
                'title' => $this->address->title,
                'province' => $this->address->province,
                'district' => $this->address->district,
                'neighborhood' => $this->address->neighborhood,
                'street' => $this->address->street,
                'building_no' => $this->address->building_no,
                'apartment_no' => $this->address->apartment_no,
                'directions' => $this->address->directions,
            ] : null,
            'status' => $this->status,
            // Lets clients hide the review CTA once this customer has reviewed the appointment.
            'has_review' => $this->status === \App\Models\Appointment::STATUS_COMPLETED
                && \App\Models\ProviderReview::where('appointment_id', $this->id)
                    ->where('customer_user_id', $this->customer_user_id)
                    ->exists(),
            'appointment_date' => $this->appointment_date ? $this->appointment_date->format('Y-m-d') : null,
            'start_time' => substr($this->start_time, 0, 5),
            'end_time' => substr($this->end_time, 0, 5),
            'payment_method' => $this->payment_method,
            'total_price' => (float) $this->total_price,
            'total_duration_minutes' => (int) $this->total_duration_minutes,
            'provider_package_id' => $this->provider_package_id,
            'offering' => $this->offering_snapshot,
            'approx_location' => trim(($this->approx_district ? $this->approx_district . ', ' : '') . ($this->approx_province ?: '')),
            'approx_province' => $this->approx_province,
            'approx_district' => $this->approx_district,
            'approx_neighborhood' => $this->approx_neighborhood,
            'customer_note' => \App\Support\CustomerNote::forDisplay($this->customer_note),
            'requested_at' => $this->requested_at?->toISOString(),
            'confirmed_at' => $this->confirmed_at?->toISOString(),
            'rejected_at' => $this->rejected_at?->toISOString(),
            'cancelled_at' => $this->cancelled_at?->toISOString(),
            'rejection_reason' => \App\Support\CustomerNote::forDisplay($this->rejection_reason),
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
            // Backend source-of-truth for start code / location share / service start gates
            // (CASH: commission RESERVED/CAPTURED, ONLINE: payment HELD/TRANSFER_PENDING/SETTLED)
            'is_financially_ready' => in_array($this->status, ['CONFIRMED', 'IN_PROGRESS', 'AWAITING_CUSTOMER_CONFIRMATION', 'COMPLETED'], true)
                && app(\App\Services\FinancialService::class)->isResourceFinanciallyReady(
                    \App\Models\LocationShareGrant::RESOURCE_SCHEDULED_APPOINTMENT,
                    (int) $this->id,
                    (string) ($this->payment_method ?? 'CASH')
                ),
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
            'services' => $this->services->map(function ($service) {
                return [
                    'id' => (string) $service->id,
                    'name' => $service->name,
                    'price_snapshot' => (float) $service->pivot->price_snapshot,
                    'duration_minutes_snapshot' => (int) $service->pivot->duration_minutes_snapshot,
                ];
            }),
            'alternative_slots' => $this->alternativeSlots->map(function ($slot) {
                return [
                    'id' => (string) $slot->id,
                    'date' => $slot->date ? $slot->date->format('Y-m-d') : null,
                    'start_time' => substr($slot->start_time, 0, 5),
                    'end_time' => substr($slot->end_time, 0, 5),
                    'status' => $slot->status,
                ];
            }),
            'created_at' => $this->created_at?->toISOString(),
            'updated_at' => $this->updated_at?->toISOString(),
        ];
    }
}
