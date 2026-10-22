<?php

namespace App\Services\Sms;

use App\Services\IntegrationSettings;
use Illuminate\Support\Facades\Http;

/**
 * Netgsm REST v2 (https://api.netgsm.com.tr/sms/rest/v2/send).
 * Credentials are read through IntegrationSettings and never logged.
 */
class NetgsmProvider implements SmsProviderInterface
{
    private const ENDPOINT = 'https://api.netgsm.com.tr/sms/rest/v2/send';

    /** Netgsm returns "00"/"01"/"02" for accepted jobs; everything else is an error. */
    private const SUCCESS_CODES = ['00', '01', '02'];

    private const ERROR_MESSAGES = [
        '20' => 'Mesaj metni hatalı veya karakter limiti aşıldı.',
        '30' => 'Geçersiz kullanıcı adı/şifre veya API erişim izni yok.',
        '40' => 'Mesaj başlığı (gönderici adı) sistemde tanımlı değil.',
        '50' => 'Abone hesabı IYS kontrollü gönderime uygun değil.',
        '51' => 'IYS marka bilgisi bulunamadı.',
        '70' => 'Hatalı sorgulama; parametreleri kontrol edin.',
        '80' => 'Gönderim sınırı aşıldı.',
        '85' => 'Mükerrer gönderim sınırı aşıldı.',
    ];

    public function __construct(private IntegrationSettings $settings)
    {
    }

    public function key(): string
    {
        return 'netgsm';
    }

    public function label(): string
    {
        return 'Netgsm';
    }

    public function validateConfig(): array
    {
        $missing = [];
        foreach (['username' => 'Kullanıcı adı', 'password' => 'Şifre', 'sender_title' => 'Gönderici başlığı'] as $key => $label) {
            if (!$this->settings->isConfigured('sms', $key)) {
                $missing[] = $label;
            }
        }

        return ['valid' => $missing === [], 'missing' => $missing];
    }

    public function send(string $to, string $message): array
    {
        $username = (string) $this->settings->get('sms', 'username');
        $password = (string) $this->settings->get('sms', 'password');
        $header = (string) $this->settings->get('sms', 'sender_title');

        try {
            $response = Http::timeout(15)
                ->withBasicAuth($username, $password)
                ->acceptJson()
                ->post(self::ENDPOINT, [
                    'msgheader' => $header,
                    'encoding' => 'TR',
                    'messages' => [
                        ['msg' => $message, 'no' => $to],
                    ],
                ]);

            $code = (string) ($response->json('code') ?? '');
            $jobId = $response->json('jobid');

            if ($response->successful() && in_array($code, self::SUCCESS_CODES, true)) {
                return [
                    'success' => true,
                    'provider_message_id' => $jobId ? (string) $jobId : null,
                    'error_code' => null,
                    'error_message' => null,
                    'http_status' => $response->status(),
                ];
            }

            return [
                'success' => false,
                'provider_message_id' => null,
                'error_code' => $code !== '' ? $code : (string) $response->status(),
                'error_message' => self::ERROR_MESSAGES[$code] ?? 'Netgsm gönderimi reddetti (kod: ' . ($code ?: $response->status()) . ').',
                'http_status' => $response->status(),
            ];
        } catch (\Throwable $e) {
            return [
                'success' => false,
                'provider_message_id' => null,
                'error_code' => 'TRANSPORT',
                'error_message' => 'Netgsm servisine ulaşılamadı: ' . $e->getMessage(),
                'http_status' => null,
            ];
        }
    }
}
