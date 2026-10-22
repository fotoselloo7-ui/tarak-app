<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('provider_services', function (Blueprint $table) {
            $table->string('description', 300)->nullable()->after('custom_duration_minutes');
        });

        // Provider-owned bundles; never part of the global catalog.
        Schema::create('provider_packages', function (Blueprint $table) {
            $table->id();
            $table->foreignId('provider_profile_id')->constrained('provider_profiles')->cascadeOnDelete();
            $table->string('title', 120);
            $table->text('description')->nullable();
            $table->decimal('price', 10, 2);
            $table->unsignedInteger('duration_minutes');
            $table->boolean('is_active')->default(true);
            $table->unsignedInteger('sort_order')->default(0);
            $table->timestamps();

            $table->index(['provider_profile_id', 'is_active']);
        });

        Schema::create('provider_package_items', function (Blueprint $table) {
            $table->id();
            $table->foreignId('provider_package_id')->constrained('provider_packages')->cascadeOnDelete();
            $table->foreignId('service_id')->constrained('services')->cascadeOnDelete();
            $table->unsignedInteger('sort_order')->default(0);
            $table->timestamps();

            $table->unique(['provider_package_id', 'service_id']);
        });

        Schema::table('service_requests', function (Blueprint $table) {
            $table->foreignId('target_provider_user_id')->nullable()->after('urgency')->constrained('users')->nullOnDelete();
            $table->foreignId('provider_service_id')->nullable()->after('target_provider_user_id')->constrained('provider_services')->nullOnDelete();
            $table->foreignId('provider_package_id')->nullable()->after('provider_service_id')->constrained('provider_packages')->nullOnDelete();
            $table->decimal('snapshot_price', 10, 2)->nullable()->after('provider_package_id');
            $table->unsignedInteger('snapshot_duration_minutes')->nullable()->after('snapshot_price');
            $table->json('offering_snapshot')->nullable()->after('snapshot_duration_minutes');

            $table->index(['target_provider_user_id', 'status']);
        });

        Schema::table('appointments', function (Blueprint $table) {
            $table->foreignId('provider_package_id')->nullable()->after('total_duration_minutes')->constrained('provider_packages')->nullOnDelete();
            $table->json('offering_snapshot')->nullable()->after('provider_package_id');
        });
    }

    public function down(): void
    {
        Schema::table('appointments', function (Blueprint $table) {
            $table->dropConstrainedForeignId('provider_package_id');
            $table->dropColumn('offering_snapshot');
        });

        Schema::table('service_requests', function (Blueprint $table) {
            $table->dropConstrainedForeignId('provider_package_id');
            $table->dropConstrainedForeignId('provider_service_id');
            $table->dropConstrainedForeignId('target_provider_user_id');
            $table->dropColumn(['snapshot_price', 'snapshot_duration_minutes', 'offering_snapshot']);
        });

        Schema::dropIfExists('provider_package_items');
        Schema::dropIfExists('provider_packages');

        Schema::table('provider_services', function (Blueprint $table) {
            $table->dropColumn('description');
        });
    }
};
