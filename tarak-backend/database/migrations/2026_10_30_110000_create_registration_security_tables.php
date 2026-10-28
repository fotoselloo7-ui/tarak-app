<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('registration_verifications', function (Blueprint $table) {
            $table->id();
            $table->string('channel', 10);
            $table->string('destination_hash', 64);
            $table->string('code_hash', 64);
            $table->string('proof_hash', 64)->nullable();
            $table->unsignedTinyInteger('attempts')->default(0);
            $table->timestamp('expires_at');
            $table->timestamp('resend_after');
            $table->timestamp('verified_at')->nullable();
            $table->timestamp('consumed_at')->nullable();
            $table->timestamps();
            $table->unique(['channel', 'destination_hash'], 'registration_verification_destination');
            $table->index('expires_at');
        });

        Schema::create('social_auth_attempts', function (Blueprint $table) {
            $table->id();
            $table->string('token_hash', 64)->unique();
            $table->string('provider', 12);
            $table->string('subject', 255);
            $table->string('email', 255)->nullable();
            $table->boolean('email_verified')->default(false);
            $table->string('first_name', 100)->nullable();
            $table->string('last_name', 100)->nullable();
            $table->timestamp('expires_at');
            $table->timestamp('consumed_at')->nullable();
            $table->timestamps();
            $table->index('expires_at');
        });

        Schema::create('social_identities', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('provider', 12);
            $table->string('subject', 255);
            $table->string('email_at_link', 255)->nullable();
            $table->timestamps();
            $table->unique(['provider', 'subject']);
            $table->unique(['user_id', 'provider']);
        });

        Schema::create('registration_consents', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->unique()->constrained('users')->cascadeOnDelete();
            $table->timestamp('terms_accepted_at');
            $table->timestamp('kvkk_acknowledged_at');
            $table->timestamp('marketing_consented_at')->nullable();
            $table->string('terms_version', 40)->default('current');
            $table->string('kvkk_version', 40)->default('current');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('registration_consents');
        Schema::dropIfExists('social_identities');
        Schema::dropIfExists('social_auth_attempts');
        Schema::dropIfExists('registration_verifications');
    }
};
