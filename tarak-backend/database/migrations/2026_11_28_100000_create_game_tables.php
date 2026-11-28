<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * "Randevuya Koş" oyunu entegrasyonu.
 * - İşletmeler oyuna sponsor olur (hizmet + aylık kota + bölge). Logoları o bölgedeki oyunculara oyunda görünür.
 * - Oyuncu oyunda hediye hakkı kazanınca kupon BURADA (Tarak'ta) üretilir: müşteri profilinde ve sponsor
 *   işletmenin panelinde aynı kayıt görünür; işletme kodu doğrulayıp kullanıldı işaretler. Kupon 30 gün geçerlidir.
 * - Oyun "Tarak ile giriş" için tek kullanımlık kod alır (OAuth benzeri), oyun sunucusu kodu sunucudan sunucuya değiştirir.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('game_settings', function (Blueprint $table) {
            $table->id();
            $table->string('key', 80)->unique();
            $table->text('value')->nullable();
            $table->timestamps();
        });

        Schema::create('game_auth_codes', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('code_hash', 64)->unique();
            $table->timestamp('expires_at');
            $table->timestamp('used_at')->nullable();
            $table->timestamps();
        });

        Schema::create('game_sponsorships', function (Blueprint $table) {
            $table->id();
            $table->foreignId('provider_user_id')->constrained('users')->cascadeOnDelete();
            $table->string('service_name', 120);            // ör. "Sakal Tıraşı", "Manikür"
            $table->string('audience', 10)->default('erkek'); // erkek | kadin | hepsi (oyundaki karakter modu)
            $table->string('scope', 10)->default('district'); // district | city
            $table->string('province', 100)->nullable();
            $table->string('district', 100)->nullable();
            $table->unsignedSmallInteger('monthly_quota')->default(10);
            $table->boolean('is_active')->default(true);
            $table->date('starts_on')->nullable();
            $table->date('ends_on')->nullable();
            $table->timestamps();
            $table->index(['is_active', 'province', 'district']);
        });

        Schema::create('game_coupons', function (Blueprint $table) {
            $table->id();
            $table->string('code', 20)->unique();             // TRK-XXXX-XXXX
            $table->foreignId('customer_user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('provider_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('sponsorship_id')->nullable()->constrained('game_sponsorships')->nullOnDelete();
            $table->string('service_name', 120);
            $table->string('status', 12)->default('active');  // active | used | expired
            $table->string('game_ref', 64)->nullable()->unique(); // oyun sunucusundaki kayıt (aynı hak iki kez kupon üretmesin)
            $table->string('province', 100)->nullable();
            $table->string('district', 100)->nullable();
            $table->timestamp('expires_at');
            $table->timestamp('used_at')->nullable();
            $table->timestamps();
            $table->index(['customer_user_id', 'status']);
            $table->index(['provider_user_id', 'status']);
        });

        Schema::create('game_impressions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('sponsorship_id')->constrained('game_sponsorships')->cascadeOnDelete();
            $table->date('day');
            $table->string('route', 120)->nullable();          // oynanan harita: "İstanbul · Beyoğlu"
            $table->unsignedInteger('views')->default(0);
            $table->unsignedInteger('players')->default(0);
            $table->timestamps();
            $table->unique(['sponsorship_id', 'day', 'route']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('game_impressions');
        Schema::dropIfExists('game_coupons');
        Schema::dropIfExists('game_sponsorships');
        Schema::dropIfExists('game_auth_codes');
        Schema::dropIfExists('game_settings');
    }
};
