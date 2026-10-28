<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\MailSettingsApplier;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use Illuminate\Validation\ValidationException;

class PasswordResetController extends Controller
{
    private const CODE_TTL_MINUTES = 10;
    private const RESEND_SECONDS = 60;
    private const MAX_ATTEMPTS = 5;

    public function forgot(Request $request, MailSettingsApplier $mailSettings): JsonResponse
    {
        $validated = $request->validate([
            'email' => ['required', 'email:rfc', 'max:100'],
        ], [
            'email.required' => 'E-posta adresinizi giriniz.',
            'email.email' => 'Geçerli bir e-posta adresi giriniz.',
        ]);

        $email = strtolower(trim($validated['email']));
        $generic = [
            'success' => true,
            'message' => 'Bu e-posta ile kayıtlı bir hesap varsa şifre yenileme kodu gönderildi.',
            'data' => ['resend_after_seconds' => self::RESEND_SECONDS],
        ];

        $user = User::whereRaw('LOWER(email) = ?', [$email])->first();
        if (!$user) {
            return response()->json($generic);
        }

        $emailHash = hash_hmac('sha256', $email, (string) config('app.key'));
        $existing = DB::table('password_reset_codes')->where('email_hash', $emailHash)->first();

        if ($existing && now()->lessThan($existing->resend_after)) {
            $remaining = max(1, now()->diffInSeconds($existing->resend_after, false));
            $generic['data']['resend_after_seconds'] = $remaining;
            return response()->json($generic);
        }

        $code = (string) random_int(100000, 999999);
        $codeHash = hash_hmac('sha256', $email.'|'.$code, (string) config('app.key'));

        DB::table('password_reset_codes')->updateOrInsert(
            ['email_hash' => $emailHash],
            [
                'code_hash' => $codeHash,
                'attempts' => 0,
                'expires_at' => now()->addMinutes(self::CODE_TTL_MINUTES),
                'resend_after' => now()->addSeconds(self::RESEND_SECONDS),
                'consumed_at' => null,
                'created_at' => $existing?->created_at ?? now(),
                'updated_at' => now(),
            ]
        );

        try {
            $mailSettings->apply();
            Mail::raw(
                "Tarak şifre yenileme kodunuz: {$code}\n\nBu kod ".self::CODE_TTL_MINUTES." dakika geçerlidir. Bu işlemi siz başlatmadıysanız mesajı yok sayabilirsiniz.",
                function ($message) use ($email) {
                    $message->to($email)->subject('Tarak Şifre Yenileme Kodu');
                }
            );
        } catch (\Throwable $e) {
            Log::error('Password reset mail could not be sent.', [
                'error_type' => get_class($e),
                'error_message' => $e->getMessage(),
            ]);
        }

        return response()->json($generic);
    }

    public function reset(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'email' => ['required', 'email:rfc', 'max:100'],
            'code' => ['required', 'digits:6'],
            'password' => ['required', 'string', 'min:8', 'confirmed'],
        ], [
            'email.required' => 'E-posta adresinizi giriniz.',
            'email.email' => 'Geçerli bir e-posta adresi giriniz.',
            'code.required' => 'Doğrulama kodunu giriniz.',
            'code.digits' => 'Doğrulama kodu 6 haneli olmalıdır.',
            'password.required' => 'Yeni şifrenizi giriniz.',
            'password.min' => 'Yeni şifre en az 8 karakter olmalıdır.',
            'password.confirmed' => 'Şifre tekrarı eşleşmiyor.',
        ]);

        $email = strtolower(trim($validated['email']));
        $emailHash = hash_hmac('sha256', $email, (string) config('app.key'));

        DB::transaction(function () use ($validated, $email, $emailHash) {
            $row = DB::table('password_reset_codes')
                ->where('email_hash', $emailHash)
                ->lockForUpdate()
                ->first();

            if (!$row || $row->consumed_at || now()->greaterThan($row->expires_at)) {
                throw ValidationException::withMessages([
                    'code' => 'Kod geçersiz veya süresi dolmuş. Yeni kod isteyiniz.',
                ]);
            }

            if ((int) $row->attempts >= self::MAX_ATTEMPTS) {
                throw ValidationException::withMessages([
                    'code' => 'Çok fazla hatalı deneme yapıldı. Yeni kod isteyiniz.',
                ]);
            }

            $expected = hash_hmac('sha256', $email.'|'.$validated['code'], (string) config('app.key'));
            if (!hash_equals((string) $row->code_hash, $expected)) {
                DB::table('password_reset_codes')->where('id', $row->id)->increment('attempts');
                throw ValidationException::withMessages([
                    'code' => 'Doğrulama kodu hatalı.',
                ]);
            }

            $user = User::whereRaw('LOWER(email) = ?', [$email])->lockForUpdate()->first();
            if (!$user) {
                throw ValidationException::withMessages([
                    'code' => 'Kod geçersiz veya süresi dolmuş. Yeni kod isteyiniz.',
                ]);
            }

            $user->forceFill(['password' => Hash::make($validated['password'])])->save();
            $user->tokens()->delete();

            DB::table('password_reset_codes')->where('id', $row->id)->update([
                'consumed_at' => now(),
                'updated_at' => now(),
            ]);
        });

        return response()->json([
            'success' => true,
            'message' => 'Şifreniz başarıyla yenilendi. Yeni şifrenizle giriş yapabilirsiniz.',
        ]);
    }
}
