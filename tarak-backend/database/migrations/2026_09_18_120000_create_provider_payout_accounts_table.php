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
        Schema::create('provider_payout_accounts', function (Blueprint $table) {
            $table->id();
            $table->foreignId('provider_user_id')->unique()->constrained('users')->cascadeOnDelete();
            $table->string('account_holder_name');
            $table->text('iban_encrypted');
            $table->string('iban_last4', 4);
            $table->string('status', 20)->default('ACTIVE'); // ACTIVE, SUSPENDED
            $table->timestamp('verified_at')->nullable();
            $table->string('payout_tax_status', 30)->default('NOT_CONFIGURED'); // NOT_CONFIGURED, CONFIGURED
            $table->string('tax_type', 30)->nullable(); // INDIVIDUAL, COMPANY, EXEMPT
            $table->text('tax_id_or_tckn_encrypted')->nullable();
            $table->string('tax_id_last2', 4)->nullable();
            $table->string('tax_office')->nullable();
            $table->decimal('withholding_rate', 5, 2)->nullable(); // e.g. 0.00, 1.00
            $table->string('withholding_basis', 50)->nullable();
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('provider_payout_accounts');
    }
};
