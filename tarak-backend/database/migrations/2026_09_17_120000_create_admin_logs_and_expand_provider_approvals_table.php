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
        // 1. Create Admin Audit Logs table
        Schema::create('admin_logs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('admin_user_id')->constrained('users')->cascadeOnDelete();
            $table->string('action', 60)->index(); // 'PROVIDER_DOCUMENT_APPROVED', 'PROVIDER_DOCUMENT_REJECTED', 'PROVIDER_DOCUMENT_REUPLOAD_REQUIRED', 'PROVIDER_APPROVED', 'PROVIDER_REJECTED', 'PROVIDER_REUPLOAD_REQUIRED'
            $table->string('target_type', 60); // 'PROVIDER', 'PROVIDER_DOCUMENT'
            $table->unsignedBigInteger('target_id')->index();
            $table->json('metadata')->nullable();
            $table->timestamp('created_at')->useCurrent();
        });

        // 2. Expand Provider Profiles with approval rejection/reupload reasons and welcome bonus flag
        Schema::table('provider_profiles', function (Blueprint $table) {
            $table->text('rejection_reason')->nullable()->after('reviewed_at');
            $table->text('reupload_reason')->nullable()->after('rejection_reason');
            $table->boolean('has_received_welcome_bonus')->default(false)->after('reupload_reason');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('provider_profiles', function (Blueprint $table) {
            $table->dropColumn([
                'rejection_reason',
                'reupload_reason',
                'has_received_welcome_bonus',
            ]);
        });

        Schema::dropIfExists('admin_logs');
    }
};
