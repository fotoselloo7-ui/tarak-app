<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AdminLog;
use App\Models\CommissionTopup;
use App\Models\FinanceSetting;
use App\Models\WalletTransaction;
use App\Services\CommissionTopupService;
use App\Services\IbanValidator;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

/**
 * Admin side of the bank collection: the account businesses pay into, the payment notices and verification,
 * the commission ledger and the audit log. ADMIN only (route group). A notice or a receipt never adds balance by
 * itself: verification against the bank statement does.
 */
class AdminCommissionTopupController extends Controller
{
    public function __construct(protected CommissionTopupService $topups) {}

    // ------------------------------------------------------------------ bank account

    public function bankSettings(): JsonResponse
    {
        return response()->json(['success' => true, 'data' => $this->bankPayload(FinanceSetting::current())]);
    }

    public function updateBankSettings(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'bank_account_holder' => ['required', 'string', 'min:3', 'max:150'],
            'bank_name' => ['nullable', 'string', 'max:100'],
            'bank_iban' => ['required', 'string', 'max:40'],
            'bank_instructions' => ['nullable', 'string', 'max:1000'],
            'topup_min_amount' => ['required', 'numeric', 'min:1', 'max:100000'],
        ], [
            'bank_account_holder.required' => 'Şirket unvanı zorunludur.',
            'bank_iban.required' => 'IBAN zorunludur.',
            'topup_min_amount.required' => 'En az yükleme tutarı zorunludur.',
        ]);

        if (!IbanValidator::validate($validated['bank_iban'])) {
            throw ValidationException::withMessages(['bank_iban' => ['Geçerli bir TR IBAN giriniz (26 karakter, doğrulama basamağı tutmalı).']]);
        }

        $setting = FinanceSetting::current();
        $before = $this->bankPayload($setting);

        $setting->update([
            'bank_account_holder' => trim($validated['bank_account_holder']),
            'bank_name' => isset($validated['bank_name']) ? trim($validated['bank_name']) ?: null : null,
            'bank_iban' => IbanValidator::normalize($validated['bank_iban']),
            'bank_instructions' => isset($validated['bank_instructions']) ? trim($validated['bank_instructions']) ?: null : null,
            'topup_min_amount' => $validated['topup_min_amount'],
        ]);

        $after = $this->bankPayload($setting->refresh());
        AdminLog::logAction($request->user()->id, AdminLog::ACTION_BANK_SETTINGS_SAVED, AdminLog::TARGET_SYSTEM, $setting->id, [
            'changed' => array_keys(array_filter($after, fn ($v, $k) => ($before[$k] ?? null) !== $v && $k !== 'configured', ARRAY_FILTER_USE_BOTH)),
            'iban_last4' => substr((string) $setting->bank_iban, -4),
            'account_holder' => $setting->bank_account_holder,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Banka hesabı bilgileri kaydedildi.',
            'data' => $after,
        ]);
    }

    private function bankPayload(FinanceSetting $s): array
    {
        return [
            'bank_account_holder' => $s->bank_account_holder,
            'bank_name' => $s->bank_name,
            'bank_iban' => $s->bank_iban,
            'bank_instructions' => $s->bank_instructions,
            'topup_min_amount' => (float) $s->topup_min_amount,
            'configured' => $s->hasBankAccount(),
        ];
    }

    // ------------------------------------------------------------------ payment notices

    public function index(Request $request): JsonResponse
    {
        $status = strtoupper((string) $request->query('status', ''));
        $q = trim((string) $request->query('q', ''));
        $perPage = max(1, min(100, (int) $request->query('per_page', 20)));

        $query = CommissionTopup::query()->with(['provider.providerProfile', 'reviewer'])->latest('id');
        if (in_array($status, [CommissionTopup::STATUS_PENDING, CommissionTopup::STATUS_PAID, CommissionTopup::STATUS_REJECTED], true)) {
            $query->where('status', $status);
        }
        if ($q !== '') {
            $like = '%' . str_replace(['%', '_'], ['\\%', '\\_'], $q) . '%';
            $query->where(function ($w) use ($like) {
                $w->where('reference_code', 'like', $like)
                    ->orWhere('sender_name', 'like', $like)
                    ->orWhere('bank_transaction_ref', 'like', $like)
                    ->orWhereHas('provider', fn ($u) => $u->where('name', 'like', $like)->orWhere('email', 'like', $like))
                    ->orWhereHas('provider.providerProfile', fn ($p) => $p->where('business_name', 'like', $like));
            });
        }

        $page = $query->paginate($perPage);

        return response()->json([
            'success' => true,
            'data' => $page->getCollection()->map(fn (CommissionTopup $t) => $this->present($t))->values(),
            'meta' => [
                'current_page' => $page->currentPage(),
                'last_page' => $page->lastPage(),
                'per_page' => $page->perPage(),
                'total' => $page->total(),
            ],
            'summary' => [
                'pending' => CommissionTopup::where('status', CommissionTopup::STATUS_PENDING)->count(),
                'pending_amount' => (float) CommissionTopup::where('status', CommissionTopup::STATUS_PENDING)->sum('claimed_amount'),
                'paid' => CommissionTopup::where('status', CommissionTopup::STATUS_PAID)->count(),
                'paid_amount' => (float) CommissionTopup::where('status', CommissionTopup::STATUS_PAID)->sum('verified_amount'),
                'rejected' => CommissionTopup::where('status', CommissionTopup::STATUS_REJECTED)->count(),
            ],
        ]);
    }

    /** The money is on the bank statement; match it to the business by TRK code (no notice needed). */
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'reference_code' => ['required', 'string', 'max:20'],
            'amount' => ['required', 'numeric', 'min:0.01', 'max:1000000'],
            'bank_transaction_ref' => ['required', 'string', 'min:3', 'max:100'],
            'transfer_date' => ['nullable', 'date', 'before_or_equal:today'],
            'sender_name' => ['nullable', 'string', 'max:150'],
            'admin_note' => ['nullable', 'string', 'max:500'],
        ], [
            'reference_code.required' => 'TRK referans kodu zorunludur.',
            'bank_transaction_ref.required' => 'Banka işlem / dekont referansı zorunludur.',
        ]);

        $topup = $this->topups->recordBankReceipt($request->user(), $validated);

        return response()->json([
            'success' => true,
            'message' => 'Banka ödemesi işlendi ve komisyon bakiyesine eklendi.',
            'data' => $this->present($topup->load(['provider.providerProfile', 'reviewer'])),
        ], 201);
    }

    public function verify(int $id, Request $request): JsonResponse
    {
        $validated = $request->validate([
            'verified_amount' => ['required', 'numeric', 'min:0.01', 'max:1000000'],
            'bank_transaction_ref' => ['required', 'string', 'min:3', 'max:100'],
            'admin_note' => ['nullable', 'string', 'max:500'],
        ], [
            'verified_amount.required' => 'Banka kaydındaki tutarı girin.',
            'bank_transaction_ref.required' => 'Banka işlem / dekont referansı zorunludur.',
        ]);

        $topup = $this->topups->verify($id, $request->user(), (string) $validated['verified_amount'], $validated['bank_transaction_ref'], $validated['admin_note'] ?? null);

        return response()->json([
            'success' => true,
            'message' => 'Ödeme doğrulandı ve komisyon bakiyesine eklendi.',
            'data' => $this->present($topup->load(['provider.providerProfile', 'reviewer'])),
        ]);
    }

    public function reject(int $id, Request $request): JsonResponse
    {
        $validated = $request->validate([
            'admin_note' => ['required', 'string', 'min:3', 'max:500'],
        ], [
            'admin_note.required' => 'Reddetme nedeni zorunludur.',
        ]);

        $topup = $this->topups->reject($id, $request->user(), $validated['admin_note']);

        return response()->json([
            'success' => true,
            'message' => 'Ödeme bildirimi reddedildi.',
            'data' => $this->present($topup->load(['provider.providerProfile', 'reviewer'])),
        ]);
    }

    private function present(CommissionTopup $t): array
    {
        $profile = $t->provider?->providerProfile;

        return [
            'id' => $t->id,
            'reference_code' => $t->reference_code,
            'source' => $t->source,
            'status' => $t->status,
            'status_label' => CommissionTopup::statusLabel($t->status),
            'provider' => [
                'id' => $t->provider_user_id,
                'name' => $t->provider?->name,
                'email' => $t->provider?->email,
                'business_name' => $profile?->business_name,
            ],
            'claimed_amount' => (float) $t->claimed_amount,
            'verified_amount' => $t->verified_amount !== null ? (float) $t->verified_amount : null,
            'transfer_date' => $t->transfer_date?->toDateString(),
            'sender_name' => $t->sender_name,
            'bank_transaction_ref' => $t->bank_transaction_ref,
            'provider_note' => $t->provider_note,
            'admin_note' => $t->admin_note,
            'reviewed_by' => $t->reviewer?->name,
            'reviewed_at' => $t->reviewed_at?->toISOString(),
            'wallet_transaction_id' => $t->wallet_transaction_id,
            'created_at' => $t->created_at?->toISOString(),
        ];
    }

    // ------------------------------------------------------------------ ledger + audit

    /** Read-only commission ledger across all businesses (wallet_transactions are immutable). */
    public function ledger(Request $request): JsonResponse
    {
        $perPage = max(1, min(100, (int) $request->query('per_page', 30)));
        $type = strtoupper((string) $request->query('type', ''));
        $q = trim((string) $request->query('q', ''));

        $query = WalletTransaction::query()->with(['user.providerProfile'])->latest('id');
        if ($type !== '') {
            $query->where('type', $type);
        }
        if ($request->filled('provider_id')) {
            $query->where('user_id', (int) $request->query('provider_id'));
        }
        if ($q !== '') {
            $like = '%' . str_replace(['%', '_'], ['\\%', '\\_'], $q) . '%';
            $query->where(function ($w) use ($like) {
                $w->where('description', 'like', $like)
                    ->orWhereHas('user', fn ($u) => $u->where('name', 'like', $like)->orWhere('email', 'like', $like))
                    ->orWhereHas('user.providerProfile', fn ($p) => $p->where('business_name', 'like', $like)->orWhere('payment_reference', 'like', $like));
            });
        }

        $page = $query->paginate($perPage);

        return response()->json([
            'success' => true,
            'data' => $page->getCollection()->map(fn (WalletTransaction $tx) => [
                'id' => $tx->id,
                'type' => $tx->type,
                'direction' => $tx->direction,
                'bucket' => $tx->bucket,
                'amount' => (float) $tx->amount,
                'reference_type' => $tx->reference_type,
                'reference_id' => $tx->reference_id,
                'description' => $tx->description,
                'provider' => [
                    'id' => $tx->user_id,
                    'name' => $tx->user?->name,
                    'business_name' => $tx->user?->providerProfile?->business_name,
                ],
                'created_at' => $tx->created_at?->toISOString(),
            ])->values(),
            'meta' => [
                'current_page' => $page->currentPage(),
                'last_page' => $page->lastPage(),
                'per_page' => $page->perPage(),
                'total' => $page->total(),
            ],
        ]);
    }

    public function auditLogs(Request $request): JsonResponse
    {
        $perPage = max(1, min(100, (int) $request->query('per_page', 30)));
        $page = AdminLog::whereIn('action', AdminLog::FINANCE_ACTIONS)->with('adminUser')->latest('id')->paginate($perPage);

        return response()->json([
            'success' => true,
            'data' => $page->getCollection()->map(fn (AdminLog $log) => [
                'id' => $log->id,
                'action' => $log->action,
                'target_type' => $log->target_type,
                'target_id' => $log->target_id,
                'admin' => $log->adminUser?->name,
                'metadata' => $log->metadata,
                'created_at' => $log->created_at?->toISOString(),
            ])->values(),
            'meta' => [
                'current_page' => $page->currentPage(),
                'last_page' => $page->lastPage(),
                'per_page' => $page->perPage(),
                'total' => $page->total(),
            ],
        ]);
    }
}
