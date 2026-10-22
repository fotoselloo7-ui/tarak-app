<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Integration control-plane tables.
 *
 * - integration_settings : admin-managed credentials/toggles. Secret values are
 *   stored ENCRYPTED (Laravel Crypt via the model cast) and never returned raw.
 *   ENV/config stays the fallback so nothing existing breaks.
 * - integration_events   : safe observability trail for outbound/inbound calls
 *   (PayTR callbacks, SMS sends, test actions). NEVER stores secrets/payloads.
 * - sms_messages         : real SMS delivery log (recipient masked).
 * - scheduler_heartbeats : proves the cron/scheduler is actually running.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('integration_settings', function (Blueprint $table) {
            $table->id();
            $table->string('group', 40);              // paytr | sms | smtp | fcm | reverb
            $table->string('key', 80);
            $table->text('value')->nullable();        // encrypted at the model layer
            $table->boolean('is_secret')->default(false);
            $table->foreignId('updated_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();

            $table->unique(['group', 'key']);
        });

        Schema::create('integration_events', function (Blueprint $table) {
            $table->id();
            $table->string('integration', 40);        // paytr | sms | smtp | fcm | reverb | queue
            $table->string('event_type', 80);         // callback_received | test_sms | token_request ...
            $table->string('direction', 10);          // inbound | outbound
            $table->string('reference', 120)->nullable();
            $table->string('status', 20);             // success | failed | warning
            $table->unsignedSmallInteger('http_status')->nullable();
            $table->string('error_code', 80)->nullable();
            $table->text('error_message')->nullable(); // sanitised summary only
            $table->timestamp('occurred_at');
            $table->timestamps();

            $table->index(['integration', 'occurred_at']);
            $table->index(['integration', 'status']);
        });

        Schema::create('sms_messages', function (Blueprint $table) {
            $table->id();
            $table->string('provider', 40);
            $table->string('recipient_masked', 40);   // 0555***4567 — never the full number
            $table->string('recipient_hash', 64)->nullable();
            $table->string('template_key', 60)->nullable();
            $table->string('status', 20);             // queued | sent | failed
            $table->string('provider_message_id', 120)->nullable();
            $table->string('error_code', 60)->nullable();
            $table->text('error_message')->nullable();
            $table->foreignId('user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('sent_at')->nullable();
            $table->timestamps();

            $table->index(['provider', 'status']);
            $table->index('created_at');
        });

        Schema::create('scheduler_heartbeats', function (Blueprint $table) {
            $table->id();
            $table->string('task', 80)->unique();
            $table->timestamp('last_run_at')->nullable();
            $table->timestamp('last_success_at')->nullable();
            $table->string('status', 20)->default('unknown');
            $table->text('message')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('scheduler_heartbeats');
        Schema::dropIfExists('sms_messages');
        Schema::dropIfExists('integration_events');
        Schema::dropIfExists('integration_settings');
    }
};
