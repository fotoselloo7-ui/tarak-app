<?php

namespace App\Services;

use App\Models\AdminBroadcast;
use App\Models\PushDevice;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;

/** Segmentation always uses authenticated, server-side account data. */
class AdminBroadcastAudience
{
    public function query(array|AdminBroadcast $broadcast): Builder
    {
        $data = $broadcast instanceof AdminBroadcast ? $broadcast->toArray() : $broadcast;
        $audience = $data['audience'] ?? 'all';
        $kind = $data['kind'] ?? 'system';
        $province = trim((string) ($data['province'] ?? ''));
        $district = trim((string) ($data['district'] ?? ''));

        $query = User::query()->where('status', 'active')
            ->whereIn('role', [User::ROLE_CUSTOMER, User::ROLE_PROVIDER]);

        if ($audience === 'customers') {
            $query->where('role', User::ROLE_CUSTOMER);
        } elseif ($audience === 'providers') {
            $query->where('role', User::ROLE_PROVIDER);
        }

        // Marketing is permitted only after an affirmative preference is stored.
        // The existing application's implicit "true" default DOES NOT qualify as consent.
        if ($kind !== 'system') {
            $query->whereHas('pushPreference', fn (Builder $p) => $p
                ->where('push_enabled', true)->where('campaign_enabled', true))
                ->whereHas('pushDevices', fn (Builder $d) => $d
                    ->where('status', PushDevice::STATUS_ACTIVE));
        }

        if ($province !== '') {
            $customerRegion = static function (Builder $addresses) use ($province, $district) {
                $addresses->where('province', $province);
                if ($district !== '') {
                    $addresses->where('district', $district);
                }
            };
            $providerRegion = static function (Builder $profile) use ($province, $district) {
                $profile->where('city', $province);
                if ($district !== '') {
                    $profile->where('district', $district);
                }
            };

            $query->where(function (Builder $q) use ($customerRegion, $providerRegion) {
                $q->where(fn (Builder $w) => $w->where('role', User::ROLE_CUSTOMER)
                    ->whereHas('customerProfile.addresses', $customerRegion))
                    ->orWhere(fn (Builder $w) => $w->where('role', User::ROLE_PROVIDER)
                        ->whereHas('providerProfile', $providerRegion));
            });
        }
        return $query;
    }

    public function estimate(array $filters): array
    {
        $query = $this->query($filters);
        $eligible = (clone $query)->count('users.id');
        $reachable = (clone $query)->whereHas('pushDevices', fn (Builder $devices) => $devices
            ->where('status', PushDevice::STATUS_ACTIVE))->count('users.id');

        return [
            'eligible' => (int) $eligible,
            'push_reachable' => (int) $reachable,
            'in_app_only' => max(0, (int) $eligible - (int) $reachable),
            'requires_opt_in' => ($filters['kind'] ?? 'system') !== 'system',
        ];
    }
}
