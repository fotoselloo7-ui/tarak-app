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
        // 1. Expand Customer Profiles
        Schema::table('customer_profiles', function (Blueprint $table) {
            $table->date('birth_date')->nullable()->after('profile_completed');
            $table->string('avatar_url', 500)->nullable()->after('birth_date');
        });

        // 2. Expand Provider Profiles
        Schema::table('provider_profiles', function (Blueprint $table) {
            $table->string('work_mode', 20)->default('both')->after('provider_type'); // 'venue', 'mobile', 'both'
            $table->boolean('profile_completed')->default(false)->after('experience_years');
            $table->string('city', 100)->nullable()->after('profile_completed');
            $table->string('district', 100)->nullable()->after('city');
            $table->text('address_detail')->nullable()->after('district');
            $table->text('bio')->nullable()->after('address_detail');
            $table->string('title', 150)->nullable()->after('bio');
            $table->string('cover_url', 500)->nullable()->after('title');
            $table->smallInteger('cover_position_x')->default(50)->after('cover_url');
            $table->smallInteger('cover_position_y')->default(50)->after('cover_position_x');
            $table->json('gallery')->nullable()->after('cover_position_y');
        });

        // 3. Customer Saved Addresses
        Schema::create('customer_addresses', function (Blueprint $table) {
            $table->id();
            $table->foreignId('customer_profile_id')->constrained('customer_profiles')->cascadeOnDelete();
            $table->string('title', 50)->default('Ev'); // 'Ev', 'İş', 'Diğer'
            $table->string('province', 100);
            $table->string('district', 100);
            $table->string('neighborhood', 150)->nullable();
            $table->string('street', 200)->nullable();
            $table->string('building_no', 30)->nullable();
            $table->string('apartment_no', 30)->nullable();
            $table->text('directions')->nullable();
            $table->decimal('latitude', 10, 7)->nullable();
            $table->decimal('longitude', 10, 7)->nullable();
            $table->boolean('is_default')->default(false);
            $table->timestamps();
        });

        // 4. Provider Services (Pivot)
        Schema::create('provider_services', function (Blueprint $table) {
            $table->id();
            $table->foreignId('provider_profile_id')->constrained('provider_profiles')->cascadeOnDelete();
            $table->foreignId('service_id')->constrained('services')->cascadeOnDelete();
            $table->decimal('custom_price', 10, 2)->nullable();
            $table->unsignedInteger('custom_duration_minutes')->nullable();
            $table->boolean('is_active')->default(true);
            $table->timestamps();

            $table->unique(['provider_profile_id', 'service_id'], 'provider_service_unique');
        });

        // 5. Provider KYC Documents
        Schema::create('provider_documents', function (Blueprint $table) {
            $table->id();
            $table->foreignId('provider_profile_id')->constrained('provider_profiles')->cascadeOnDelete();
            $table->string('document_type', 40); // 'DIPLOMA', 'MASTER_CERTIFICATE', 'JOURNEYMAN_CERTIFICATE'
            $table->string('original_name', 255);
            $table->string('storage_path', 500);
            $table->string('mime_type', 100);
            $table->unsignedInteger('file_size'); // bytes
            $table->string('status', 30)->default('PENDING')->index(); // 'PENDING', 'APPROVED', 'REJECTED', 'REUPLOAD_REQUIRED'
            $table->text('rejection_reason')->nullable();
            $table->timestamp('uploaded_at')->useCurrent();
            $table->timestamp('reviewed_at')->nullable();
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('provider_documents');
        Schema::dropIfExists('provider_services');
        Schema::dropIfExists('customer_addresses');

        Schema::table('provider_profiles', function (Blueprint $table) {
            $table->dropColumn([
                'work_mode',
                'profile_completed',
                'city',
                'district',
                'address_detail',
                'bio',
                'title',
                'cover_url',
                'cover_position_x',
                'cover_position_y',
                'gallery',
            ]);
        });

        Schema::table('customer_profiles', function (Blueprint $table) {
            $table->dropColumn(['birth_date', 'avatar_url']);
        });
    }
};
