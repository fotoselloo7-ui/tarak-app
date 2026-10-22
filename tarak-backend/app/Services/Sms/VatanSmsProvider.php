<?php

namespace App\Services\Sms;

use App\Services\IntegrationSettings;
use Illuminate\Support\Facades\Http;

/**
 * VatanSMS JSON API (https://api.vatansms.net/api/v1/1toN).
 * Second provider proving the layer is genuinely provider-neutral.
 *
 * Credential mapping: username -> api_id, password -> api_key.
 */
class VatanSmsProvider implements SmsProviderInterface
{
    private const ENDPOINT = 'https://api.vatansms.net/api/v1/1toN';

    public function __construct(private IntegrationSettings $settings)
    {
    }

    public function key(): string
    {
        return 'vatansms';
    }

    public function label(): string
    {
        return 'VatanSMS';
    }

    public function validateConfig(): array
    {
        $missing = [];
        foreach (['username' => 'API ID', 'password' => 'API Key', 'sender_title' => 'Gönderici başlığı'] as $key => $label) {
            if (!$this->settings->isConfigured('sms', $key)) {
                $missing[] = $label;
            }
        }

        return ['valid' => $missing === [], 'missing' => $missing];
    }

    public function send(string $to, string $message): array
    {
        try {
            $response = Http::timeout(15)->acceptJson()->post(self::ENDPOINT, [
                'api_id' => (string) $this->settings->get('sms', 'username'),
                'api_key' => (string) $this->settings->get('sms', 'password'),
                'sender' => (string) $this->settings->get('sms', 'sender_title'),
                'message_type' => 'normal',
                'message' => $message,
                'phones' => [$to],
            ]);

            $status = $response->json('status');
            $ok = $response->successful()
                && ($status === 'success' || $status === true || $response->json('report_id') !== null);

            if ($ok) {
                $reportId = $response->json('report_id') ?? $response->json('data.report_id');

                return [
                    'success' => true,
                    'provider_message_id' => $reportId !== null ? (string) $reportId : null,
                    'error_code' => null,
                    'error_message' => null,
                    'http_status' => $response->status(),
                ];
            }

            return [
                'success' => false,
                'provider_message_id' => null,
                'error_code' => (string) ($response->json('code') ?? $response->status()),
                'error_message' => (string) ($response->json('message') ?? 'VatanSMS gönderimi reddetti.'),
                'http_status' => $response->status(),
            ];
        } catch (\Throwable $e) {
            return [
                'success' => false,
                'provider_message_id' => null,
                'error_code' => 'TRANSPORT',
                'error_message' => 'VatanSMS servisine ulaşılamadı: ' . $e->getMessage(),
                'http_status' => null,
            ];
        }
    }
}
