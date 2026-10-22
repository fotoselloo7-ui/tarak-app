<?php

use App\Models\Appointment;
use App\Models\DisputeCase;
use App\Models\LocationShareGrant;
use App\Models\ServiceRequest;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('dispute_cases', function (Blueprint $table) {
            $table->id();
            $table->string('resource_type', 50); // INSTANT_REQUEST, SCHEDULED_APPOINTMENT
            $table->unsignedBigInteger('resource_id');
            $table->foreignId('customer_user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('provider_user_id')->constrained('users')->cascadeOnDelete();
            $table->string('payment_method', 20); // CASH, ONLINE
            $table->string('status', 30)->default('OPEN'); // OPEN, UNDER_REVIEW, RESOLVED_CUSTOMER, RESOLVED_PROVIDER
            $table->string('customer_reason', 255);
            $table->text('customer_note')->nullable();
            $table->string('admin_resolution', 50)->nullable(); // CUSTOMER_FAVOR, PROVIDER_FAVOR
            $table->text('admin_note')->nullable();
            $table->timestamp('opened_at');
            $table->timestamp('review_started_at')->nullable();
            $table->timestamp('resolved_at')->nullable();
            $table->foreignId('reviewed_by_admin_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();

            $table->unique(['resource_type', 'resource_id'], 'dispute_cases_resource_unique');
            $table->index('status');
            $table->index('customer_user_id');
            $table->index('provider_user_id');
        });

        // Idempotent backfill of any pre-existing DISPUTED resources
        $this->backfillExistingDisputes();
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('dispute_cases');
    }

    /**
     * Backfill existing DISPUTED records safely and idempotently.
     */
    private function backfillExistingDisputes(): void
    {
        // 1. Instant Service Requests
        $disputedRequests = DB::table('service_requests')
            ->where('status', 'DISPUTED')
            ->whereNotNull('assigned_provider_user_id')
            ->get();

        foreach ($disputedRequests as $req) {
            $exists = DB::table('dispute_cases')
                ->where('resource_type', 'INSTANT_REQUEST')
                ->where('resource_id', $req->id)
                ->exists();

            if (!$exists) {
                DB::table('dispute_cases')->insert([
                    'resource_type' => 'INSTANT_REQUEST',
                    'resource_id' => $req->id,
                    'customer_user_id' => $req->customer_user_id,
                    'provider_user_id' => $req->assigned_provider_user_id,
                    'payment_method' => strtoupper($req->payment_method ?? 'CASH'),
                    'status' => 'OPEN',
                    'customer_reason' => $req->dispute_reason ?? 'Sorun bildirildi',
                    'customer_note' => $req->dispute_note,
                    'opened_at' => $req->disputed_at ?? now(),
                    'created_at' => now(),
                    'updated_at' => now(),
                ]);
            }
        }

        // 2. Scheduled Appointments
        $disputedAppointments = DB::table('appointments')
            ->where('status', 'DISPUTED')
            ->get();

        foreach ($disputedAppointments as $appt) {
            $exists = DB::table('dispute_cases')
                ->where('resource_type', 'SCHEDULED_APPOINTMENT')
                ->where('resource_id', $appt->id)
                ->exists();

            if (!$exists) {
                DB::table('dispute_cases')->insert([
                    'resource_type' => 'SCHEDULED_APPOINTMENT',
                    'resource_id' => $appt->id,
                    'customer_user_id' => $appt->customer_user_id,
                    'provider_user_id' => $appt->provider_user_id,
                    'payment_method' => strtoupper($appt->payment_method ?? 'CASH'),
                    'status' => 'OPEN',
                    'customer_reason' => $appt->dispute_reason ?? 'Sorun bildirildi',
                    'customer_note' => $appt->dispute_note,
                    'opened_at' => $appt->disputed_at ?? now(),
                    'created_at' => now(),
                    'updated_at' => now(),
                ]);
            }
        }
    }
};
