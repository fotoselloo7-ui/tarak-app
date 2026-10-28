<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('password_reset_codes', function (Blueprint $table) {
            $table->id();
            $table->string('email_hash', 64)->unique();
            $table->string('code_hash', 64);
            $table->unsignedTinyInteger('attempts')->default(0);
            $table->timestamp('expires_at');
            $table->timestamp('resend_after');
            $table->timestamp('consumed_at')->nullable();
            $table->timestamps();
            $table->index('expires_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('password_reset_codes');
    }
};
