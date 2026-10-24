<?php
namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\MailSettingsApplier;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Str;

/**
 * Registration challenge is a pre-account flow: no User row or Sanctum token
 * is created until the visitor confirms possession of the email inbox.
 * OTP and final proof are short-lived, single-use and never returned to a client.
 */
class RegistrationVerificationController extends Controller
{
    public function start(Request $request, MailSettingsApplier $mailer): JsonResponse
    {
        $data = $request->validate(['email' => ['required', 'email:rfc', 'max:100']]);
        $email = mb_strtolower(trim($data['email']));
        if (\App\Models\User::where('email', $email)->exists()) {
            return response()->json(['success' => false, 'message' => 'Bu e-posta zaten kayıtlı. Lütfen giriş yapın.'], 422);
        }

        $limitKey = 'registration:cooldown:' . hash('sha256', $email);
        if (Cache::has($limitKey)) {
            return response()->json(['success' => false, 'message' => 'Yeni kod için 60 saniye bekleyin.'], 429);
        }
        $id = (string) Str::uuid();
        $code = (string) random_int(100000, 999999);
        $data = [
            'email' => $email,
            'digest' => hash_hmac('sha256', $id . ':' . $code, (string) config('app.key')),
            'attempts' => 0,
            'expires_at' => time() + 600,
        ];
        $key = 'registration:challenge:' . $id;
        Cache::put($key, $data, now()->addMinutes(10));
        Cache::put($limitKey, true, now()->addSeconds(60));

        try {
            $mailer->apply();
            Mail::raw("Tarak.app kayıt doğrulama kodunuz: {$code}\n\nKod 10 dakika geçerlidir. Bu kodu kimseyle paylaşmayın.", static function ($mail) use ($email) {
                $mail->to($email)->subject('Tarak.app – E-posta doğrulama kodu');
            });
        } catch (\Throwable $e) {
            Cache::forget($key);
            Cache::forget($limitKey);
            report($e);
            return response()->json(['success' => false, 'message' => 'Doğrulama e-postası gönderilemedi. Lütfen daha sonra tekrar deneyin.'], 503);
        }
        return response()->json([
            'success' => true,
            'message' => 'Doğrulama kodu e-postanıza gönderildi.',
            'data' => ['challenge_id' => $id, 'expires_in' => 600],
        ]);
    }

    public function confirm(Request $request): JsonResponse
    {
        $input = $request->validate([
            'challenge_id' => ['required', 'uuid'],
            'email' => ['required', 'email:rfc'],
            'code' => ['required', 'digits:6'],
        ]);
        $email = mb_strtolower(trim($input['email']));
        $id = $input['challenge_id'];
        $key = 'registration:challenge:' . $id;
        $record = Cache::get($key);
        if (!$record || !hash_equals($record['email'], $email)) {
            return response()->json(['success' => false, 'message' => 'Doğrulama isteğinin süresi doldu.'], 422);
        }
        if ($record['attempts'] >= 5) {
            Cache::forget($key);
            return response()->json(['success' => false, 'message' => 'Deneme hakkınız doldu; yeni kod isteyin.'], 429);
        }
        $record['attempts']++;
        // Preserve the original challenge TTL; never extend it on wrong codes.
        $expires = (int) ($record['expires_at'] ?? time());
        if (!hash_equals($record['digest'], hash_hmac('sha256', $id . ':' . $input['code'], (string) config('app.key')))) {
            Cache::put($key, $record, max(1, $expires - time()));
            return response()->json(['success' => false, 'message' => 'Kod geçersiz.'], 422);
        }
        Cache::forget($key);
        $proof = Str::random(64);
        Cache::put('registration:proof:' . hash('sha256', $proof), $email, now()->addMinutes(15));
        return response()->json([
            'success' => true,
            'message' => 'E-posta adresiniz doğrulandı. Kaydı tamamlayabilirsiniz.',
            'data' => ['registration_proof' => $proof],
        ]);
    }

    public static function claimProof(string $proof, string $email): bool
    {
        if ($proof === '') return false;
        $key = 'registration:proof:' . hash('sha256', $proof);
        return Cache::lock('registration:proof-lock:' . hash('sha256', $proof), 10)->block(3, static function () use ($key, $email): bool {
            $saved = Cache::get($key);
            if (!is_string($saved) || !hash_equals($saved, mb_strtolower(trim($email)))) return false;
            Cache::forget($key);
            return true;
        });
    }
}
