<?php

namespace App\Jobs;

use App\Models\User;
use App\Services\ProviderFinanceMailer;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

/** "Ödeme Bilgilerimi E-postama Gönder": the payment details go to the e-mail registered on the business account. */
class SendPaymentInstructionsEmail implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $tries = 3;

    public array $backoff = [30, 120, 600];

    public function __construct(public int $userId) {}

    public function handle(ProviderFinanceMailer $mailer): void
    {
        $user = User::find($this->userId);
        if (!$user || !$user->email) {
            return;
        }

        $mailer->sendPaymentInstructions($user);
    }
}
