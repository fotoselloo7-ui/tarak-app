<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // A user blocking another user (chat is closed in both directions).
        Schema::create('user_blocks', function (Blueprint $table) {
            $table->id();
            $table->foreignId('blocker_user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('blocked_user_id')->constrained('users')->cascadeOnDelete();
            $table->timestamps();

            $table->unique(['blocker_user_id', 'blocked_user_id'], 'uniq_user_block');
            $table->index('blocked_user_id');
        });

        // User-generated content reports (chat messages, reviews) for admin moderation.
        Schema::create('content_reports', function (Blueprint $table) {
            $table->id();
            $table->foreignId('reporter_user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('reported_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('content_type', 20); // MESSAGE | REVIEW
            $table->unsignedBigInteger('content_id');
            $table->string('reason', 30); // SPAM | HARASSMENT | INAPPROPRIATE | FRAUD | OTHER
            $table->string('details', 1000)->nullable();
            // Copy of the reported text so the evidence survives moderation/removal.
            $table->text('content_snapshot')->nullable();
            $table->string('status', 20)->default('OPEN'); // OPEN | REVIEWING | ACTION_TAKEN | DISMISSED
            $table->foreignId('handled_by')->nullable()->constrained('users')->nullOnDelete();
            $table->text('admin_note')->nullable();
            $table->timestamp('handled_at')->nullable();
            $table->timestamps();

            // One report per reporter per content.
            $table->unique(['reporter_user_id', 'content_type', 'content_id'], 'uniq_content_report');
            $table->index(['status', 'created_at']);
            $table->index('reported_user_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('content_reports');
        Schema::dropIfExists('user_blocks');
    }
};
