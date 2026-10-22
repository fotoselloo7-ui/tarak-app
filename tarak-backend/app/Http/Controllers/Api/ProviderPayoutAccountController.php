<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\PayoutTransfer;
use App\Models\ProviderPayoutAccount;
use App\Services\IbanValidator;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

class ProviderPayoutAccountController extends Controller
{
    /**
     * GET /api/provider/payout-account
     * Returns the authenticated provider's payout bank account details.
     * Full IBAN is NEVER exposed in the response.
     */
    public function show(Request $request): JsonResponse
    {
        $user = $request->user();
        $account = ProviderPayoutAccount::where('provider_user_id', $user->id)->first();

        if (!$account) {
            return response()->json([
                'success' => true,
                'data' => null,
                'message' => 'Henüz kayıtlı bir hakediş banka hesabı bulunmuyor.',
            ]);
        }

        return response()->json([
            'success' => true,
            'data' => [
                'id' => $account->id,
                'account_holder_name' => \App\Support\CustomerNote::forDisplay($account->account_holder_name),
                'iban_masked' => $account->iban_masked,
                'status' => $account->status,
                'verified_at' => $account->verified_at?->toISOString(),
                'payout_tax_status' => $account->payout_tax_status,
                'tax_type' => $account->tax_type,
                'tax_id_masked' => $account->tax_id_masked,
                'tax_office' => $account->tax_office,
                'withholding_rate' => $account->withholding_rate !== null ? (float) $account->withholding_rate : null,
                'withholding_basis' => $account->withholding_basis,
                'created_at' => $account->created_at?->toISOString(),
                'updated_at' => $account->updated_at?->toISOString(),
            ],
        ]);
    }

    /**
     * PUT /api/provider/payout-account
     * Stores or updates the authenticated provider's bank account.
     * Enforces strict TR IBAN format & ISO 7064 MOD 97-10 checksum validation.
     * Full IBAN is NEVER returned in the response.
     */
    public function update(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'account_holder_name' => ['required', 'string', 'min:3', 'max:255'],
            'iban' => ['required', 'string'],
            'payout_tax_status' => ['nullable', 'string', 'in:NOT_CONFIGURED,CONFIGURED'],
            'tax_type' => ['nullable', 'string', 'max:50'],
            'tax_id_or_tckn' => ['nullable', 'string', 'max:50'],
            'tax_office' => ['nullable', 'string', 'max:100'],
            'withholding_rate' => ['nullable', 'numeric', 'min:0', 'max:100'],
            'withholding_basis' => ['nullable', 'string', 'max:100'],
        ]);

        $normalizedIban = IbanValidator::normalize($validated['iban']);

        if (!IbanValidator::validate($normalizedIban)) {
            throw ValidationException::withMessages([
                'iban' => ['Geçerli bir Türkiye IBAN numarası giriniz. Sağlama (checksum) algoritması doğrulanamadı.'],
            ]);
        }

        $user = $request->user();
        $last4 = substr($normalizedIban, -4);

        $account = ProviderPayoutAccount::updateOrCreate(
            ['provider_user_id' => $user->id],
            [
                'account_holder_name' => trim($validated['account_holder_name']),
                'iban_encrypted' => $normalizedIban, // Encrypted by Eloquent cast
                'iban_last4' => $last4,
                'status' => ProviderPayoutAccount::STATUS_ACTIVE,
                'payout_tax_status' => $validated['payout_tax_status'] ?? ProviderPayoutAccount::TAX_STATUS_NOT_CONFIGURED,
                'tax_type' => $validated['tax_type'] ?? null,
                'tax_id_or_tckn' => $validated['tax_id_or_tckn'] ?? null,
                'tax_office' => $validated['tax_office'] ?? null,
                'withholding_rate' => isset($validated['withholding_rate']) ? $validated['withholding_rate'] : null,
                'withholding_basis' => $validated['withholding_basis'] ?? null,
            ]
        );

        return response()->json([
            'success' => true,
            'message' => 'Hakediş banka hesabı başarıyla kaydedildi.',
            'data' => [
                'id' => $account->id,
                'account_holder_name' => \App\Support\CustomerNote::forDisplay($account->account_holder_name),
                'iban_masked' => $account->iban_masked,
                'status' => $account->status,
                'verified_at' => $account->verified_at?->toISOString(),
                'payout_tax_status' => $account->payout_tax_status,
                'tax_type' => $account->tax_type,
                'tax_id_masked' => $account->tax_id_masked,
                'withholding_rate' => $account->withholding_rate !== null ? (float) $account->withholding_rate : null,
            ],
        ]);
    }

    /**
     * GET /api/provider/payouts
     * Returns provider's payout transfer history.
     */
    public function payouts(Request $request): JsonResponse
    {
        $user = $request->user();

        $transfers = PayoutTransfer::where('provider_user_id', $user->id)
            ->with(['servicePayment'])
            ->orderBy('created_at', 'desc')
            ->get();

        $data = $transfers->map(function (PayoutTransfer $pt) {
            return [
                'id' => $pt->id,
                'service_payment_id' => $pt->service_payment_id,
                'resource_type' => $pt->servicePayment?->resource_type,
                'resource_id' => $pt->servicePayment?->resource_id,
                'trans_id' => $pt->trans_id,
                'gross_amount' => (float) $pt->gross_amount,
                'platform_commission' => (float) $pt->platform_commission,
                'withholding_amount' => (float) $pt->withholding_amount,
                'final_submerchant_amount' => (float) $pt->final_submerchant_amount,
                'status' => $pt->status,
                'status_label' => $pt->status_label,
                'iban_masked' => $pt->iban_masked,
                'eligible_at' => $pt->eligible_at?->toISOString(),
                'requested_at' => $pt->requested_at?->toISOString(),
                'completed_at' => $pt->completed_at?->toISOString(),
                'failed_at' => $pt->failed_at?->toISOString(),
                'created_at' => $pt->created_at?->toISOString(),
            ];
        });

        return response()->json([
            'success' => true,
            'data' => $data,
        ]);
    }
}
