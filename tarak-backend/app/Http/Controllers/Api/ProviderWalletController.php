<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Wallet;
use App\Models\WalletTransaction;
use App\Services\FinancialService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ProviderWalletController extends Controller
{
    public function __construct(
        protected FinancialService $financialService
    ) {}

    /**
     * Get provider's wallet breakdown and usable balances.
     * Protected: PROVIDER only.
     */
    public function getWallet(Request $request): JsonResponse
    {
        $user = $request->user();
        $summary = $this->financialService->getProviderFinancialSummary($user->id);

        return response()->json([
            'success' => true,
            'data' => $summary,
        ]);
    }

    /**
     * Get paginated ledger transactions for provider's wallet.
     * Provider can strictly ONLY view their own transactions.
     * Protected: PROVIDER only.
     */
    public function getTransactions(Request $request): JsonResponse
    {
        $user = $request->user();
        $wallet = Wallet::where('user_id', $user->id)->first();

        if (!$wallet) {
            return response()->json([
                'success' => true,
                'data' => [],
                'meta' => [
                    'current_page' => 1,
                    'last_page' => 1,
                    'per_page' => 15,
                    'total' => 0,
                ],
            ]);
        }

        $perPage = max(1, min(50, (int) $request->query('per_page', 15)));

        $transactions = WalletTransaction::where('wallet_id', $wallet->id)
            ->where('user_id', $user->id)
            ->latest('id')
            ->paginate($perPage);

        $transformed = $transactions->getCollection()->map(function (WalletTransaction $tx) {
            return [
                'id' => (string) $tx->id,
                'type' => $tx->type,
                'direction' => $tx->direction,
                'bucket' => $tx->bucket,
                'amount' => (float) $tx->amount,
                'reference_type' => $tx->reference_type,
                'reference_id' => $tx->reference_id,
                'description' => \App\Support\CustomerNote::forDisplay($tx->description) ?? 'Bakiye hareketi',
                'created_at' => $tx->created_at?->toISOString(),
            ];
        });

        return response()->json([
            'success' => true,
            'data' => $transformed,
            'meta' => [
                'current_page' => $transactions->currentPage(),
                'last_page' => $transactions->lastPage(),
                'per_page' => $transactions->perPage(),
                'total' => $transactions->total(),
            ],
        ]);
    }
}
