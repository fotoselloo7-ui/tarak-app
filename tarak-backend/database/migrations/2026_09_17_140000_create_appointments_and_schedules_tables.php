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
        // 1. Appointments Canonical Table
        Schema::create('appointments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('customer_user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('provider_user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('customer_address_id')->nullable()->constrained('customer_addresses')->nullOnDelete();

            $table->string('status')->default('PENDING'); // PENDING, ALTERNATIVE_PROPOSED, CONFIRMED, REJECTED, CANCELLED, IN_PROGRESS, etc.
            $table->date('appointment_date');
            $table->time('start_time');
            $table->time('end_time');

            $table->string('payment_method')->default('CASH'); // CASH or ONLINE
            $table->decimal('total_price', 10, 2)->default(0);
            $table->unsignedInteger('total_duration_minutes')->default(30);

            // Privacy location
            $table->string('approx_province')->nullable();
            $table->string('approx_district')->nullable();
            $table->string('approx_neighborhood')->nullable();

            // Exact address (hidden from provider responses)
            $table->decimal('private_latitude', 10, 7)->nullable();
            $table->decimal('private_longitude', 10, 7)->nullable();

            $table->text('customer_note')->nullable();

            $table->timestamp('requested_at')->useCurrent();
            $table->timestamp('confirmed_at')->nullable();
            $table->timestamp('rejected_at')->nullable();
            $table->timestamp('cancelled_at')->nullable();

            $table->text('rejection_reason')->nullable();

            $table->timestamps();

            $table->index(['provider_user_id', 'appointment_date', 'status']);
            $table->index(['customer_user_id', 'status']);
        });

        // 2. Appointment Services (Snapshot Pivot)
        Schema::create('appointment_services', function (Blueprint $table) {
            $table->id();
            $table->foreignId('appointment_id')->constrained('appointments')->cascadeOnDelete();
            $table->foreignId('service_id')->constrained('services')->cascadeOnDelete();
            $table->decimal('price_snapshot', 10, 2)->default(0);
            $table->unsignedInteger('duration_minutes_snapshot')->default(30);
            $table->timestamps();
        });

        // 3. Provider Weekly Schedules
        Schema::create('provider_weekly_schedules', function (Blueprint $table) {
            $table->id();
            $table->foreignId('provider_profile_id')->constrained('provider_profiles')->cascadeOnDelete();
            $table->string('day_of_week'); // monday, tuesday, wednesday, thursday, friday, saturday, sunday
            $table->boolean('is_enabled')->default(true);
            $table->time('start_time')->nullable()->default('09:00');
            $table->time('end_time')->nullable()->default('19:00');
            $table->timestamps();

            $table->unique(['provider_profile_id', 'day_of_week']);
        });

        // 4. Provider Schedule Breaks
        Schema::create('provider_schedule_breaks', function (Blueprint $table) {
            $table->id();
            $table->foreignId('weekly_schedule_id')->constrained('provider_weekly_schedules')->cascadeOnDelete();
            $table->time('start_time');
            $table->time('end_time');
            $table->timestamps();
        });

        // 5. Provider Closed Dates
        Schema::create('provider_closed_dates', function (Blueprint $table) {
            $table->id();
            $table->foreignId('provider_profile_id')->constrained('provider_profiles')->cascadeOnDelete();
            $table->date('date');
            $table->string('reason')->default('izin'); // izin, tatil, kisisel, diger
            $table->text('note')->nullable();
            $table->timestamps();

            $table->unique(['provider_profile_id', 'date']);
        });

        // 6. Appointment Alternative Slots
        Schema::create('appointment_alternative_slots', function (Blueprint $table) {
            $table->id();
            $table->foreignId('appointment_id')->constrained('appointments')->cascadeOnDelete();
            $table->date('date');
            $table->time('start_time');
            $table->time('end_time');
            $table->string('status')->default('PENDING'); // PENDING, ACCEPTED, EXPIRED
            $table->timestamps();

            $table->index(['appointment_id', 'status']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('appointment_alternative_slots');
        Schema::dropIfExists('provider_closed_dates');
        Schema::dropIfExists('provider_schedule_breaks');
        Schema::dropIfExists('provider_weekly_schedules');
        Schema::dropIfExists('appointment_services');
        Schema::dropIfExists('appointments');
    }
};
