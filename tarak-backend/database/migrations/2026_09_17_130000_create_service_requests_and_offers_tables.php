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
        // 1. Add coordinates to provider_profiles if not present
        Schema::table('provider_profiles', function (Blueprint $table) {
            if (!Schema::hasColumn('provider_profiles', 'latitude')) {
                $table->decimal('latitude', 10, 7)->nullable()->after('address_detail');
                $table->decimal('longitude', 10, 7)->nullable()->after('latitude');
            }
        });

        // 2. Service Requests (Canonical name, avoids collision with Laravel queue 'jobs' table)
        Schema::create('service_requests', function (Blueprint $table) {
            $table->id();
            $table->foreignId('customer_user_id')->constrained('users')->cascadeOnDelete();
            $table->string('category_id', 30)->nullable();
            $table->string('mode', 20)->default('INSTANT'); // 'INSTANT'
            $table->string('status', 30)->default('OPEN'); // 'OPEN', 'ASSIGNED', 'CANCELLED'
            $table->string('payment_method', 20)->default('CASH'); // 'CASH', 'ONLINE'
            $table->foreignId('customer_address_id')->nullable()->constrained('customer_addresses')->nullOnDelete();
            $table->string('location_text', 255)->nullable();
            $table->string('approx_province', 100)->nullable();
            $table->string('approx_district', 100)->nullable();
            $table->string('approx_neighborhood', 150)->nullable();
            $table->decimal('private_latitude', 10, 7)->nullable();
            $table->decimal('private_longitude', 10, 7)->nullable();
            $table->text('customer_note')->nullable();
            $table->string('duration_preference', 50)->default('1h');
            $table->string('urgency', 30)->default('urgent');
            $table->foreignId('assigned_provider_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->unsignedBigInteger('accepted_offer_id')->nullable();
            $table->timestamp('assigned_at')->nullable();
            $table->timestamp('cancelled_at')->nullable();
            $table->timestamps();

            $table->index(['mode', 'status']);
            $table->index(['approx_province', 'approx_district']);
        });

        // 3. Pivot: Service Request Services (relational pivot for requested services)
        Schema::create('service_request_services', function (Blueprint $table) {
            $table->id();
            $table->foreignId('service_request_id')->constrained('service_requests')->cascadeOnDelete();
            $table->foreignId('service_id')->constrained('services')->cascadeOnDelete();
            $table->timestamps();

            $table->unique(['service_request_id', 'service_id']);
        });

        // 4. Service Offers
        Schema::create('service_offers', function (Blueprint $table) {
            $table->id();
            $table->foreignId('service_request_id')->constrained('service_requests')->cascadeOnDelete();
            $table->foreignId('provider_user_id')->constrained('users')->cascadeOnDelete();
            $table->decimal('price', 10, 2);
            $table->unsignedInteger('duration_minutes')->default(30);
            $table->unsignedInteger('estimated_arrival_min')->nullable();
            $table->string('payment_preference', 30)->default('ANY');
            $table->text('message')->nullable();
            $table->string('status', 30)->default('PENDING'); // 'PENDING', 'ACCEPTED', 'REJECTED'
            $table->timestamp('accepted_at')->nullable();
            $table->timestamp('rejected_at')->nullable();
            $table->timestamps();

            $table->unique(['service_request_id', 'provider_user_id']);
            $table->index(['status']);
        });

        // 5. Add foreign key for accepted_offer_id
        Schema::table('service_requests', function (Blueprint $table) {
            $table->foreign('accepted_offer_id')->references('id')->on('service_offers')->nullOnDelete();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('service_requests', function (Blueprint $table) {
            $table->dropForeign(['accepted_offer_id']);
        });

        Schema::dropIfExists('service_offers');
        Schema::dropIfExists('service_request_services');
        Schema::dropIfExists('service_requests');

        Schema::table('provider_profiles', function (Blueprint $table) {
            if (Schema::hasColumn('provider_profiles', 'latitude')) {
                $table->dropColumn(['latitude', 'longitude']);
            }
        });
    }
};
