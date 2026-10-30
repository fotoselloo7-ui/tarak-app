<?php

use Illuminate\Auth\AuthenticationException;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        channels: __DIR__.'/../routes/channels.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware) {
        $middleware->append(\App\Http\Middleware\LocalMediaOrigin::class);
        $middleware->alias([
            'role' => \App\Http\Middleware\RoleMiddleware::class,
        ]);
        $middleware->redirectGuestsTo(fn (Request $request) => null);
    })
    ->withExceptions(function (Exceptions $exceptions) {
        $exceptions->render(function (AuthenticationException $e, Request $request) {
            if ($request->is('api/*') || $request->expectsJson()) {
                return response()->json([
                    'success' => false,
                    'message' => 'Yetkilendirme gerekli.',
                ], 401);
            }
        });

        $exceptions->render(function (\Symfony\Component\HttpKernel\Exception\TooManyRequestsHttpException $e, Request $request) {
            if ($request->is('api/*') || $request->expectsJson()) {
                $headers = $e->getHeaders();
                $seconds = max(1, (int) ($headers['Retry-After'] ?? 60));
                return response()->json([
                    'success' => false,
                    'message' => "Çok fazla deneme yapıldı. {$seconds} saniye sonra tekrar deneyin.",
                    'retry_after_seconds' => $seconds,
                ], 429, $headers);
            }
        });

        // Production API Error Leak Prevention: Never leak SQL, file paths, env, or stack traces in production
        $exceptions->render(function (\Throwable $e, Request $request) {
            if (($request->is('api/*') || $request->expectsJson()) && !config('app.debug')) {
                if ($e instanceof \Illuminate\Validation\ValidationException) {
                    return null; // Standard 422 validation response preserved
                }

                $statusCode = 500;
                if ($e instanceof \Symfony\Component\HttpKernel\Exception\HttpExceptionInterface) {
                    $statusCode = $e->getStatusCode();
                }

                $message = $statusCode === 500
                    ? 'Sunucu hatası oluştu. Lütfen daha sonra tekrar deneyiniz.'
                    : ($e->getMessage() ?: 'İşlem gerçekleştirilemedi.');

                return response()->json([
                    'success' => false,
                    'message' => $message,
                ], $statusCode);
            }
        });
    })->create();
