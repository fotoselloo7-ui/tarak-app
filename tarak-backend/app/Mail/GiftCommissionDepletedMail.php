<?php

namespace App\Mail;

use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;

/**
 * One-time notice: the gift commission right ("İlk 500 TL komisyon Tarak.app'ten!") is used up.
 * It deliberately carries no IBAN: payment details live in the signed-in İşletme Finans Merkezi.
 */
class GiftCommissionDepletedMail extends Mailable
{
    public function __construct(
        public string $businessName,
        public array $gift,
        public array $account,
        public int $servicesCovered,
        public string $financeUrl,
        public string $logoPath,
    ) {}

    public function envelope(): Envelope
    {
        return new Envelope(subject: 'Hediye komisyon hakkınız tamamlandı · Tarak.app');
    }

    public function content(): Content
    {
        return new Content(view: 'emails.gift-depleted');
    }
}
