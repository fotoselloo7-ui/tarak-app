<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * "Öne çıkarma" learns about WHERE a provider is promoted. Every package, purchase and order now
     * belongs to a placement: `home` (the homepage "Öne Çıkan Profesyoneller" showcase, all existing rows)
     * or `listing` (sponsored slots at the top of every provider list: appointment provider step,
     * "Uzmanlar" per service, the Hizmet Verenler lists). Each placement has its own packages / prices,
     * its own purchase queue per provider and its own admin settings.
     */
    public function up(): void
    {
        foreach (['featured_packages', 'featured_promotions', 'featured_orders'] as $table) {
            Schema::table($table, function (Blueprint $blueprint) use ($table) {
                $blueprint->string('placement', 20)->default('home')->after($table === 'featured_packages' ? 'id' : 'provider_user_id')->index();
            });
        }

        Schema::create('featured_placement_settings', function (Blueprint $table) {
            $table->id();
            $table->string('placement', 20)->unique();
            $table->boolean('is_enabled')->default(true);          // false = new purchases are closed for this placement
            $table->unsignedTinyInteger('slots')->default(3);      // listing: how many sponsored cards a list shows at once
            $table->unsignedSmallInteger('rotation_minutes')->default(15); // listing: how often the sponsored set re-shuffles
            $table->string('title', 80);
            $table->string('description', 400)->nullable();
            $table->timestamps();
        });

        $now = now();
        DB::table('featured_placement_settings')->insert([
            ['placement' => 'home', 'is_enabled' => true, 'slots' => 6, 'rotation_minutes' => 0, 'title' => 'Ana Sayfa Vitrini',
                'description' => 'Profilin ana sayfadaki "Öne Çıkan Profesyoneller" bölümünde, kategorilerin hemen altında yer alır. Tüm ziyaretçiler görür; kartlar sırayla döner.',
                'created_at' => $now, 'updated_at' => $now],
            ['placement' => 'listing', 'is_enabled' => true, 'slots' => 3, 'rotation_minutes' => 15, 'title' => 'Liste Reklamı',
                'description' => 'Müşteri bir hizmet için uzman ararken (randevuda "Hizmet Veren Seçimi", hizmet bazlı "Uzmanlar" ve Hizmet Verenler listeleri) profilin listenin en üstünde "Sponsorlu" etiketiyle çıkar.',
                'created_at' => $now, 'updated_at' => $now],
        ]);

        // Same durations as the homepage packages; the price is the admin's to change.
        DB::table('featured_packages')->insert([
            ['placement' => 'listing', 'name' => '1 Gün', 'description' => 'Bir gün boyunca uzman listelerinin en üstünde.', 'badge' => null, 'duration_days' => 1, 'price' => 79, 'is_active' => true, 'sort_order' => 1, 'created_at' => $now, 'updated_at' => $now],
            ['placement' => 'listing', 'name' => '7 Gün', 'description' => 'Bir hafta boyunca listelerin en üstünde kal.', 'badge' => null, 'duration_days' => 7, 'price' => 399, 'is_active' => true, 'sort_order' => 2, 'created_at' => $now, 'updated_at' => $now],
            ['placement' => 'listing', 'name' => '30 Gün', 'description' => 'Bir ay boyunca aramalarda sürekli görün.', 'badge' => 'En popüler', 'duration_days' => 30, 'price' => 1199, 'is_active' => true, 'sort_order' => 3, 'created_at' => $now, 'updated_at' => $now],
            ['placement' => 'listing', 'name' => '1 Yıl', 'description' => 'Tüm yıl boyunca uzman listelerinde sponsorlu yer.', 'badge' => 'En avantajlı', 'duration_days' => 365, 'price' => 9599, 'is_active' => true, 'sort_order' => 4, 'created_at' => $now, 'updated_at' => $now],
        ]);
    }

    public function down(): void
    {
        DB::table('featured_packages')->where('placement', 'listing')->delete();
        Schema::dropIfExists('featured_placement_settings');
        foreach (['featured_packages', 'featured_promotions', 'featured_orders'] as $table) {
            Schema::table($table, function (Blueprint $blueprint) {
                $blueprint->dropIndex(['placement']);
                $blueprint->dropColumn('placement');
            });
        }
    }
};
