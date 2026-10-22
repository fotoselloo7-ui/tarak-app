<?php

namespace App\Services\Sms;

/**
 * Provider-neutral SMS contract. Adding a provider means implementing this
 * interface and registering it in SmsManager::PROVIDERS — no call-site changes.
 */
interface SmsProviderInterface
{
    /** Machine key, e.g. "netgsm". */
    public function key(): string;

    /** Human label for the admin UI. */
    public function label(): string;

    /**
     * Config validation WITHOUT contacting the provider.
     *
     * @return array{valid: bool, missing: string[]}
     */
    public function validateConfig(): array;

    /**
     * Sends one message.
     *
     * @param string $to  E.164-ish msisdn without '+', e.g. 905551112233
     * @return array{success: bool, provider_message_id: ?string, error_code: ?string, error_message: ?string, http_status: ?int}
     */
    public function send(string $to, string $message): array;
}
