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
        // 1. Expand Wallets table
        Schema::table('wallets', function (Blueprint $table) {
            $table->decimal('promo_balance', 12, 2)->default(0.00)->after('balance');
            $table->decimal('reserved_cash_balance', 12, 2)->default(0.00)->after('promo_balance');
            $table->decimal('reserved_promo_balance', 12, 2)->default(0.00)->after('reserved_cash_balance');
        });

        // 2. Finance Settings (Singleton Canonical Config)
        Schema::create('finance_settings', function (Blueprint $table) {
            $table->id();
            $table->decimal('default_commission_rate', 5, 2)->default(15.00);
            $table->decimal('welcome_bonus_amount', 10, 2)->default(500.00);
            $table->string('currency', 10)->default('TRY');
            $table->timestamps();
        });

        // 3. Wallet Transactions (Immutable Ledger)
        Schema::create('wallet_transactions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('wallet_id')->constrained('wallets')->cascadeOnDelete();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('type', 60)->index();
            $table->string('direction', 10); // 'CREDIT', 'DEBIT'
            $table->string('bucket', 30); // 'CASH', 'PROMO', 'RESERVED_CASH', 'RESERVED_PROMO'
            $table->decimal('amount', 12, 2);
            $table->string('reference_type', 60)->nullable();
            $table->unsignedBigInteger('reference_id')->nullable();
            $table->string('idempotency_key', 191)->unique();
            $table->string('description', 255)->nullable();
            $table->json('metadata')->nullable();
            $table->timestamp('created_at')->useCurrent()->index();

            $table->index(['wallet_id', 'created_at']);
            $table->index(['user_id', 'created_at']);
        });

        // 4. Commission Reservations (CASH Jobs/Appointments)
        Schema::create('commission_reservations', function (Blueprint $table) {
            $table->id();
            $table->string('resource_type', 30); // 'INSTANT_REQUEST', 'SCHEDULED_APPOINTMENT'
            $table->unsignedBigInteger('resource_id');
            $table->foreignId('provider_user_id')->constrained('users')->cascadeOnDelete();
            $table->string('payment_method', 20)->default('CASH');
            $table->decimal('gross_amount', 10, 2);
            $table->decimal('commission_rate', 5, 2);
            $table->decimal('commission_amount', 10, 2);
            $table->decimal('reserved_cash_amount', 10, 2)->default(0.00);
            $table->decimal('reserved_promo_amount', 10, 2)->default(0.00);
            $table->string('status', 30)->default('RESERVED')->index(); // 'RESERVED', 'CAPTURED', 'RELEASED', 'HELD_DISPUTE'
            $table->timestamp('reserved_at')->useCurrent();
            $table->timestamp('captured_at')->nullable();
            $table->timestamp('released_at')->nullable();
            $table->timestamp('held_dispute_at')->nullable();
            $table->timestamps();

            $table->index(['resource_type', 'resource_id', 'status'], 'comm_res_status_idx');
            $table->index(['provider_user_id', 'status'], 'comm_res_prov_idx');
        });

        // 5. Service Payments (ONLINE Payments Domain Model)
        Schema::create('service_payments', function (Blueprint $table) {
            $table->id();
            $table->string('resource_type', 30); // 'INSTANT_REQUEST', 'SCHEDULED_APPOINTMENT'
            $table->unsignedBigInteger('resource_id');
            $table->foreignId('customer_user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('provider_user_id')->constrained('users')->cascadeOnDelete();
            $table->string('payment_method', 20)->default('ONLINE');
            $table->decimal('gross_amount', 10, 2);
            $table->decimal('commission_rate', 5, 2);
            $table->decimal('commission_amount', 10, 2);
            $table->decimal('provider_net_amount', 10, 2);
            $table->string('status', 30)->default('PENDING')->index(); // 'PENDING', 'HELD', 'SETTLED', 'DISPUTED', 'REFUND_REQUIRED', 'CANCELLED'
            $table->string('gateway', 50)->default('PAYTR');
            $table->string('gateway_reference', 100)->nullable();
            $table->timestamp('held_at')->nullable();
            $table->timestamp('settled_at')->nullable();
            $table->timestamp('cancelled_at')->nullable();
            $table->timestamp('disputed_at')->nullable();
            $table->timestamps();

            $table->index(['resource_type', 'resource_id', 'status'], 'srv_pay_status_idx');
            $table->index(['provider_user_id', 'status'], 'srv_pay_prov_idx');
            $table->index(['customer_user_id', 'status'], 'srv_pay_cust_idx');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('service_payments');
        Schema::dropIfExists('commission_reservations');
        Schema::dropIfExists('wallet_transactions');
        Schema::dropIfExists('finance_settings');

        Schema::table('wallets', function (Blueprint $table) {
            $table->dropColumn([
                'promo_balance',
                'reserved_cash_balance',
                'reserved_promo_balance',
            ]);
        });
    }
};
