<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * "İlk 500 TL komisyon Tarak.app'ten" + banka (IBAN) komisyon tahsilatı.
 *
 * Purely additive: no existing column, row or ledger entry is touched.
 *  - finance_settings: the bank account the businesses pay their commission to (admin-managed)
 *  - wallets: when the gift commission right ran out and whether the one-time e-mail went out
 *  - provider_profiles.payment_reference: the unique TRK code a business writes in its transfer description
 *  - commission_topups: bank payment notices / verified bank receipts (a notice alone never credits anything)
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('finance_settings', function (Blueprint $table) {
            $table->string('bank_account_holder', 150)->nullable();
            $table->string('bank_name', 100)->nullable();
            $table->string('bank_iban', 34)->nullable();
            $table->text('bank_instructions')->nullable();
            $table->decimal('topup_min_amount', 10, 2)->default(100.00);
        });

        Schema::table('wallets', function (Blueprint $table) {
            $table->timestamp('gift_depleted_at')->nullable();
            $table->timestamp('gift_email_sent_at')->nullable();
        });

        Schema::table('provider_profiles', function (Blueprint $table) {
            $table->string('payment_reference', 20)->nullable()->unique();
        });

        Schema::create('commission_topups', function (Blueprint $table) {
            $table->id();
            $table->foreignId('provider_user_id')->constrained('users')->cascadeOnDelete();
            $table->string('reference_code', 20)->index();
            $table->string('source', 20)->default('PROVIDER_NOTICE'); // PROVIDER_NOTICE | ADMIN_ENTRY
            $table->string('status', 20)->default('PENDING')->index(); // PENDING | PAID | REJECTED
            $table->decimal('claimed_amount', 12, 2);
            $table->decimal('verified_amount', 12, 2)->nullable();
            $table->date('transfer_date')->nullable();
            $table->string('sender_name', 150)->nullable();
            // The bank statement line this payment was verified against; unique so one transfer can never credit twice.
            $table->string('bank_transaction_ref', 100)->nullable()->unique();
            $table->string('provider_note', 500)->nullable();
            $table->string('admin_note', 500)->nullable();
            $table->foreignId('reviewed_by_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('reviewed_at')->nullable();
            $table->unsignedBigInteger('wallet_transaction_id')->nullable();
            $table->timestamps();

            $table->index(['provider_user_id', 'status'], 'topup_provider_status_idx');
            $table->index(['status', 'created_at'], 'topup_status_created_idx');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('commission_topups');

        Schema::table('provider_profiles', function (Blueprint $table) {
            $table->dropUnique(['payment_reference']);
            $table->dropColumn('payment_reference');
        });

        Schema::table('wallets', function (Blueprint $table) {
            $table->dropColumn(['gift_depleted_at', 'gift_email_sent_at']);
        });

        Schema::table('finance_settings', function (Blueprint $table) {
            $table->dropColumn(['bank_account_holder', 'bank_name', 'bank_iban', 'bank_instructions', 'topup_min_amount']);
        });
    }
};
