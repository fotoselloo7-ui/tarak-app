<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::table('users', function (Blueprint $table): void {
            $table->timestamp('terms_accepted_at')->nullable();
            $table->timestamp('privacy_acknowledged_at')->nullable();
            $table->timestamp('marketing_consent_at')->nullable();
        });
    }
    public function down(): void {
        Schema::table('users', static function (Blueprint $table): void {
            $table->dropColumn(['terms_accepted_at', 'privacy_acknowledged_at', 'marketing_consent_at']);
        });
    }
};
