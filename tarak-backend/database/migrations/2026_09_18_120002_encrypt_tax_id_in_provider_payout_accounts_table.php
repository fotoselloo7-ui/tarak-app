<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        if (Schema::hasTable('provider_payout_accounts')) {
            Schema::table('provider_payout_accounts', function (Blueprint $table) {
                if (!Schema::hasColumn('provider_payout_accounts', 'tax_id_or_tckn_encrypted')) {
                    $table->text('tax_id_or_tckn_encrypted')->nullable()->after('tax_type');
                }
                if (!Schema::hasColumn('provider_payout_accounts', 'tax_id_last2')) {
                    $table->string('tax_id_last2', 4)->nullable()->after('tax_id_or_tckn_encrypted');
                }
            });

            if (Schema::hasColumn('provider_payout_accounts', 'tax_id_or_tckn')) {
                $rows = DB::table('provider_payout_accounts')->get();
                foreach ($rows as $row) {
                    if (!empty($row->tax_id_or_tckn)) {
                        $clean = trim((string) $row->tax_id_or_tckn);
                        $encrypted = Crypt::encryptString($clean);
                        $last2 = substr($clean, -2);
                        DB::table('provider_payout_accounts')
                            ->where('id', $row->id)
                            ->update([
                                'tax_id_or_tckn_encrypted' => $encrypted,
                                'tax_id_last2' => $last2,
                            ]);
                    }
                }

                Schema::table('provider_payout_accounts', function (Blueprint $table) {
                    $table->dropColumn('tax_id_or_tckn');
                });
            }
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        if (Schema::hasTable('provider_payout_accounts')) {
            Schema::table('provider_payout_accounts', function (Blueprint $table) {
                if (!Schema::hasColumn('provider_payout_accounts', 'tax_id_or_tckn')) {
                    $table->string('tax_id_or_tckn')->nullable()->after('tax_type');
                }
                if (Schema::hasColumn('provider_payout_accounts', 'tax_id_or_tckn_encrypted')) {
                    $table->dropColumn(['tax_id_or_tckn_encrypted', 'tax_id_last2']);
                }
            });
        }
    }
};
