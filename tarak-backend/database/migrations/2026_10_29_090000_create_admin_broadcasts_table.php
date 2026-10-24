<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/** Independent from provider-paid notification advertisements. */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('admin_broadcasts', function (Blueprint $table) {
            $table->id();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->string('kind', 24)->default('system');
            $table->string('audience', 20)->default('all');
            $table->string('province', 120)->nullable();
            $table->string('district', 120)->nullable();
            $table->string('title', 100);
            $table->text('body');
            $table->string('sponsor_name', 120)->nullable();
            $table->string('action_url', 255)->nullable();
            $table->string('status', 24)->default('DRAFT');
            $table->timestamp('scheduled_at')->nullable();
            $table->timestamp('started_at')->nullable();
            $table->timestamp('finished_at')->nullable();
            $table->unsignedBigInteger('last_user_id')->default(0);
            $table->unsignedInteger('estimated_recipients')->default(0);
            $table->unsignedInteger('processed_recipients')->default(0);
            $table->unsignedInteger('notifications_created')->default(0);
            $table->timestamp('last_enqueued_at')->nullable();
            $table->text('failure_message')->nullable();
            $table->timestamps();
            $table->index(['status', 'scheduled_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('admin_broadcasts');
    }
};
