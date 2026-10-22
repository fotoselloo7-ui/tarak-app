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
        Schema::create('user_notifications', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->onDelete('cascade');
            $table->string('type', 50)->index();
            $table->string('title');
            $table->text('message');
            $table->string('resource_type', 50)->nullable()->index();
            $table->string('resource_id', 100)->nullable()->index();
            $table->string('action_url')->nullable();
            $table->json('metadata')->nullable();
            $table->string('idempotency_key', 191)->unique();
            $table->timestamp('read_at')->nullable()->index();
            $table->timestamps();

            $table->index(['user_id', 'read_at']);
            $table->index(['user_id', 'created_at']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('user_notifications');
    }
};
