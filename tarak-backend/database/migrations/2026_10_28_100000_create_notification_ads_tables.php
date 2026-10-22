<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * "Bildirim reklamı": a provider pays to send a discount notification to customers (their service area, a chosen
 * location, or every customer). The discount is real: it is applied to the provider's services while it runs.
 * Prices and limits are the admin's (`notification_ad_settings`).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('notification_ad_settings', function (Blueprint $table) {
            $table->id();
            $table->boolean('is_enabled')->default(true);
            $table->string('title', 120)->default('Bildirim Reklamı');
            $table->text('description')->nullable();
            // One price per audience (per send).
            $table->decimal('price_service_area', 10, 2)->default(150);
            $table->decimal('price_location', 10, 2)->default(250);
            $table->decimal('price_all', 10, 2)->default(750);
            // The discount a campaign may carry.
            $table->unsignedTinyInteger('min_discount_percent')->default(5);
            $table->unsignedTinyInteger('max_discount_percent')->default(50);
            $table->unsignedSmallInteger('max_discount_days')->default(14);
            // Anti-spam: sends per provider and notification ads one customer may receive, per day.
            $table->unsignedSmallInteger('max_sends_per_provider_per_day')->default(2);
            $table->unsignedSmallInteger('max_per_customer_per_day')->default(2);
            $table->timestamps();
        });

        Schema::create('notification_ads', function (Blueprint $table) {
            $table->id();
            $table->foreignId('provider_user_id')->constrained('users')->cascadeOnDelete();
            $table->string('audience', 20); // service_area | location | all
            $table->string('province', 100)->nullable();
            $table->string('district', 100)->nullable();
            $table->string('title', 80);
            $table->string('body', 200);
            $table->unsignedTinyInteger('discount_percent');
            $table->unsignedSmallInteger('discount_days');
            $table->decimal('amount', 10, 2)->default(0);
            $table->string('payment_source', 10)->nullable(); // wallet | card
            $table->string('status', 20)->default('PENDING_PAYMENT')->index(); // PENDING_PAYMENT | QUEUED | SENT | FAILED
            $table->unsignedInteger('recipients_count')->default(0);
            $table->string('merchant_oid', 64)->nullable()->unique();
            $table->string('failure_message', 250)->nullable();
            $table->string('user_ip', 45)->nullable();
            $table->timestamp('paid_at')->nullable();
            $table->timestamp('sent_at')->nullable();
            $table->json('callback_payload')->nullable();
            $table->timestamps();

            $table->index(['provider_user_id', 'created_at']);
        });

        Schema::create('provider_discounts', function (Blueprint $table) {
            $table->id();
            $table->foreignId('provider_user_id')->constrained('users')->cascadeOnDelete();
            $table->unsignedTinyInteger('percent');
            $table->timestamp('starts_at');
            $table->timestamp('ends_at');
            $table->timestamp('cancelled_at')->nullable();
            $table->foreignId('notification_ad_id')->nullable()->constrained('notification_ads')->nullOnDelete();
            $table->timestamps();

            $table->index(['provider_user_id', 'ends_at']);
        });

        // Customers can turn campaign (discount) notifications off without silencing the rest.
        Schema::table('user_push_preferences', function (Blueprint $table) {
            $table->boolean('campaign_enabled')->default(true)->after('push_enabled');
        });
    }

    public function down(): void
    {
        Schema::table('user_push_preferences', function (Blueprint $table) {
            $table->dropColumn('campaign_enabled');
        });
        Schema::dropIfExists('provider_discounts');
        Schema::dropIfExists('notification_ads');
        Schema::dropIfExists('notification_ad_settings');
    }
};
