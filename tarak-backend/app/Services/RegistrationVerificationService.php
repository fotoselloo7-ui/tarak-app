<?php

namespace App\Services;

use App\Models\User;
use App\Services\Sms\SmsManager;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Mail;
use Illuminate\Validation\ValidationException;

class RegistrationVerificationService
{
    private const TTL_MINUTES = 10;
    private const RESEND_SECONDS = 60;
    private const MAX_ATTEMPTS = 5;

    public function __construct(
        private SmsManager $sms,
        private MailSettingsApplier $mailSettings,
    ) {}

    public function isSmsVerificationEnabled(): bool
    {
        if (!config('services.registration.sms_verification_enabled', false)) {
            return false;
        }

        if (!$this->sms->isEnabled() || !$this->sms->isEventEnabled('otp')) {
            return false;
        }

        try {
            $config = $this->sms->validateConfig();

            return (bool) ($config['valid'] ?? false);
        } catch (\Throwable) {
            return false;
        }
    }

    public function normalize(string $channel, string $value): string
    {
        $destination = $channel === 'email'
            ? User::normalizeEmail($value)
            : User::normalizePhone($value);

        if (!$destination || ($channel === 'sms' && !preg_match('/^\+905\d{9}$/', $destination))) {
            throw ValidationException::withMessages(['destination' => 'Geçerli bir e-posta adresi veya cep telefonu giriniz.']);
        }

        return $destination;
    }

    public function send(string $channel, string $destination): array
    {
        $destinationHash = $this->destinationHash($channel, $destination);
        $existing = DB::table('registration_verifications')
            ->where('channel', $channel)->where('destination_hash', $destinationHash)->first();

        if ($existing && now()->lessThan($existing->resend_after)) {
            throw ValidationException::withMessages(['destination' => 'Yeni kod istemek için 60 saniye bekleyiniz.']);
        }

        if ($channel === 'sms' && (!$this->sms->isEnabled() || !$this->sms->isEventEnabled('otp'))) {
            throw ValidationException::withMessages(['destination' => 'SMS doğrulaması yönetici tarafından henüz etkinleştirilmedi.']);
        }

        if ($channel === 'email' && config('app.env') === 'production' && in_array(config('mail.default'), ['log', 'array'], true)) {
            throw ValidationException::withMessages(['destination' => 'E-posta gönderimi yapılandırılmadı.']);
        }

        $code = (string) random_int(100000, 999999);
        $attributes = [
            'code_hash' => $this->digest($code),
            'proof_hash' => null,
            'attempts' => 0,
            'expires_at' => now()->addMinutes(self::TTL_MINUTES),
            'resend_after' => now()->addSeconds(self::RESEND_SECONDS),
            'verified_at' => null,
            'consumed_at' => null,
            'updated_at' => now(),
        ];
        DB::table('registration_verifications')->updateOrInsert(
            ['channel' => $channel, 'destination_hash' => $destinationHash],
            $attributes + ['created_at' => now()],
        );

        try {
            if ($channel === 'email') {
                $this->mailSettings->apply();
                Mail::raw("Tarak kayıt doğrulama kodunuz: {$code}. Kod 10 dakika geçerlidir. Kodu kimseyle paylaşmayın.",
                    fn ($message) => $message->to($destination)->subject('Tarak e-posta doğrulama kodu'));
            } else {
                $result = $this->sms->sendTemplate('otp', $destination, ['code' => $code]);
                if (!($result['sent'] ?? false)) {
                    $reason = ($result['reason'] ?? '') === 'not_configured'
                        ? 'SMS sağlayıcısı yapılandırılmadı.'
                        : 'SMS kodu gönderilemedi. Sağlayıcı ayarlarını kontrol ediniz.';
                    throw ValidationException::withMessages(['destination' => $reason]);
                }
            }
        } catch (\Throwable $exception) {
            DB::table('registration_verifications')
                ->where('channel', $channel)
                ->where('destination_hash', $destinationHash)
                ->where('code_hash', $attributes['code_hash'])->delete();
            if ($exception instanceof ValidationException) {
                throw $exception;
            }
            report($exception);
            throw ValidationException::withMessages(['destination' => 'Doğrulama kodu gönderilemedi. Lütfen daha sonra deneyiniz.']);
        }

        return [
            'expires_in_seconds' => self::TTL_MINUTES * 60,
            'resend_after_seconds' => self::RESEND_SECONDS,
        ];
    }

    public function confirm(string $channel, string $destination, string $code): string
    {
        $result = DB::transaction(function () use ($channel, $destination, $code): ?string {
            $challenge = DB::table('registration_verifications')
                ->where('channel', $channel)
                ->where('destination_hash', $this->destinationHash($channel, $destination))
                ->lockForUpdate()->first();

            if (!$challenge || $challenge->consumed_at || now()->greaterThan($challenge->expires_at)
                || $challenge->attempts >= self::MAX_ATTEMPTS) {
                throw ValidationException::withMessages(['code' => 'Kodun süresi doldu veya deneme sınırı aşıldı. Yeni kod isteyiniz.']);
            }

            if (!hash_equals($challenge->code_hash, $this->digest($code))) {
                DB::table('registration_verifications')->where('id', $challenge->id)
                    ->update(['attempts' => $challenge->attempts + 1, 'updated_at' => now()]);
                return null;
            }

            $proof = bin2hex(random_bytes(32));
            DB::table('registration_verifications')->where('id', $challenge->id)->update([
                'proof_hash' => $this->digest($proof),
                'verified_at' => now(),
                'updated_at' => now(),
            ]);

            return $proof;
        });

        if ($result === null) {
            throw ValidationException::withMessages(['code' => 'Doğrulama kodu hatalı.']);
        }

        return $result;
    }

    /** Must be called inside the account-creation transaction. */
    public function consume(string $channel, string $destination, ?string $proof): void
    {
        $challenge = DB::table('registration_verifications')
            ->where('channel', $channel)
            ->where('destination_hash', $this->destinationHash($channel, $destination))
            ->lockForUpdate()->first();

        if (!$proof || !$challenge || !$challenge->verified_at || $challenge->consumed_at
            || now()->greaterThan($challenge->expires_at)
            || !hash_equals((string) $challenge->proof_hash, $this->digest($proof))) {
            throw ValidationException::withMessages([$channel === 'email' ? 'email' : 'phone' => 'Bu iletişim bilgisini doğrulayınız.']);
        }

        DB::table('registration_verifications')->where('id', $challenge->id)
            ->update(['consumed_at' => now(), 'updated_at' => now()]);
    }

    private function destinationHash(string $channel, string $destination): string
    {
        return $this->digest($channel . ':' . $destination);
    }

    private function digest(string $value): string
    {
        return hash_hmac('sha256', $value, (string) config('app.key'));
    }
}
