<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Customer -> provider reviews, only after a completed resource.
        Schema::create('provider_reviews', function (Blueprint $table) {
            $table->id();
            $table->foreignId('provider_user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('customer_user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('appointment_id')->nullable()->constrained('appointments')->nullOnDelete();
            $table->foreignId('service_request_id')->nullable()->constrained('service_requests')->nullOnDelete();
            $table->unsignedTinyInteger('rating'); // 1..5
            $table->string('comment', 1000)->nullable();
            $table->timestamps();

            $table->index(['provider_user_id', 'created_at']);
            // One review per customer per completed resource.
            $table->unique(['customer_user_id', 'appointment_id'], 'uniq_review_customer_appointment');
            $table->unique(['customer_user_id', 'service_request_id'], 'uniq_review_customer_request');
        });

        // Customer favourites (provider users).
        Schema::create('customer_favorites', function (Blueprint $table) {
            $table->id();
            $table->foreignId('customer_user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('provider_user_id')->constrained('users')->cascadeOnDelete();
            $table->timestamps();

            $table->unique(['customer_user_id', 'provider_user_id'], 'uniq_favorite');
            $table->index('provider_user_id');
        });

        // Support tickets (contact form + optional auth user).
        Schema::create('support_tickets', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('name', 120);
            $table->string('email', 160);
            $table->string('category', 40)->default('general');
            $table->string('subject', 160);
            $table->text('message');
            $table->string('status', 20)->default('OPEN'); // OPEN | IN_PROGRESS | RESOLVED | CLOSED
            $table->foreignId('handled_by')->nullable()->constrained('users')->nullOnDelete();
            $table->text('admin_note')->nullable();
            $table->timestamps();

            $table->index(['status', 'created_at']);
        });

        // Newsletter subscriptions.
        Schema::create('newsletter_subscriptions', function (Blueprint $table) {
            $table->id();
            $table->string('email', 160)->unique();
            $table->string('status', 20)->default('SUBSCRIBED'); // SUBSCRIBED | UNSUBSCRIBED
            $table->string('unsubscribe_token', 64)->nullable()->unique();
            $table->timestamp('unsubscribed_at')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('newsletter_subscriptions');
        Schema::dropIfExists('support_tickets');
        Schema::dropIfExists('customer_favorites');
        Schema::dropIfExists('provider_reviews');
    }
};
