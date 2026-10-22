<?php

namespace App\Console\Commands;

use App\Jobs\SendGiftDepletedEmail;
use App\Models\Wallet;
use Illuminate\Console\Command;

/**
 * Safety net for the "hediye komisyon hakkı tamamlandı" e-mail: re-queues businesses whose gift ran out but whose
 * mail never went out (mail server was down, worker stopped). The job itself is idempotent, so running this is safe.
 */
class NotifyDepletedGiftCommand extends Command
{
    protected $signature = 'finance:notify-gift-depleted';

    protected $description = 'Queue the one-time "gift commission used up" e-mail for businesses that did not get it yet';

    public function handle(): int
    {
        $count = 0;

        Wallet::whereNotNull('gift_depleted_at')
            ->whereNull('gift_email_sent_at')
            ->where('promo_balance', '<=', 0)
            ->whereHas('user', fn ($q) => $q->whereNotNull('email'))
            ->orderBy('id')
            ->chunkById(100, function ($wallets) use (&$count) {
                foreach ($wallets as $wallet) {
                    SendGiftDepletedEmail::dispatch((int) $wallet->user_id);
                    $count++;
                }
            });

        $this->info("Queued {$count} gift-depleted e-mail(s).");

        return self::SUCCESS;
    }
}
