<?php

namespace App\Services;

use App\Mail\GiftCommissionDepletedMail;
use App\Mail\PaymentInstructionsMail;
use App\Models\IntegrationEvent;
use App\Models\User;
use App\Models\Wallet;
use App\Models\WalletTransaction;
use Illuminate\Support\Facades\Mail;

/**
 * Business e-mails of the commission flow (gift used up, payment details on request).
 * Sends through the configured mailer with the admin-panel SMTP values applied; every attempt is recorded in the
 * Integration Center so a failing mail server shows up there. Callers are queue jobs, so a thrown exception means retry.
 */
class ProviderFinanceMailer
{
    public function __construct(
        protected MailSettingsApplier $mailSettings,
        protected FinancialService $financial,
        protected CommissionTopupService $topups,
    ) {}

    public function sendGiftDepleted(User $user, Wallet $wallet): void
    {
        $summary = $this->financial->getProviderFinancialSummary($user->id);
        $profile = $user->providerProfile;

        $servicesCovered = WalletTransaction::where('wallet_id', $wallet->id)
            ->where('type', WalletTransaction::TYPE_COMMISSION_CAPTURE_PROMO)
            ->count();

        $mail = new GiftCommissionDepletedMail(
            businessName: $profile?->business_name ?: $user->name,
            gift: $summary['gift'],
            account: $summary,
            servicesCovered: $servicesCovered,
            financeUrl: $this->financeUrl(),
            logoPath: $this->logoPath(),
        );

        $this->deliver($user, $mail, 'gift_depleted_email');
    }

    public function sendPaymentInstructions(User $user): void
    {
        $mail = new PaymentInstructionsMail(
            instructions: $this->topups->paymentInstructions($user),
            financeUrl: $this->financeUrl(),
            logoPath: $this->logoPath(),
        );

        $this->deliver($user, $mail, 'payment_info_email');
    }

    private function deliver(User $user, \Illuminate\Mail\Mailable $mail, string $eventType): void
    {
        $this->mailSettings->apply();

        try {
            Mail::to($user->email)->send($mail);
        } catch (\Throwable $e) {
            IntegrationEvent::record(
                integration: 'smtp',
                eventType: $eventType,
                direction: 'outbound',
                status: IntegrationEvent::STATUS_FAILED,
                reference: 'user:' . $user->id,
                errorMessage: $e->getMessage(),
            );
            throw $e;
        }

        IntegrationEvent::record(
            integration: 'smtp',
            eventType: $eventType,
            direction: 'outbound',
            status: IntegrationEvent::STATUS_SUCCESS,
            reference: 'user:' . $user->id,
        );
    }

    /** The signed-in finance center of the web app (the page asks the business to log in first). */
    public function financeUrl(): string
    {
        return rtrim((string) config('app.url'), '/') . '/barber?tab=wallet';
    }

    /** The brand logo shipped with the backend (a copy of the web app's public/brand/tarak-logo-header.png). */
    public function logoPath(): string
    {
        return resource_path('brand/tarak-logo.png');
    }
}
