<?php

namespace App\Mail;

use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;

/**
 * The business asked for its commission payment details ("Ödeme Bilgilerimi E-postama Gönder").
 * Sent only to the e-mail registered on the business account.
 */
class PaymentInstructionsMail extends Mailable
{
    public function __construct(
        public array $instructions,
        public string $financeUrl,
        public string $logoPath,
    ) {}

    public function envelope(): Envelope
    {
        return new Envelope(subject: 'Komisyon ödeme bilgileriniz · Tarak.app');
    }

    public function content(): Content
    {
        return new Content(view: 'emails.payment-instructions');
    }
}
