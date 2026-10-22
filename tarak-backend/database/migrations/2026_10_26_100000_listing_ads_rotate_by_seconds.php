<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * The list ad slots re-shuffle every few SECONDS (hundreds of providers can buy the slot, so a 15 minute
     * set would give almost all of them no exposure): `rotation_minutes` becomes `rotation_seconds`.
     * The cards are also presented as "Önerilen" (a recommendation), not as "Sponsorlu": the copy providers read is updated.
     */
    public function up(): void
    {
        Schema::table('featured_placement_settings', function (Blueprint $table) {
            $table->renameColumn('rotation_minutes', 'rotation_seconds');
        });

        DB::table('featured_placement_settings')->where('placement', 'listing')->update([
            'rotation_seconds' => 20,
            'description' => 'Müşteri bir hizmet için uzman ararken (randevuda "Hizmet Veren Seçimi", hizmet bazlı "Uzmanlar" ve Hizmet Verenler listeleri) profilin listenin en üstünde "Önerilen" olarak çıkar.',
            'updated_at' => now(),
        ]);
        DB::table('featured_placement_settings')->where('placement', 'home')->update(['rotation_seconds' => 0, 'updated_at' => now()]);

        DB::table('featured_packages')->where('placement', 'listing')->where('duration_days', 365)->update([
            'description' => 'Tüm yıl boyunca uzman listelerinde önerilen yer.',
            'updated_at' => now(),
        ]);
    }

    public function down(): void
    {
        Schema::table('featured_placement_settings', function (Blueprint $table) {
            $table->renameColumn('rotation_seconds', 'rotation_minutes');
        });

        DB::table('featured_placement_settings')->where('placement', 'listing')->update(['rotation_minutes' => 15]);
    }
};
