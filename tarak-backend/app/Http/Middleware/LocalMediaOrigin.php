<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class LocalMediaOrigin
{
    public function handle(Request $request, Closure $next): mixed
    {
        $response = $next($request);
        if (!app()->environment('local') || !$response instanceof JsonResponse) {
            return $response;
        }

        // Existing local snapshots contain the previous server's media origin.
        // Adapt only the response; never rewrite the stored photos or URLs.
        $origin = $request->getSchemeAndHttpHost();
        $walk = function (mixed $value) use (&$walk, $origin): mixed {
            if (is_string($value)) {
                return preg_replace('~^http://(?:127\.0\.0\.1|localhost)(?::\d+)?(?=/(?:storage|demo-media)/)~', $origin, $value);
            }
            if (is_array($value)) return array_map($walk, $value);
            if ($value instanceof \stdClass) {
                foreach ($value as $key => $child) $value->$key = $walk($child);
            }
            return $value;
        };
        $response->setData($walk($response->getData()));
        return $response;
    }
}
