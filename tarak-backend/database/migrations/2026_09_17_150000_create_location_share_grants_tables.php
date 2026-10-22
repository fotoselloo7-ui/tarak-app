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
        Schema::create('location_share_grants', function (Blueprint $table) {
            $table->id();
            $table->foreignId('customer_user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('provider_user_id')->constrained('users')->cascadeOnDelete();

            $table->string('resource_type'); // INSTANT_REQUEST or SCHEDULED_APPOINTMENT
            $table->unsignedBigInteger('resource_id');

            $table->string('source'); // SAVED_ADDRESS or CURRENT_LOCATION
            $table->string('status')->default('ACTIVE'); // ACTIVE, REVOKED, EXPIRED

            $table->foreignId('customer_address_id')->nullable()->constrained('customer_addresses')->nullOnDelete();

            // Encrypted exact location payload (stores full address, directions, coordinates snapshot)
            $table->longText('exact_location_payload');

            $table->timestamp('shared_at')->useCurrent();
            $table->timestamp('expires_at');
            $table->timestamp('revoked_at')->nullable();
            $table->timestamp('expired_at')->nullable();

            $table->timestamps();

            $table->index(['resource_type', 'resource_id', 'status']);
            $table->index(['provider_user_id', 'status']);
            $table->index(['customer_user_id', 'status']);
        });

        Schema::create('location_share_events', function (Blueprint $table) {
            $table->id();
            $table->foreignId('location_share_grant_id')->constrained('location_share_grants')->cascadeOnDelete();
            $table->string('event_type'); // LOCATION_SHARED, LOCATION_REVOKED, LOCATION_EXPIRED
            $table->foreignId('actor_user_id')->constrained('users')->cascadeOnDelete();
            $table->timestamp('created_at')->useCurrent();

            $table->index(['location_share_grant_id', 'event_type']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('location_share_events');
        Schema::dropIfExists('location_share_grants');
    }
};
