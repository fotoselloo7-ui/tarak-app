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
        // 1. Add lifecycle columns to service_requests if missing
        Schema::table('service_requests', function (Blueprint $table) {
            if (!Schema::hasColumn('service_requests', 'service_started_at')) {
                $table->timestamp('service_started_at')->nullable()->after('cancelled_at');
            }
            if (!Schema::hasColumn('service_requests', 'provider_completed_at')) {
                $table->timestamp('provider_completed_at')->nullable()->after('service_started_at');
            }
            if (!Schema::hasColumn('service_requests', 'completed_at')) {
                $table->timestamp('completed_at')->nullable()->after('provider_completed_at');
            }
            if (!Schema::hasColumn('service_requests', 'disputed_at')) {
                $table->timestamp('disputed_at')->nullable()->after('completed_at');
            }
            if (!Schema::hasColumn('service_requests', 'dispute_reason')) {
                $table->string('dispute_reason', 255)->nullable()->after('disputed_at');
            }
            if (!Schema::hasColumn('service_requests', 'dispute_note')) {
                $table->text('dispute_note')->nullable()->after('dispute_reason');
            }
        });

        // 2. Add lifecycle columns to appointments if missing
        Schema::table('appointments', function (Blueprint $table) {
            if (!Schema::hasColumn('appointments', 'service_started_at')) {
                $table->timestamp('service_started_at')->nullable()->after('rejection_reason');
            }
            if (!Schema::hasColumn('appointments', 'provider_completed_at')) {
                $table->timestamp('provider_completed_at')->nullable()->after('service_started_at');
            }
            if (!Schema::hasColumn('appointments', 'completed_at')) {
                $table->timestamp('completed_at')->nullable()->after('provider_completed_at');
            }
            if (!Schema::hasColumn('appointments', 'disputed_at')) {
                $table->timestamp('disputed_at')->nullable()->after('completed_at');
            }
            if (!Schema::hasColumn('appointments', 'dispute_reason')) {
                $table->string('dispute_reason', 255)->nullable()->after('disputed_at');
            }
            if (!Schema::hasColumn('appointments', 'dispute_note')) {
                $table->text('dispute_note')->nullable()->after('dispute_reason');
            }
        });

        // Drop if partial table exists from failed attempt
        Schema::dropIfExists('service_start_verifications');

        // 3. Service Start Verifications Canonical Table
        Schema::create('service_start_verifications', function (Blueprint $table) {
            $table->id();
            $table->string('resource_type', 50); // INSTANT_REQUEST, SCHEDULED_APPOINTMENT
            $table->unsignedBigInteger('resource_id');
            $table->foreignId('customer_user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('provider_user_id')->constrained('users')->cascadeOnDelete();

            $table->string('code_hash', 255);
            $table->text('encrypted_code');

            $table->string('status', 30)->default('ACTIVE'); // ACTIVE, VERIFIED, EXPIRED
            $table->unsignedTinyInteger('failed_attempts')->default(0);
            $table->timestamp('locked_until')->nullable();

            $table->timestamp('generated_at');
            $table->timestamp('verified_at')->nullable();
            $table->timestamp('expires_at')->nullable();

            $table->timestamps();

            // Explicit short index names to avoid MySQL 64-char limit
            $table->index(['resource_type', 'resource_id', 'status'], 'ssv_res_status_idx');
            $table->index(['customer_user_id'], 'ssv_cust_idx');
            $table->index(['provider_user_id'], 'ssv_prov_idx');
        });

        // 4. Service Lifecycle Audit Events Table
        Schema::dropIfExists('service_lifecycle_events');
        Schema::create('service_lifecycle_events', function (Blueprint $table) {
            $table->id();
            $table->string('resource_type', 50);
            $table->unsignedBigInteger('resource_id');
            $table->string('event_type', 50); // START_CODE_GENERATED, START_CODE_FAILED, etc.
            $table->foreignId('actor_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->json('metadata')->nullable();
            $table->timestamp('created_at')->useCurrent();

            $table->index(['resource_type', 'resource_id'], 'sle_res_idx');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('service_lifecycle_events');
        Schema::dropIfExists('service_start_verifications');

        Schema::table('appointments', function (Blueprint $table) {
            $table->dropColumn([
                'service_started_at',
                'provider_completed_at',
                'completed_at',
                'disputed_at',
                'dispute_reason',
                'dispute_note',
            ]);
        });

        Schema::table('service_requests', function (Blueprint $table) {
            $table->dropColumn([
                'service_started_at',
                'provider_completed_at',
                'completed_at',
                'disputed_at',
                'dispute_reason',
                'dispute_note',
            ]);
        });
    }
};
