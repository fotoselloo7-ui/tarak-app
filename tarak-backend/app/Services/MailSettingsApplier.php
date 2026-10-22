<?php

namespace App\Services;

use Illuminate\Support\Facades\Mail;

/**
 * Puts the SMTP values saved in Admin → Entegrasyon Merkezi → SMTP on top of the .env mailer config right before a
 * business e-mail is sent ("DB value wins over .env", see IntegrationSettings). Nothing changes when the app runs
 * with a non-SMTP mailer (log / array), so local development and tests never talk to a real mail server.
 */
class MailSettingsApplier
{
    public function __construct(protected IntegrationSettings $settings) {}

    public function apply(): void
    {
        try {
            if (config('mail.default') !== 'smtp') {
                return;
            }

            $host = (string) $this->settings->get('smtp', 'host', '');
            if ($host !== '') {
                config(['mail.mailers.smtp.host' => $host]);
            }

            $port = $this->settings->get('smtp', 'port');
            if ($port !== null && $port !== '') {
                config(['mail.mailers.smtp.port' => (int) $port]);
            }

            foreach (['username', 'password'] as $key) {
                $value = $this->settings->get('smtp', $key);
                if ($value !== null && $value !== '') {
                    config(["mail.mailers.smtp.{$key}" => (string) $value]);
                }
            }

            $encryption = strtolower((string) $this->settings->get('smtp', 'encryption', ''));
            if ($encryption !== '') {
                // Laravel 11 speaks "smtps" (implicit TLS, port 465); STARTTLS (587) is the default with no scheme.
                config(['mail.mailers.smtp.scheme' => in_array($encryption, ['ssl', 'smtps'], true) ? 'smtps' : null]);
            }

            $fromAddress = (string) $this->settings->get('smtp', 'from_address', '');
            if ($fromAddress !== '') {
                config(['mail.from.address' => $fromAddress]);
            }
            $fromName = (string) $this->settings->get('smtp', 'from_name', '');
            if ($fromName !== '') {
                config(['mail.from.name' => $fromName]);
            }

            // The mailer instance is cached after first use; rebuild it with the values above.
            Mail::forgetMailers();
        } catch (\Throwable $e) {
            // Settings table unreachable / not migrated yet: send with whatever .env provides.
        }
    }
}
