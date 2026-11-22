<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable('user_push_preferences')) {
            return;
        }

        Schema::table('user_push_preferences', function (Blueprint $table) {
            if (!Schema::hasColumn('user_push_preferences', 'appointment_reminder_enabled')) {
                $table->boolean('appointment_reminder_enabled')
                    ->default(true)
                    ->after('campaign_enabled');
            }
            if (!Schema::hasColumn('user_push_preferences', 'appointment_reminder_minutes')) {
                $table->unsignedSmallInteger('appointment_reminder_minutes')
                    ->default(30)
                    ->after('appointment_reminder_enabled');
            }
            if (!Schema::hasColumn('user_push_preferences', 'appointment_start_alert_enabled')) {
                $table->boolean('appointment_start_alert_enabled')
                    ->default(true)
                    ->after('appointment_reminder_minutes');
            }
        });
    }

    public function down(): void
    {
        if (!Schema::hasTable('user_push_preferences')) {
            return;
        }

        $columns = array_values(array_filter([
            Schema::hasColumn('user_push_preferences', 'appointment_reminder_enabled')
                ? 'appointment_reminder_enabled'
                : null,
            Schema::hasColumn('user_push_preferences', 'appointment_reminder_minutes')
                ? 'appointment_reminder_minutes'
                : null,
            Schema::hasColumn('user_push_preferences', 'appointment_start_alert_enabled')
                ? 'appointment_start_alert_enabled'
                : null,
        ]));

        if ($columns !== []) {
            Schema::table('user_push_preferences', function (Blueprint $table) use ($columns) {
                $table->dropColumn($columns);
            });
        }
    }
};
