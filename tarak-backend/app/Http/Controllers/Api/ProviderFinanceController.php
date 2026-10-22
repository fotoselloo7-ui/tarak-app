<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Jobs\SendPaymentInstructionsEmail;
use App\Models\CommissionTopup;
use App\Models\FinanceSetting;
use App\Services\CommissionTopupService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Str;

/**
 * İşletme Finans Merkezi — the signed-in, APPROVED business's commission payment details and bank payment notices.
 * Customers and anonymous visitors never reach this (role:PROVIDER route group), and neither does a business that is
 * not approved yet.
 */
class ProviderFinanceController extends Controller
{
    /** "Ödeme bilgilerimi e-postama gönder": at most this many mails per hour per business. */
    private const EMAIL_PER_HOUR = 3;

    public function __construct(protected CommissionTopupService $topups) {}

    private function denyUnlessApproved(Request $request): ?JsonResponse
    {
        $profile = $request->user()->providerProfile;
        if (!$profile || !$profile->is_approved) {
            return response()->json([
                'success' => false,
                'message' => 'Ödeme bilgileri yalnızca onaylı işletmelere açıktır.',
            ], 403);
        }

        return null;
    }

    /** Bank account, the business's TRK reference code and the transfer description. */
    public function paymentInfo(Request $request): JsonResponse
    {
        if ($denied = $this->denyUnlessApproved($request)) {
            return $denied;
        }

        return response()->json([
            'success' => true,
            'data' => $this->topups->paymentInstructions($request->user()),
        ]);
    }

    public function topups(Request $request): JsonResponse
    {
        $perPage = max(1, min(50, (int) $request->query('per_page', 20)));
        $page = CommissionTopup::where('provider_user_id', $request->user()->id)->latest('id')->paginate($perPage);

        return response()->json([
            'success' => true,
            'data' => $page->getCollection()->map(fn (CommissionTopup $t) => $this->present($t))->values(),
            'meta' => [
                'current_page' => $page->currentPage(),
                'last_page' => $page->lastPage(),
                'per_page' => $page->perPage(),
                'total' => $page->total(),
            ],
        ]);
    }

    /** "Ödeme bildir": a notice only. It never adds balance; an admin verifies it against the bank statement. */
    public function submitTopup(Request $request): JsonResponse
    {
        if ($denied = $this->denyUnlessApproved($request)) {
            return $denied;
        }

        $validated = $request->validate([
            'amount' => ['required', 'numeric', 'min:1', 'max:1000000'],
            'transfer_date' => ['required', 'date', 'before_or_equal:today', 'after_or_equal:' . now()->subDays(45)->toDateString()],
            'sender_name' => ['nullable', 'string', 'max:150'],
            'note' => ['nullable', 'string', 'max:500'],
        ], [
            'amount.required' => 'Gönderdiğiniz tutarı yazın.',
            'amount.numeric' => 'Tutar sayı olmalıdır.',
            'amount.min' => 'Tutar geçersiz.',
            'transfer_date.required' => 'Transfer tarihini seçin.',
            'transfer_date.before_or_equal' => 'Transfer tarihi bugünden ileri olamaz.',
            'transfer_date.after_or_equal' => 'Transfer tarihi çok eski görünüyor. Lütfen destek ile iletişime geçin.',
        ]);

        $topup = $this->topups->submitNotice($request->user(), $validated);

        return response()->json([
            'success' => true,
            'message' => 'Ödeme bildiriminiz alındı. Tutar banka kaydımızda doğrulandığında komisyon bakiyenize eklenir.',
            'data' => $this->present($topup),
        ], $topup->wasRecentlyCreated ? 201 : 200);
    }

    /** Sends the payment details to the e-mail registered on the account, rate limited. */
    public function emailPaymentInfo(Request $request): JsonResponse
    {
        if ($denied = $this->denyUnlessApproved($request)) {
            return $denied;
        }

        $user = $request->user();
        if (!$user->email) {
            return response()->json([
                'success' => false,
                'message' => 'Hesabınıza kayıtlı bir e-posta adresi yok. Profilinizden e-posta ekleyin veya web finans merkezini kullanın.',
            ], 422);
        }

        if (!FinanceSetting::current()->hasBankAccount()) {
            return response()->json([
                'success' => false,
                'message' => 'Banka hesabı bilgileri henüz hazır değil. Lütfen daha sonra tekrar deneyin.',
            ], 422);
        }

        $key = 'payment-info-email:' . $user->id;
        if (RateLimiter::tooManyAttempts($key, self::EMAIL_PER_HOUR)) {
            $seconds = RateLimiter::availableIn($key);

            return response()->json([
                'success' => false,
                'message' => 'Çok sık istek gönderdiniz. ' . (int) ceil($seconds / 60) . ' dakika sonra tekrar deneyin.',
                'retry_after' => $seconds,
            ], 429)->header('Retry-After', (string) $seconds);
        }
        RateLimiter::hit($key, 3600);

        SendPaymentInstructionsEmail::dispatch($user->id);

        return response()->json([
            'success' => true,
            'message' => 'Ödeme bilgileriniz ' . self::maskEmail($user->email) . ' adresine gönderiliyor.',
            'data' => ['email' => self::maskEmail($user->email)],
        ]);
    }

    private static function maskEmail(string $email): string
    {
        [$local, $domain] = array_pad(explode('@', $email, 2), 2, '');
        if ($domain === '') {
            return Str::mask($email, '*', 2);
        }

        return mb_substr($local, 0, 1) . '***@' . $domain;
    }

    private function present(CommissionTopup $t): array
    {
        return [
            'id' => $t->id,
            'reference_code' => $t->reference_code,
            'status' => $t->status,
            'status_label' => CommissionTopup::statusLabel($t->status),
            'claimed_amount' => (float) $t->claimed_amount,
            'verified_amount' => $t->verified_amount !== null ? (float) $t->verified_amount : null,
            'transfer_date' => $t->transfer_date?->toDateString(),
            'sender_name' => $t->sender_name,
            'provider_note' => $t->provider_note,
            // The reason of a rejection is for the business; internal notes on paid rows stay internal.
            'admin_note' => $t->status === CommissionTopup::STATUS_REJECTED ? $t->admin_note : null,
            'created_at' => $t->created_at?->toISOString(),
            'reviewed_at' => $t->reviewed_at?->toISOString(),
        ];
    }
}
