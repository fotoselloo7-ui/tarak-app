<?php

namespace Tests\Feature;

use Tests\TestCase;

class TestIsolationTest extends TestCase
{
    public function test_database_refresh_can_only_target_memory(): void
    {
        $this->assertSame('testing', config('app.env'));
        $this->assertSame('sqlite', config('database.default'));
        $this->assertSame(':memory:', config('database.connections.sqlite.database'));
    }
}
