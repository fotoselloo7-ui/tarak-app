<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * users.avatar_url becomes the single canonical avatar field for ALL
     * roles (customer, provider, admin). customer_profiles.avatar_url is
     * left in place (not dropped, to avoid destructive schema changes on
     * an existing DB) but is no longer read at runtime after this migration.
     */
    private const DEMO_URL_PATTERNS = [
        'dicebear.com',
        'randomuser.me',
        'replit',
        'ui-avatars.com',
        'unsplash.com',
        'placeholder',
        'placehold.co',
        'placeimg.com',
        'via.placeholder.com',
        'pravatar.cc',
        'lorempixel',
        'picsum.photos',
    ];

    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('avatar_url', 500)->nullable()->after('gender');
        });

        // Backfill: migrate ONLY real, non-demo customer avatars. Anything
        // matching a known demo/placeholder host is left null rather than
        // carried forward as if it were a real user photo.
        $rows = DB::table('customer_profiles')
            ->whereNotNull('avatar_url')
            ->where('avatar_url', '!=', '')
            ->get(['user_id', 'avatar_url']);

        foreach ($rows as $row) {
            $needle = strtolower($row->avatar_url);
            $isDemo = false;
            foreach (self::DEMO_URL_PATTERNS as $pattern) {
                if (str_contains($needle, $pattern)) {
                    $isDemo = true;
                    break;
                }
            }
            if (!$isDemo) {
                DB::table('users')->where('id', $row->user_id)->update(['avatar_url' => $row->avatar_url]);
            }
        }
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('avatar_url');
        });
    }
};
