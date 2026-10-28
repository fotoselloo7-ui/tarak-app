<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\RegistrationVerificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class RegistrationVerificationController extends Controller
{
    public function __construct(private RegistrationVerificationService $verification) {}

    public function config(): JsonResponse
    {
        return response()->json([
            'success' => true,
            'data' => [
                'sms_enabled' => $this->verification->isSmsVerificationEnabled(),
            ],
        ])->header('Cache-Control', 'no-store');
    }

    public function send(Request $request, string $channel): JsonResponse
    {
        $field = $channel === 'email' ? 'email' : 'phone';
        $validated = $request->validate([$field => ['required', 'string', 'max:255']]);
        $destination = $this->verification->normalize($channel, $validated[$field]);
        $result = $this->verification->send($channel, $destination);

        return response()->json([
            'success' => true,
            'message' => 'Doğrulama kodu gönderildi.',
            'data' => $result,
        ]);
    }

    public function confirm(Request $request, string $channel): JsonResponse
    {
        $field = $channel === 'email' ? 'email' : 'phone';
        $validated = $request->validate([
            $field => ['required', 'string', 'max:255'],
            'code' => ['required', 'regex:/^\d{6}$/'],
        ]);
        $destination = $this->verification->normalize($channel, $validated[$field]);
        $proof = $this->verification->confirm($channel, $destination, $validated['code']);

        return response()->json([
            'success' => true,
            'message' => 'İletişim bilgisi doğrulandı.',
            'data' => ['verification_token' => $proof],
        ]);
    }
}
