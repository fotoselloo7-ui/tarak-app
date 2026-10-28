<?php

namespace Tests\Feature;

use App\Http\Middleware\LocalMediaOrigin;
use Illuminate\Http\Request;
use Tests\TestCase;

class LocalMediaOriginTest extends TestCase
{
    public function test_local_snapshot_media_follows_current_origin_without_altering_other_urls(): void
    {
        $this->app->instance('env', 'local');
        $request = Request::create('http://10.0.2.2:18810/api/providers');
        $response = (new LocalMediaOrigin)->handle($request, fn () => response()->json([
            'cards' => [['avatar_url' => 'http://127.0.0.1:8010/storage/avatar.jpg']],
            'external' => 'https://tarak.app/storage/avatar.jpg',
            'other_local_url' => 'http://localhost:8010/auth/login',
            'settings' => (object) [],
        ]));
        $this->assertSame('http://10.0.2.2:18810/storage/avatar.jpg', $response->getData()->cards[0]->avatar_url);
        $this->assertSame('https://tarak.app/storage/avatar.jpg', $response->getData()->external);
        $this->assertSame('http://localhost:8010/auth/login', $response->getData()->other_local_url);
        $this->assertInstanceOf(\stdClass::class, $response->getData()->settings);
    }

    public function test_production_response_is_unchanged(): void
    {
        $this->app->instance('env', 'production');
        $response = (new LocalMediaOrigin)->handle(Request::create('/api/providers'), fn () => response()->json([
            'avatar_url' => 'http://127.0.0.1:8010/storage/avatar.jpg',
        ]));
        $this->assertSame('http://127.0.0.1:8010/storage/avatar.jpg', $response->getData()->avatar_url);
    }
}
