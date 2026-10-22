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
        Schema::create('payout_transfers', function (Blueprint $table) {
            $table->id();
            $table->foreignId('service_payment_id')->unique()->constrained('service_payments')->cascadeOnDelete();
            $table->foreignId('provider_user_id')->constrained('users')->cascadeOnDelete();
            $table->string('merchant_oid', 64)->index();
            $table->string('trans_id', 60)->unique();

            // PayTR API minor-unit integer amounts (kuruş)
            $table->unsignedBigInteger('submerchant_amount');
            $table->unsignedBigInteger('total_amount');

            // Snapshot accounting amounts (decimal)
            $table->decimal('gross_amount', 10, 2);
            $table->decimal('platform_commission', 10, 2);
            $table->decimal('withholding_amount', 10, 2)->default(0.00);
            $table->decimal('final_submerchant_amount', 10, 2);

            // Bank account snapshot
            $table->string('account_holder_name_snapshot');
            $table->text('iban_encrypted_snapshot');
            $table->string('iban_last4_snapshot', 4);

            // Transfer status: WAITING_ELIGIBILITY, READY, REQUESTED, COMPLETED, FAILED
            $table->string('status', 30)->default('WAITING_ELIGIBILITY')->index();

            // Timing & Eligibility
            $table->timestamp('eligible_at')->index();
            $table->timestamp('requested_at')->nullable();
            $table->timestamp('accepted_by_paytr_at')->nullable();
            $table->timestamp('completed_at')->nullable();
            $table->timestamp('failed_at')->nullable();

            // PayTR feedback & error tracking
            $table->string('paytr_reference')->nullable();
            $table->string('failure_code')->nullable();
            $table->text('failure_message')->nullable();

            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('payout_transfers');
    }
};
