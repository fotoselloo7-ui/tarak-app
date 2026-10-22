<?php

namespace App\Services;

use App\Models\AdminLog;
use App\Models\CommissionTopup;
use App\Models\FinanceSetting;
use App\Models\ProviderProfile;
use App\Models\User;
use App\Models\UserNotification;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Commission credit paid by bank transfer (IBAN / havale / EFT) to Tarak.
 *
 * Money rules:
 *  - A business's payment notice (PENDING) never changes a balance, a receipt alone neither.
 *  - Credit is posted exactly once, by an admin, against a bank statement line (bank_transaction_ref is unique).
 *  - Every state change writes an audit log row and keeps the wallet ledger immutable.
 */
class CommissionTopupService
{
    /** Open (unverified) notices one business may have at the same time. */
    public const MAX_PENDING_NOTICES = 5;

    public function __construct(
        protected FinancialService $financial,
        protected NotificationService $notifications,
    ) {}

    /**
     * The business's unique TRK reference code (created once, kept forever). It goes into the transfer description
     * so the bank statement line can be matched to the business.
     */
    public function referenceFor(User|int $provider): string
    {
        $userId = $provider instanceof User ? $provider->id : $provider;

        return DB::transaction(function () use ($userId) {
            $profile = ProviderProfile::where('user_id', $userId)->lockForUpdate()->first();
            if (!$profile) {
                throw ValidationException::withMessages(['provider' => ['İşletme profili bulunamadı.']]);
            }
            if ($profile->payment_reference) {
                return $profile->payment_reference;
            }

            do {
                $code = 'TRK' . $this->randomChars(7);
            } while (ProviderProfile::where('payment_reference', $code)->exists());

            $profile->payment_reference = $code;
            $profile->save();

            return $code;
        });
    }

    private function randomChars(int $length): string
    {
        // No 0/O/1/I: the code is typed into a bank app and read off a statement.
        $alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
        $out = '';
        for ($i = 0; $i < $length; $i++) {
            $out .= $alphabet[random_int(0, strlen($alphabet) - 1)];
        }

        return $out;
    }

    /**
     * Everything a business needs to pay: only for the signed-in, approved business (never public, never customers).
     */
    public function paymentInstructions(User $provider): array
    {
        $setting = FinanceSetting::current();
        $reference = $this->referenceFor($provider);
        $profile = ProviderProfile::where('user_id', $provider->id)->first();
        $configured = $setting->hasBankAccount();
        $iban = $configured ? IbanValidator::normalize((string) $setting->bank_iban) : null;

        return [
            'bank_account_configured' => $configured,
            'business_name' => $profile?->business_name ?: $provider->name,
            'account_holder' => $configured ? $setting->bank_account_holder : null,
            'bank_name' => $configured ? $setting->bank_name : null,
            'iban' => $iban,
            'iban_formatted' => $iban ? trim(chunk_split($iban, 4, ' ')) : null,
            'reference_code' => $reference,
            'transfer_description' => $reference . ' komisyon bakiyesi',
            'min_amount' => (float) $setting->topup_min_amount,
            'instructions' => $setting->bank_instructions,
            'currency' => $setting->currency ?: 'TRY',
        ];
    }

    /**
     * The business tells us it sent a payment. This creates a PENDING notice only — no balance moves.
     * Repeating the same notice (double click, retry) returns the existing one.
     */
    public function submitNotice(User $provider, array $data): CommissionTopup
    {
        $setting = FinanceSetting::current();
        $amountCents = FinancialService::parseToCents($data['amount']);
        $minCents = FinancialService::parseToCents($setting->topup_min_amount);

        if ($amountCents < max(1, $minCents)) {
            throw ValidationException::withMessages([
                'amount' => ['En az ₺' . number_format($minCents / 100, 2, ',', '.') . ' tutarında ödeme bildirebilirsiniz.'],
            ]);
        }

        $reference = $this->referenceFor($provider);
        $transferDate = Carbon::parse($data['transfer_date'])->startOfDay();
        $sender = isset($data['sender_name']) ? trim((string) $data['sender_name']) : null;

        return DB::transaction(function () use ($provider, $data, $amountCents, $reference, $transferDate, $sender) {
            // Serialise a business's notices so the pending limit and the duplicate check cannot race.
            ProviderProfile::where('user_id', $provider->id)->lockForUpdate()->first();

            $duplicate = CommissionTopup::where('provider_user_id', $provider->id)
                ->where('status', CommissionTopup::STATUS_PENDING)
                ->where('claimed_amount', FinancialService::formatFromCents($amountCents))
                ->whereDate('transfer_date', $transferDate->toDateString())
                ->when(
                    $sender !== null && $sender !== '',
                    fn ($q) => $q->where('sender_name', $sender),
                    fn ($q) => $q->whereNull('sender_name')
                )
                ->first();
            if ($duplicate) {
                return $duplicate;
            }

            $pending = CommissionTopup::where('provider_user_id', $provider->id)
                ->where('status', CommissionTopup::STATUS_PENDING)
                ->count();
            if ($pending >= self::MAX_PENDING_NOTICES) {
                throw ValidationException::withMessages([
                    'amount' => ['Doğrulama bekleyen ' . self::MAX_PENDING_NOTICES . ' bildiriminiz var. Önce bunların sonuçlanmasını bekleyin.'],
                ]);
            }

            return CommissionTopup::create([
                'provider_user_id' => $provider->id,
                'reference_code' => $reference,
                'source' => CommissionTopup::SOURCE_PROVIDER_NOTICE,
                'status' => CommissionTopup::STATUS_PENDING,
                'claimed_amount' => FinancialService::formatFromCents($amountCents),
                'transfer_date' => $transferDate->toDateString(),
                'sender_name' => $sender ?: null,
                'provider_note' => isset($data['note']) ? trim((string) $data['note']) ?: null : null,
            ]);
        });
    }

    /**
     * Admin saw the money on the bank statement: post the credit. Idempotent (a PAID notice stays PAID, one bank
     * statement reference can only ever credit once).
     */
    public function verify(int $topupId, User $admin, string $verifiedAmount, string $bankTransactionRef, ?string $adminNote = null): CommissionTopup
    {
        $bankRef = trim($bankTransactionRef);
        if (mb_strlen($bankRef) < 3) {
            throw ValidationException::withMessages(['bank_transaction_ref' => ['Banka işlem / dekont referansı zorunludur.']]);
        }

        $cents = FinancialService::parseToCents($verifiedAmount);
        if ($cents <= 0 || $cents > 100_000_000) {
            throw ValidationException::withMessages(['verified_amount' => ['Doğrulanan tutar geçersiz.']]);
        }

        return DB::transaction(function () use ($topupId, $admin, $cents, $bankRef, $adminNote) {
            $topup = CommissionTopup::whereKey($topupId)->lockForUpdate()->first();
            if (!$topup) {
                throw ValidationException::withMessages(['topup' => ['Ödeme bildirimi bulunamadı.']]);
            }

            if ($topup->status === CommissionTopup::STATUS_PAID) {
                return $topup;
            }
            if ($topup->status === CommissionTopup::STATUS_REJECTED) {
                throw ValidationException::withMessages(['topup' => ['Reddedilen bildirim doğrulanamaz; gerekirse banka kaydını yeni bir ödeme olarak girin.']]);
            }

            $used = CommissionTopup::where('bank_transaction_ref', $bankRef)->where('id', '!=', $topup->id)->exists();
            if ($used) {
                throw ValidationException::withMessages(['bank_transaction_ref' => ['Bu banka işlem referansı daha önce başka bir ödemeye işlendi.']]);
            }

            $amount = FinancialService::formatFromCents($cents);
            $topup->status = CommissionTopup::STATUS_PAID;
            $topup->verified_amount = $amount;
            $topup->bank_transaction_ref = $bankRef;
            $topup->admin_note = $adminNote ? mb_substr(trim($adminNote), 0, 500) : null;
            $topup->reviewed_by_user_id = $admin->id;
            $topup->reviewed_at = now();
            $topup->save();

            $this->financial->creditCommissionTopup($topup, $amount);

            AdminLog::logAction($admin->id, AdminLog::ACTION_COMMISSION_TOPUP_VERIFIED, AdminLog::TARGET_COMMISSION_TOPUP, $topup->id, [
                'provider_user_id' => $topup->provider_user_id,
                'reference_code' => $topup->reference_code,
                'claimed_amount' => (string) $topup->claimed_amount,
                'verified_amount' => $amount,
                'bank_transaction_ref' => $bankRef,
            ]);

            $this->notifications->notifyUser(
                $topup->provider_user_id,
                UserNotification::TYPE_COMMISSION_TOPUP_VERIFIED,
                'Komisyon bakiyeniz yüklendi',
                '₺' . number_format($cents / 100, 2, ',', '.') . ' ödemeniz doğrulandı ve komisyon bakiyenize eklendi.',
                UserNotification::RESOURCE_COMMISSION_TOPUP,
                $topup->id,
                '/barber?tab=wallet',
                ['amount' => (float) $amount, 'reference_code' => $topup->reference_code],
                "COMMISSION_TOPUP_VERIFIED:{$topup->id}"
            );

            return $topup->refresh();
        });
    }

    public function reject(int $topupId, User $admin, string $adminNote): CommissionTopup
    {
        $note = trim($adminNote);
        if ($note === '') {
            throw ValidationException::withMessages(['admin_note' => ['Reddetme nedeni zorunludur.']]);
        }

        return DB::transaction(function () use ($topupId, $admin, $note) {
            $topup = CommissionTopup::whereKey($topupId)->lockForUpdate()->first();
            if (!$topup) {
                throw ValidationException::withMessages(['topup' => ['Ödeme bildirimi bulunamadı.']]);
            }
            if ($topup->status === CommissionTopup::STATUS_REJECTED) {
                return $topup;
            }
            if ($topup->status === CommissionTopup::STATUS_PAID) {
                throw ValidationException::withMessages(['topup' => ['Doğrulanmış ödeme reddedilemez.']]);
            }

            $topup->status = CommissionTopup::STATUS_REJECTED;
            $topup->admin_note = mb_substr($note, 0, 500);
            $topup->reviewed_by_user_id = $admin->id;
            $topup->reviewed_at = now();
            $topup->save();

            AdminLog::logAction($admin->id, AdminLog::ACTION_COMMISSION_TOPUP_REJECTED, AdminLog::TARGET_COMMISSION_TOPUP, $topup->id, [
                'provider_user_id' => $topup->provider_user_id,
                'reference_code' => $topup->reference_code,
                'claimed_amount' => (string) $topup->claimed_amount,
                'reason' => $topup->admin_note,
            ]);

            $this->notifications->notifyUser(
                $topup->provider_user_id,
                UserNotification::TYPE_COMMISSION_TOPUP_REJECTED,
                'Ödeme bildiriminiz doğrulanamadı',
                'Bildirdiğiniz ödeme banka kayıtlarımızla eşleşmedi: ' . $topup->admin_note,
                UserNotification::RESOURCE_COMMISSION_TOPUP,
                $topup->id,
                '/barber?tab=wallet',
                ['reference_code' => $topup->reference_code],
                "COMMISSION_TOPUP_REJECTED:{$topup->id}"
            );

            return $topup->refresh();
        });
    }

    /**
     * The money is on the bank statement but the business never sent a notice: the admin matches it by TRK code.
     * Idempotent per bank statement reference.
     */
    public function recordBankReceipt(User $admin, array $data): CommissionTopup
    {
        $code = strtoupper(preg_replace('/\s+/', '', (string) $data['reference_code']));
        $bankRef = trim((string) $data['bank_transaction_ref']);

        $profile = ProviderProfile::where('payment_reference', $code)->first();
        if (!$profile) {
            throw ValidationException::withMessages(['reference_code' => ['Bu TRK referans koduna ait işletme bulunamadı.']]);
        }

        $existing = CommissionTopup::where('bank_transaction_ref', $bankRef)->first();
        if ($existing) {
            if ((int) $existing->provider_user_id === (int) $profile->user_id && $existing->status === CommissionTopup::STATUS_PAID) {
                return $existing; // the same statement line entered twice
            }
            throw ValidationException::withMessages(['bank_transaction_ref' => ['Bu banka işlem referansı daha önce işlendi.']]);
        }

        $amountCents = FinancialService::parseToCents($data['amount']);
        if ($amountCents <= 0) {
            throw ValidationException::withMessages(['amount' => ['Tutar geçersiz.']]);
        }

        // One transaction: a failed verification must not leave an orphan PENDING row behind.
        return DB::transaction(function () use ($profile, $code, $data, $amountCents, $admin, $bankRef) {
            $topup = CommissionTopup::create([
                'provider_user_id' => $profile->user_id,
                'reference_code' => $code,
                'source' => CommissionTopup::SOURCE_ADMIN_ENTRY,
                'status' => CommissionTopup::STATUS_PENDING,
                'claimed_amount' => FinancialService::formatFromCents($amountCents),
                'transfer_date' => $data['transfer_date'] ?? now()->toDateString(),
                'sender_name' => isset($data['sender_name']) ? trim((string) $data['sender_name']) ?: null : null,
            ]);

            $paid = $this->verify($topup->id, $admin, FinancialService::formatFromCents($amountCents), $bankRef, $data['admin_note'] ?? null);

            AdminLog::logAction($admin->id, AdminLog::ACTION_COMMISSION_TOPUP_RECORDED, AdminLog::TARGET_COMMISSION_TOPUP, $paid->id, [
                'provider_user_id' => $paid->provider_user_id,
                'reference_code' => $code,
                'amount' => (string) $paid->verified_amount,
                'bank_transaction_ref' => $bankRef,
            ]);

            return $paid;
        });
    }
}
