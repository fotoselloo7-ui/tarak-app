<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\FinanceSetting;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AdminFinanceController extends Controller
{
    /**
     * Get active finance settings.
     * Protected: ADMIN only.
     */
    public function getSettings(): JsonResponse
    {
        $setting = FinanceSetting::current();

        return response()->json([
            'success' => true,
            'data' => [
                'id' => $setting->id,
                'default_commission_rate' => (float) $setting->default_commission_rate,
                'welcome_bonus_amount' => (float) $setting->welcome_bonus_amount,
                'currency' => $setting->currency,
                'updated_at' => $setting->updated_at?->toISOString(),
            ],
        ]);
    }

    /**
     * Update active finance settings.
     * Protected: ADMIN only.
     */
    public function updateSettings(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'default_commission_rate' => ['required', 'numeric', 'min:0', 'max:100'],
            'welcome_bonus_amount' => ['required', 'numeric', 'min:0', 'max:100000'],
        ], [
            'default_commission_rate.required' => 'Varsayılan komisyon oranı zorunludur.',
            'default_commission_rate.min' => 'Komisyon oranı en az %0 olabilir.',
            'default_commission_rate.max' => 'Komisyon oranı en fazla %100 olabilir.',
            'welcome_bonus_amount.required' => 'Hoş geldin bonusu tutarı zorunludur.',
            'welcome_bonus_amount.min' => 'Hoş geldin bonusu 0 veya pozitif bir değer olmalıdır.',
            'welcome_bonus_amount.max' => 'Hoş geldin bonusu en fazla 100,000 olabilir.',
        ]);

        $setting = FinanceSetting::current();
        $setting->update([
            'default_commission_rate' => $validated['default_commission_rate'],
            'welcome_bonus_amount' => $validated['welcome_bonus_amount'],
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Finans ayarları başarıyla güncellendi.',
            'data' => [
                'id' => $setting->id,
                'default_commission_rate' => (float) $setting->default_commission_rate,
                'welcome_bonus_amount' => (float) $setting->welcome_bonus_amount,
                'currency' => $setting->currency,
                'updated_at' => $setting->updated_at?->toISOString(),
            ],
        ]);
    }
}
