<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // A provider's card payment (PayTR) for an "öne çıkarma" package. The period is only
        // created when PayTR confirms the payment (callback or status query), never before.
        Schema::create('featured_orders', function (Blueprint $table) {
            $table->id();
            $table->foreignId('provider_user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('featured_package_id')->nullable()->constrained('featured_packages')->nullOnDelete();
            $table->string('package_name', 80);
            $table->unsignedSmallInteger('duration_days');
            $table->decimal('amount', 10, 2);
            $table->string('status', 20)->default('PENDING')->index(); // PENDING | PAID | FAILED
            $table->string('merchant_oid', 64)->unique();
            $table->string('failure_message', 255)->nullable();
            $table->string('user_ip', 64)->nullable();
            $table->foreignId('promotion_id')->nullable()->constrained('featured_promotions')->nullOnDelete();
            $table->timestamp('paid_at')->nullable();
            $table->json('callback_payload')->nullable();
            $table->timestamps();

            $table->index(['provider_user_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('featured_orders');
    }
};
