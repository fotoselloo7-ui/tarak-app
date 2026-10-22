<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ProviderMarketplaceRequestResource extends JsonResource
{
    /**
     * Sanitized Provider Marketplace projection of an open instant ServiceRequest.
     * Guaranteed privacy: No exact customer address, no private coordinates, no customer phone or email.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'mode' => $this->mode,
            'status' => $this->status,
            'category_id' => $this->category_id,
            'category_name' => $this->category?->name,
            'services' => $this->services->map(function ($s) {
                return [
                    'id' => $s->id,
                    'name' => $s->name,
                    'duration_minutes' => $s->duration_minutes,
                    'icon_class' => $s->icon_class,
                ];
            }),
            'is_direct' => $this->target_provider_user_id !== null,
            'snapshot_price' => $this->snapshot_price !== null ? (float) $this->snapshot_price : null,
            'snapshot_duration_minutes' => $this->snapshot_duration_minutes,
            'offering' => $this->offering_snapshot ? [
                'type' => $this->offering_snapshot['type'] ?? null,
                'title' => $this->offering_snapshot['title'] ?? null,
                'description' => $this->offering_snapshot['description'] ?? null,
                'price' => $this->offering_snapshot['price'] ?? null,
                'duration_minutes' => $this->offering_snapshot['duration_minutes'] ?? null,
                'items' => $this->offering_snapshot['items'] ?? [],
            ] : null,
            'location_text' => $this->location_text ?:($this->approx_district ? "{$this->approx_district}, {$this->approx_province}" : 'Bölge Belirtilmedi'),
            'approx_province' => $this->approx_province,
            'approx_district' => $this->approx_district,
            'approx_neighborhood' => $this->approx_neighborhood,
            'customer_note' => \App\Support\CustomerNote::forDisplay($this->customer_note),
            'payment_method' => $this->payment_method,
            'duration_preference' => $this->duration_preference,
            'urgency' => $this->urgency,
            'created_at' => $this->created_at?->toISOString(),
            'distance_km' => $this->distance_km !== null ? (float) $this->distance_km : null,
            'is_approximate_match' => (bool) ($this->is_approximate_match ?? false),
            'assigned_provider_user_id' => $this->assigned_provider_user_id,
            'assigned_at' => $this->assigned_at?->toISOString(),
            'service_started_at' => $this->service_started_at?->toISOString(),
            'provider_completed_at' => $this->provider_completed_at?->toISOString(),
            'completed_at' => $this->completed_at?->toISOString(),
            'disputed_at' => $this->disputed_at?->toISOString(),
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
                return [
                    'id' => $pay->id,
                    'status' => $pay->status,
                    'gross_amount' => (float) $pay->gross_amount,
                    'held_at' => $pay->held_at?->toISOString(),
                    'transfer_pending_at' => $pay->transfer_pending_at?->toISOString(),
                ];
            }),
            'my_offer' => $this->when($request->user() && $request->user()->role === 'PROVIDER', function () use ($request) {
                $offer = $this->offers()->where('provider_user_id', $request->user()->id)->first();
                if (!$offer) {
                    return null;
                }
                return [
                    'id' => $offer->id,
                    'service_request_id' => $offer->service_request_id,
                    'provider_user_id' => $offer->provider_user_id,
                    'price' => (float) $offer->price,
                    'duration_minutes' => (int) $offer->duration_minutes,
                    'estimated_arrival_min' => $offer->estimated_arrival_min !== null ? (int) $offer->estimated_arrival_min : null,
                    'payment_preference' => $offer->payment_preference,
                    'message' => $offer->message,
                    'status' => $offer->status,
                    'accepted_at' => $offer->accepted_at?->toISOString(),
                    'rejected_at' => $offer->rejected_at?->toISOString(),
                    'created_at' => $offer->created_at?->toISOString(),
                ];
            }),
        ];
    }
}
