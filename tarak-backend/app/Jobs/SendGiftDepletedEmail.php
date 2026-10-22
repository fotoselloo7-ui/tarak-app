<?php

namespace App\Jobs;

use App\Models\User;
use App\Models\UserNotification;
use App\Models\Wallet;
use App\Services\FinancialService;
use App\Services\NotificationService;
use App\Services\ProviderFinanceMailer;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

/**
 * The one-time "hediye komisyon hakkınız tamamlandı" e-mail.
 *
 * Idempotent: the wallet row is claimed with an atomic UPDATE (gift_email_sent_at), so a duplicate dispatch, a retry
 * after a worker crash or the hourly sweep can never produce a second mail. A failed send releases the claim and the
 * queue retries with a growing back-off.
 */
class SendGiftDepletedEmail implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $tries = 5;

    public array $backoff = [60, 300, 900, 3600];

    public function __construct(public int $userId) {}

    public function handle(ProviderFinanceMailer $mailer, NotificationService $notifications): void
    {
        $wallet = Wallet::where('user_id', $this->userId)->first();
        $user = User::with('providerProfile')->find($this->userId);
        if (!$wallet || !$user) {
            return;
        }

        // Only when the gift really is used up (a later credit of promo, e.g. an admin correction, cancels the notice).
        if (FinancialService::parseToCents($wallet->promo_balance) > 0) {
            return;
        }

        // In-app notice for everyone (also for accounts that have no e-mail address).
        $notifications->notifyUser(
            $user->id,
            UserNotification::TYPE_GIFT_COMMISSION_DEPLETED,
            'Hediye komisyon hakkınız tamamlandı',
            'Yeni nakit işler için İşletme Finans Merkezi\'nden komisyon bakiyesi yükleyin.',
            UserNotification::RESOURCE_COMMISSION_TOPUP,
            $user->id,
            '/barber?tab=wallet',
            [],
            "GIFT_COMMISSION_DEPLETED:{$user->id}"
        );

        if (!$user->email) {
            Log::info('Gift depleted e-mail skipped: the business has no e-mail address.', ['user_id' => $user->id]);

            return;
        }

        $claimed = Wallet::where('id', $wallet->id)->whereNull('gift_email_sent_at')->update(['gift_email_sent_at' => now()]);
        if ($claimed !== 1) {
            return; // already sent (or being sent) by another run
        }

        try {
            $mailer->sendGiftDepleted($user, $wallet->refresh());
        } catch (\Throwable $e) {
            Wallet::where('id', $wallet->id)->update(['gift_email_sent_at' => null]);
            throw $e;
        }
    }
}
