<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Support\MediaUrl;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\HttpFoundation\BinaryFileResponse;

class PublicMediaController extends Controller
{
    public function show(string $path): BinaryFileResponse
    {
        $managedPath = MediaUrl::managedPublicPath('/api/media/' . ltrim($path, '/'));
        abort_if($managedPath === null, 404);

        $disk = Storage::disk('public');
        abort_unless($disk->exists($managedPath), 404);

        return response()->file($disk->path($managedPath), [
            'Cache-Control' => 'public, max-age=604800',
            'X-Content-Type-Options' => 'nosniff',
        ]);
    }
}
