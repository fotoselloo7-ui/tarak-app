<?php

namespace App\Services;

use App\Models\ServiceRequest;
use App\Models\User;
use App\Models\UserNotification;

class InstantOpportunityNotifier
{
    public function __construct(private InstantMatchingService $matching, private NotificationService $notifications) {}

    public function notifyEligible(ServiceRequest $request): void
    {
        if ($request->mode !== ServiceRequest::MODE_INSTANT || $request->status !== ServiceRequest::STATUS_OPEN || $request->assigned_provider_user_id !== null) return;
        User::where('role', User::ROLE_PROVIDER)->where('status', 'active')
            ->when($request->target_provider_user_id, fn ($q, $id) => $q->whereKey($id))
            ->whereHas('providerProfile', fn ($q) => $q->where('is_approved', true)
                ->where('identity_status', 'APPROVED')->where('is_online', true)->where('accepts_new_clients', true))
            ->with(['providerProfile.documents', 'providerProfile.services'])
            ->chunkById(100, function ($providers) use ($request) {
                foreach ($providers as $provider) {
                    if (!$this->matching->isProviderEligibleForRequest($provider, $request)['eligible']) continue;
                    $region = implode(', ', array_filter([$request->approx_district, $request->approx_province]));
                    $this->notifications->notifyUser($provider, UserNotification::TYPE_INSTANT_OPPORTUNITY,
                        'Yeni iş fırsatı', $region !== '' ? "{$region} bölgesinde yeni bir hizmet talebi var." : 'Yakınınızda yeni bir hizmet talebi var.',
                        UserNotification::RESOURCE_INSTANT_REQUEST, $request->id, '/barber',
                        [], 'INSTANT_OPPORTUNITY:' . $request->id . ':' . $provider->id);
                }
            });
    }
}
