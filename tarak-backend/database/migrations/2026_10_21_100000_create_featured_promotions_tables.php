<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Admin-priced "öne çıkarma" packages (1 day, 7 days, 30 days, 1 year, ...).
        Schema::create('featured_packages', function (Blueprint $table) {
            $table->id();
            $table->string('name', 80);
            $table->string('description', 200)->nullable();
            $table->string('badge', 40)->nullable();
            $table->unsignedSmallInteger('duration_days');
            $table->decimal('price', 10, 2);
            $table->boolean('is_active')->default(true);
            $table->unsignedSmallInteger('sort_order')->default(0);
            $table->timestamps();
        });

        // One row per purchase / grant. A provider is "öne çıkan" while
        // starts_at <= now < ends_at and the row is not cancelled, so the profile
        // drops out of the section on its own the moment the time is up.
        Schema::create('featured_promotions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('provider_user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('featured_package_id')->nullable()->constrained('featured_packages')->nullOnDelete();
            $table->string('package_name', 80);
            $table->unsignedSmallInteger('duration_days');
            $table->decimal('price_paid', 10, 2)->default(0);
            $table->string('source', 20)->default('wallet'); // wallet | admin
            $table->timestamp('starts_at');
            $table->timestamp('ends_at')->index();
            $table->timestamp('cancelled_at')->nullable();
            $table->timestamp('expiry_notified_at')->nullable();
            $table->unsignedBigInteger('created_by')->nullable();
            $table->string('note', 200)->nullable();
            $table->timestamps();

            $table->index(['provider_user_id', 'ends_at']);
            $table->index(['starts_at', 'ends_at']);
        });

        $now = now();
        DB::table('featured_packages')->insert([
            ['name' => '1 Gün', 'description' => 'Bir gün boyunca ana sayfada öne çık.', 'badge' => null, 'duration_days' => 1, 'price' => 99, 'is_active' => true, 'sort_order' => 1, 'created_at' => $now, 'updated_at' => $now],
            ['name' => '7 Gün', 'description' => 'Bir hafta boyunca vitrinde kal.', 'badge' => null, 'duration_days' => 7, 'price' => 499, 'is_active' => true, 'sort_order' => 2, 'created_at' => $now, 'updated_at' => $now],
            ['name' => '30 Gün', 'description' => 'Bir ay boyunca sürekli görün.', 'badge' => 'En popüler', 'duration_days' => 30, 'price' => 1499, 'is_active' => true, 'sort_order' => 3, 'created_at' => $now, 'updated_at' => $now],
            ['name' => '1 Yıl', 'description' => 'Tüm yıl boyunca öne çıkan profesyonel ol.', 'badge' => 'En avantajlı', 'duration_days' => 365, 'price' => 11999, 'is_active' => true, 'sort_order' => 4, 'created_at' => $now, 'updated_at' => $now],
        ]);
    }

    public function down(): void
    {
        Schema::dropIfExists('featured_promotions');
        Schema::dropIfExists('featured_packages');
    }
};
