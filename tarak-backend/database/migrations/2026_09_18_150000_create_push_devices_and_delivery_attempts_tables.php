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
        // 1. User Push Preferences
        Schema::create('user_push_preferences', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->unique()->constrained('users')->cascadeOnDelete();
            $table->boolean('push_enabled')->default(true);
            $table->timestamps();
        });

        // 2. Push Devices
        Schema::create('push_devices', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('platform', 16); // ANDROID, IOS
            $table->string('token_hash', 64)->unique(); // SHA-256 for fast unique lookup
            $table->text('token_encrypted'); // Encrypted FCM registration token
            $table->string('installation_id_hash', 64)->nullable()->index();
            $table->string('status', 16)->default('ACTIVE'); // ACTIVE, INACTIVE, INVALID
            $table->timestamp('last_registered_at')->useCurrent();
            $table->timestamp('last_used_at')->nullable();
            $table->timestamp('invalidated_at')->nullable();
            $table->string('app_version', 32)->nullable();
            $table->string('device_model', 64)->nullable();
            $table->timestamps();

            $table->index(['user_id', 'status']);
        });

        // 3. Push Delivery Attempts
        Schema::create('push_delivery_attempts', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_notification_id')->constrained('user_notifications')->cascadeOnDelete();
            $table->foreignId('push_device_id')->constrained('push_devices')->cascadeOnDelete();
            $table->string('status', 24)->default('PENDING'); // PENDING, SENT, FAILED, INVALID_TOKEN, SKIPPED
            $table->string('provider_message_id', 255)->nullable();
            $table->string('error_code', 64)->nullable();
            $table->unsignedInteger('attempt_count')->default(1);
            $table->timestamp('last_attempt_at')->nullable();
            $table->timestamp('sent_at')->nullable();
            $table->timestamp('failed_at')->nullable();
            $table->timestamps();

            $table->unique(['user_notification_id', 'push_device_id'], 'uniq_notif_device_attempt');
            $table->index(['status', 'created_at']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('push_delivery_attempts');
        Schema::dropIfExists('push_devices');
        Schema::dropIfExists('user_push_preferences');
    }
};
