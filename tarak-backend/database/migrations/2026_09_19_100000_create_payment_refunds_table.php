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
        Schema::create('payment_refunds', function (Blueprint $table) {
            $table->id();
            $table->foreignId('service_payment_id')->constrained('service_payments')->cascadeOnDelete();
            $table->foreignId('dispute_case_id')->nullable()->constrained('dispute_cases')->nullOnDelete();
            $table->string('merchant_oid', 64)->index();
            $table->string('reference_no', 64)->unique()->index();
            $table->unsignedBigInteger('refund_amount_minor');
            $table->string('currency', 10)->default('TL');
            $table->string('status', 30)->default('PENDING')->index(); // PENDING, REQUESTED, COMPLETED, FAILED, MANUAL_REVIEW
            $table->text('failure_reason')->nullable();
            $table->json('paytr_response')->nullable();
            $table->timestamp('requested_at')->nullable();
            $table->timestamp('completed_at')->nullable();
            $table->timestamp('failed_at')->nullable();
            $table->foreignId('created_by_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->json('metadata')->nullable();
            $table->timestamps();

            $table->index(['service_payment_id', 'status'], 'pay_refunds_srv_pay_status_idx');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('payment_refunds');
    }
};
