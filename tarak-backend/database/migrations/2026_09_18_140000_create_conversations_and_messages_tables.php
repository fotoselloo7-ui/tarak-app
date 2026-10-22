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
        Schema::create('conversations', function (Blueprint $table) {
            $table->id();
            $table->string('resource_type', 50); // 'INSTANT_REQUEST', 'SCHEDULED_APPOINTMENT'
            $table->unsignedBigInteger('resource_id');
            $table->foreignId('customer_user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('provider_user_id')->constrained('users')->cascadeOnDelete();
            $table->string('status', 20)->default('ACTIVE'); // 'ACTIVE', 'READ_ONLY', 'CLOSED'
            $table->timestamp('last_message_at')->nullable();
            $table->timestamps();

            $table->unique(['resource_type', 'resource_id'], 'uq_conv_resource');
            $table->index(['customer_user_id', 'status'], 'idx_conv_customer');
            $table->index(['provider_user_id', 'status'], 'idx_conv_provider');
        });

        Schema::create('conversation_messages', function (Blueprint $table) {
            $table->id();
            $table->foreignId('conversation_id')->constrained('conversations')->cascadeOnDelete();
            $table->foreignId('sender_user_id')->constrained('users')->cascadeOnDelete();
            $table->text('body');
            $table->string('status', 20)->default('SENT'); // 'SENT', 'READ'
            $table->timestamps();

            $table->index(['conversation_id', 'created_at'], 'idx_msg_conv_time');
            $table->index(['conversation_id', 'sender_user_id', 'status'], 'idx_msg_conv_sender_status');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('conversation_messages');
        Schema::dropIfExists('conversations');
    }
};
