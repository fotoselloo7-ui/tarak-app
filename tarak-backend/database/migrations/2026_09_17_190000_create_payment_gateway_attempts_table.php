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
        Schema::create('payment_gateway_attempts', function (Blueprint $table) {
            $table->id();
            $table->foreignId('service_payment_id')->constrained('service_payments')->cascadeOnDelete();
            $table->string('gateway', 50)->default('PAYTR');
            $table->string('merchant_oid', 64)->unique();
            $table->string('status', 30)->default('CREATED')->index(); // CREATED, TOKEN_READY, SUCCESS, FAILED
            $table->unsignedBigInteger('payment_amount_minor');
            $table->string('currency', 10)->default('TRY');
            $table->string('user_ip', 45)->nullable();
            $table->json('user_basket')->nullable();
            $table->string('failure_code', 50)->nullable();
            $table->text('failure_message')->nullable();
            $table->timestamp('callback_received_at')->nullable();
            $table->json('callback_payload')->nullable();
            $table->timestamps();

            $table->index(['service_payment_id', 'status']);
        });

        if (!Schema::hasColumn('service_payments', 'transfer_pending_at')) {
            Schema::table('service_payments', function (Blueprint $table) {
                $table->timestamp('transfer_pending_at')->nullable()->after('held_at');
            });
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('payment_gateway_attempts');

        if (Schema::hasColumn('service_payments', 'transfer_pending_at')) {
            Schema::table('service_payments', function (Blueprint $table) {
                $table->dropColumn('transfer_pending_at');
            });
        }
    }
};
