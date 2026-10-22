<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\NewsletterSubscription;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class NewsletterController extends Controller
{
    /**
     * Public: subscribe an email. Idempotent; re-subscribes an unsubscribed email.
     */
    public function subscribe(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'email' => ['required', 'email', 'max:160'],
        ]);

        $email = strtolower(trim($validated['email']));

        $sub = NewsletterSubscription::query()->where('email', $email)->first();
        if ($sub) {
            if ($sub->status === NewsletterSubscription::STATUS_UNSUBSCRIBED) {
                $sub->update([
                    'status' => NewsletterSubscription::STATUS_SUBSCRIBED,
                    'unsubscribed_at' => null,
                ]);
            }

            return response()->json(['success' => true, 'message' => 'E-posta adresiniz bültenimize kayıtlı.']);
        }

        NewsletterSubscription::create([
            'email' => $email,
            'status' => NewsletterSubscription::STATUS_SUBSCRIBED,
            'unsubscribe_token' => Str::random(48),
        ]);

        return response()->json(['success' => true, 'message' => 'Bültenimize başarıyla kaydoldunuz.'], 201);
    }

    /**
     * Public: unsubscribe via token.
     */
    public function unsubscribe(string $token): JsonResponse
    {
        $sub = NewsletterSubscription::query()->where('unsubscribe_token', $token)->first();
        if (! $sub) {
            return response()->json(['success' => false, 'message' => 'Geçersiz bağlantı.'], 404);
        }

        $sub->update([
            'status' => NewsletterSubscription::STATUS_UNSUBSCRIBED,
            'unsubscribed_at' => now(),
        ]);

        return response()->json(['success' => true, 'message' => 'Bülten aboneliğiniz sonlandırıldı.']);
    }

    /**
     * Admin: list subscriptions.
     */
    public function index(Request $request): JsonResponse
    {
        $subs = NewsletterSubscription::query()
            ->when($request->query('status'), fn ($q, $s) => $q->where('status', $s))
            ->latest()
            ->limit(500)
            ->get(['id', 'email', 'status', 'created_at', 'unsubscribed_at']);

        return response()->json(['success' => true, 'data' => $subs]);
    }
}
