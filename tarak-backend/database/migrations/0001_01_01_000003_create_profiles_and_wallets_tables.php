<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // 1. Customer Profiles
        Schema::create('customer_profiles', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->unique()->constrained('users')->cascadeOnDelete();
            $table->boolean('profile_completed')->default(false);
            $table->timestamps();
        });

        // 2. Provider Profiles
        Schema::create('provider_profiles', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->unique()->constrained('users')->cascadeOnDelete();
            $table->string('provider_type', 30)->default('barber'); // 'barber', 'coiffeur'
            $table->string('business_name')->nullable();
            $table->boolean('is_approved')->default(false);
            $table->string('identity_status', 30)->default('PENDING'); // 'PENDING', 'APPROVED', 'REJECTED', 'REUPLOAD_REQUIRED'
            $table->boolean('is_online')->default(false);
            $table->boolean('accepts_new_clients')->default(true);
            $table->unsignedInteger('service_radius_km')->default(15);
            $table->unsignedSmallInteger('experience_years')->nullable();
            $table->decimal('commission_rate_override', 5, 2)->nullable();
            $table->timestamp('approved_at')->nullable();
            $table->timestamp('reviewed_at')->nullable();
            $table->timestamps();
        });

        // 3. Provider Wallets
        Schema::create('wallets', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->unique()->constrained('users')->cascadeOnDelete();
            $table->decimal('balance', 12, 2)->default(0.00);
            $table->string('currency', 10)->default('TRY');
            $table->boolean('is_frozen')->default(false);
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('wallets');
        Schema::dropIfExists('provider_profiles');
        Schema::dropIfExists('customer_profiles');
    }
};
