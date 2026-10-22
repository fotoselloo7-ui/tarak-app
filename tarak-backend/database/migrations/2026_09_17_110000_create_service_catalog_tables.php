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
        // 1. Service Categories
        Schema::create('service_categories', function (Blueprint $table) {
            $table->string('id', 30)->primary(); // 'cat-1', 'cat-2'
            $table->string('name', 100);
            $table->string('slug', 100)->unique();
            $table->string('icon', 50)->nullable();
            $table->string('provider_type', 30)->default('both'); // 'barber', 'coiffeur', 'both'
            $table->boolean('is_active')->default(true)->index();
            $table->unsignedInteger('sort_order')->default(0);
            $table->timestamps();
        });

        // 2. Services
        Schema::create('services', function (Blueprint $table) {
            $table->id();
            $table->string('category_id', 30)->index();
            $table->string('name', 150);
            $table->string('slug', 150)->unique();
            $table->text('description')->nullable();
            $table->unsignedInteger('duration_minutes')->default(30);
            $table->decimal('base_price', 10, 2)->default(0.00);
            $table->string('icon_class', 100)->nullable();
            $table->boolean('is_active')->default(true)->index();
            $table->unsignedInteger('sort_order')->default(0);
            $table->timestamps();

            $table->foreign('category_id')
                ->references('id')
                ->on('service_categories')
                ->cascadeOnDelete();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('services');
        Schema::dropIfExists('service_categories');
    }
};
