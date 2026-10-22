<?php

namespace App\Services\Sms;

use App\Models\IntegrationEvent;
use App\Models\SmsMessage;
use App\Services\IntegrationSettings;

/**
 * Entry point for every SMS the platform sends.
 *
 * Responsibilities: provider resolution, TR phone normalisation, per-event
 * enable/disable gating, and delivery logging (masked recipient, never the
 * message body — OTP codes must not be recoverable from the log).
 */
class SmsManager
{
    /** Registered providers, keyed by their machine key. */
    public const PROVIDERS = [
        'netgsm' => NetgsmProvider::class,
        'vatansms' => VatanSmsProvider::class,
    ];

    /**
     * Transactional template keys wired to real domain events.
     * `{{placeholders}}` are filled by the caller through $params.
     */
    public const TEMPLATES = [
        'otp' => 'Tarak doğrulama kodunuz: {{code}}. Kodu kimseyle paylaşmayın.',
        'appointment_created' => 'Randevu talebiniz alındı. Hizmet veren onayı bekleniyor. Tarak',
        'appointment_confirmed' => 'Randevunuz onaylandı: {{date}} {{time}}. Tarak',
        'appointment_rejected' => 'Randevu talebiniz hizmet veren tarafından kabul edilmedi. Tarak',
        'appointment_cancelled' => 'Randevunuz iptal edildi. Detaylar uygulamada. Tarak',
        'direct_request_created' => 'Hizmet talebiniz oluşturuldu, uzmanlar bilgilendirildi. Tarak',
        'provider_accepted' => 'Talebiniz kabul edildi, uzman yola çıkmak üzere. Tarak',
        'service_started' => 'Hizmetiniz başladı. İyi bakımlar dileriz. Tarak',
        'service_completed' => 'Hizmetiniz tamamlandı. Değerlendirmenizi bekliyoruz. Tarak',
        'dispute_opened' => 'Bildiriminiz alındı, ekibimiz inceliyor. Tarak',
        'admin_test' => 'Tarak SMS bağlantı testi. Bu mesaj yöneticiniz tarafından gönderildi.',
    ];

    public function __construct(private IntegrationSettings $settings)
    {
    }

    public function isEnabled(): bool
    {
        return $this->settings->isEnabled('sms', 'enabled');
    }

    public function providerKey(): string
    {
        $key = (string) $this->settings->get('sms', 'provider', 'netgsm');

        return isset(self::PROVIDERS[$key]) ? $key : 'netgsm';
    }

    public function provider(): SmsProviderInterface
    {
        return app(self::PROVIDERS[$this->providerKey()]);
    }

    /** @return array{valid: bool, missing: string[]} */
    public function validateConfig(): array
    {
        return $this->provider()->validateConfig();
    }

    /**
     * Is this domain event allowed to send SMS? Defaults to OFF so enabling
     * the provider never causes a surprise notification storm alongside the
     * existing push/e-mail channels.
     */
    public function isEventEnabled(string $templateKey): bool
    {
        return $this->settings->isEnabled('sms_events', $templateKey, false);
    }

    /**
     * Renders a template and sends it, respecting the per-event switch.
     *
     * @return array{sent: bool, reason?: string, log_id?: int}
     */
    public function sendTemplate(string $templateKey, string $rawPhone, array $params = [], ?int $userId = null): array
    {
        if (!isset(self::TEMPLATES[$templateKey])) {
            return ['sent' => false, 'reason' => 'unknown_template'];
        }

        if (!$this->isEventEnabled($templateKey)) {
            return ['sent' => false, 'reason' => 'event_disabled'];
        }

        $message = self::TEMPLATES[$templateKey];
        foreach ($params as $k => $v) {
            $message = str_replace('{{' . $k . '}}', (string) $v, $message);
        }

        return $this->send($rawPhone, $message, $templateKey, $userId);
    }

    /**
     * Sends a message through the active provider and logs the attempt.
     *
     * @return array{sent: bool, reason?: string, error?: ?string, log_id?: int, provider?: string}
     */
    public function send(string $rawPhone, string $message, string $templateKey = 'custom', ?int $userId = null): array
    {
        if (!$this->isEnabled()) {
            return ['sent' => false, 'reason' => 'sms_disabled'];
        }

        $config = $this->validateConfig();
        if (!$config['valid']) {
            return ['sent' => false, 'reason' => 'not_configured', 'error' => implode(', ', $config['missing'])];
        }

        $msisdn = self::normalizePhone($rawPhone, (string) $this->settings->get('sms', 'default_country', '90'));
        if ($msisdn === null) {
            return ['sent' => false, 'reason' => 'invalid_phone'];
        }

        $provider = $this->provider();
        $result = $provider->send($msisdn, $message);

        $log = SmsMessage::create([
            'provider' => $provider->key(),
            'recipient_masked' => self::maskPhone($msisdn),
            'recipient_hash' => hash('sha256', $msisdn),
            'template_key' => $templateKey,
            'status' => $result['success'] ? SmsMessage::STATUS_SENT : SmsMessage::STATUS_FAILED,
            'provider_message_id' => $result['provider_message_id'],
            'error_code' => $result['error_code'],
            'error_message' => IntegrationEvent::sanitise($result['error_message']),
            'user_id' => $userId,
            'sent_at' => $result['success'] ? now() : null,
        ]);

        IntegrationEvent::record(
            integration: 'sms',
            eventType: 'send:' . $templateKey,
            direction: 'outbound',
            status: $result['success'] ? IntegrationEvent::STATUS_SUCCESS : IntegrationEvent::STATUS_FAILED,
            reference: $result['provider_message_id'],
            httpStatus: $result['http_status'],
            errorCode: $result['error_code'],
            errorMessage: $result['error_message'],
        );

        return [
            'sent' => $result['success'],
            'provider' => $provider->key(),
            'error' => $result['error_message'],
            'log_id' => $log->id,
        ];
    }

    /**
     * Normalises Turkish numbers to msisdn form (905551112233).
     * Accepts 05551112233 / 5551112233 / +905551112233 / 905551112233.
     */
    public static function normalizePhone(string $raw, string $countryCode = '90'): ?string
    {
        $digits = preg_replace('/\D+/', '', $raw) ?? '';

        if ($digits === '') {
            return null;
        }

        // Strip a leading trunk zero (0555...) before prefixing the country code.
        if (str_starts_with($digits, '0')) {
            $digits = ltrim($digits, '0');
        }

        if (!str_starts_with($digits, $countryCode)) {
            $digits = $countryCode . $digits;
        }

        // TR msisdn is exactly 12 digits (90 + 10). Reject anything else rather
        // than silently sending to a malformed number.
        if ($countryCode === '90' && strlen($digits) !== 12) {
            return null;
        }

        return strlen($digits) >= 11 && strlen($digits) <= 15 ? $digits : null;
    }

    /** 905551112233 -> 9055****2233 */
    public static function maskPhone(string $msisdn): string
    {
        if (strlen($msisdn) <= 8) {
            return str_repeat('*', strlen($msisdn));
        }

        return substr($msisdn, 0, 4) . str_repeat('*', strlen($msisdn) - 8) . substr($msisdn, -4);
    }
}
