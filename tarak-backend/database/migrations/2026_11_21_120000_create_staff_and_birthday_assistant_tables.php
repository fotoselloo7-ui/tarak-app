<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable('provider_staff')) {
            Schema::create('provider_staff', function (Blueprint $table) {
                $table->id();
                $table->foreignId('provider_profile_id')->constrained('provider_profiles')->cascadeOnDelete();
                $table->string('first_name', 80);
                $table->string('last_name', 80);
                $table->string('photo_url', 500)->nullable();
                $table->string('title', 100)->nullable();
                $table->string('specialty', 160)->nullable();
                $table->boolean('is_active')->default(true);
                $table->boolean('accepts_appointments')->default(true);
                $table->boolean('visible_to_customers')->default(true);
                $table->unsignedInteger('sort_order')->default(0);
                $table->timestamp('archived_at')->nullable();
                $table->timestamps();

                $table->index(
                    ['provider_profile_id', 'is_active', 'accepts_appointments', 'visible_to_customers'],
                    'provider_staff_eligibility_idx'
                );
            });
        }

        if (!Schema::hasTable('provider_staff_services')) {
            Schema::create('provider_staff_services', function (Blueprint $table) {
                $table->id();
                $table->foreignId('provider_staff_id')->constrained('provider_staff')->cascadeOnDelete();
                $table->foreignId('service_id')->constrained('services')->cascadeOnDelete();
                $table->unsignedSmallInteger('custom_duration_minutes')->nullable();
                $table->boolean('is_active')->default(true);
                $table->timestamps();

                $table->unique(['provider_staff_id', 'service_id'], 'staff_service_unique');
            });
        }

        if (!Schema::hasTable('provider_staff_weekly_schedules')) {
            Schema::create('provider_staff_weekly_schedules', function (Blueprint $table) {
                $table->id();
                $table->foreignId('provider_staff_id')->constrained('provider_staff')->cascadeOnDelete();
                $table->string('day_of_week', 16);
                $table->boolean('is_enabled')->default(true);
                $table->time('start_time')->nullable()->default('09:00');
                $table->time('end_time')->nullable()->default('19:00');
                $table->timestamps();

                $table->unique(['provider_staff_id', 'day_of_week'], 'staff_weekly_day_unique');
            });
        }

        if (!Schema::hasTable('provider_staff_schedule_breaks')) {
            Schema::create('provider_staff_schedule_breaks', function (Blueprint $table) {
                $table->id();
                $table->unsignedBigInteger('staff_weekly_schedule_id');
                $table->time('start_time');
                $table->time('end_time');
                $table->timestamps();

                $table->foreign('staff_weekly_schedule_id', 'staff_breaks_weekly_fk')
                    ->references('id')
                    ->on('provider_staff_weekly_schedules')
                    ->cascadeOnDelete();
            });
        }

        if (!Schema::hasTable('provider_staff_time_offs')) {
            Schema::create('provider_staff_time_offs', function (Blueprint $table) {
                $table->id();
                $table->foreignId('provider_staff_id')->constrained('provider_staff')->cascadeOnDelete();
                $table->date('start_date');
                $table->date('end_date');
                $table->time('start_time')->nullable();
                $table->time('end_time')->nullable();
                $table->string('reason', 60)->default('izin');
                $table->text('note')->nullable();
                $table->timestamps();

                $table->index(['provider_staff_id', 'start_date', 'end_date'], 'staff_time_offs_range_idx');
            });
        }

        if (!Schema::hasTable('provider_birthday_settings')) {
            Schema::create('provider_birthday_settings', function (Blueprint $table) {
                $table->id();
                $table->foreignId('provider_profile_id')->constrained('provider_profiles')->cascadeOnDelete();
                $table->boolean('is_enabled')->default(false);
                $table->boolean('send_on_birthday')->default(true);
                $table->boolean('send_one_day_before')->default(false);
                $table->boolean('send_two_days_before')->default(false);
                $table->string('send_time', 5)->default('10:00');
                $table->string('template_key', 40)->default('classic');
                $table->text('custom_message')->nullable();
                $table->string('required_plan_tier', 30)->nullable();
                $table->timestamps();

                $table->unique('provider_profile_id', 'provider_birthday_settings_profile_unique');
            });
        }

        if (!Schema::hasTable('birthday_greeting_deliveries')) {
            Schema::create('birthday_greeting_deliveries', function (Blueprint $table) {
                $table->id();
                $table->foreignId('provider_profile_id')->constrained('provider_profiles')->cascadeOnDelete();
                $table->foreignId('customer_user_id')->constrained('users')->cascadeOnDelete();
                $table->unsignedSmallInteger('birthday_year');
                $table->unsignedTinyInteger('days_before')->default(0);
                $table->date('celebration_date');
                $table->timestamp('sent_at')->useCurrent();
                $table->foreignId('user_notification_id')->nullable()->constrained('user_notifications')->nullOnDelete();
                $table->timestamps();

                $table->unique(
                    ['provider_profile_id', 'customer_user_id', 'birthday_year'],
                    'birthday_deliveries_unique'
                );
            });
        }

        if (Schema::hasTable('user_push_preferences') && !Schema::hasColumn('user_push_preferences', 'birthday_greeting_enabled')) {
            Schema::table('user_push_preferences', function (Blueprint $table) {
                $afterCol = Schema::hasColumn('user_push_preferences', 'appointment_start_alert_enabled')
                    ? 'appointment_start_alert_enabled'
                    : 'campaign_enabled';
                $table->boolean('birthday_greeting_enabled')
                    ->default(false)
                    ->after($afterCol);
            });
        }

        if (Schema::hasTable('appointments')) {
            $isMysql = DB::getDriverName() === 'mysql';
            if ($isMysql) {
                Schema::table('appointments', function (Blueprint $table) {
                    $table->dropForeign(['customer_user_id']);
                });
            }

            Schema::table('appointments', function (Blueprint $table) {
                $table->unsignedBigInteger('customer_user_id')->nullable()->change();

                if (!Schema::hasColumn('appointments', 'staff_id')) {
                    $table->foreignId('staff_id')
                        ->nullable()
                        ->after('provider_user_id')
                        ->constrained('provider_staff')
                        ->nullOnDelete();
                }
                if (!Schema::hasColumn('appointments', 'staff_name_snapshot')) {
                    $table->string('staff_name_snapshot', 160)->nullable()->after('staff_id');
                }
                if (!Schema::hasColumn('appointments', 'staff_selection_mode')) {
                    $table->string('staff_selection_mode', 20)->default('LEGACY')->after('staff_name_snapshot');
                }
                if (!Schema::hasColumn('appointments', 'booking_source')) {
                    $table->string('booking_source', 30)->default('CUSTOMER_APP')->after('staff_selection_mode');
                }
                if (!Schema::hasColumn('appointments', 'is_guest_customer')) {
                    $table->boolean('is_guest_customer')->default(false)->after('booking_source');
                }
                if (!Schema::hasColumn('appointments', 'guest_customer_name')) {
                    $table->string('guest_customer_name', 120)->nullable()->after('is_guest_customer');
                }
                if (!Schema::hasColumn('appointments', 'guest_customer_phone')) {
                    $table->string('guest_customer_phone', 30)->nullable()->after('guest_customer_name');
                }
                if (!Schema::hasColumn('appointments', 'guest_customer_consent')) {
                    $table->boolean('guest_customer_consent')->default(false)->after('guest_customer_phone');
                }
                if (!Schema::hasColumn('appointments', 'created_by_user_id')) {
                    $table->foreignId('created_by_user_id')
                        ->nullable()
                        ->after('guest_customer_consent')
                        ->constrained('users')
                        ->nullOnDelete();
                }

                $table->index(
                    ['provider_user_id', 'staff_id', 'appointment_date', 'status'],
                    'appointments_provider_staff_date_status_idx'
                );
            });

            if ($isMysql) {
                Schema::table('appointments', function (Blueprint $table) {
                    $table->foreign('customer_user_id')
                        ->references('id')
                        ->on('users')
                        ->nullOnDelete();
                });
            }
        }
    }

    public function down(): void
    {
        if (Schema::hasTable('appointments')) {
            $isMysql = DB::getDriverName() === 'mysql';

            try {
                Schema::table('appointments', function (Blueprint $table) {
                    $table->dropIndex('appointments_provider_staff_date_status_idx');
                });
            } catch (\Throwable) {
            }

            Schema::table('appointments', function (Blueprint $table) {
                if (Schema::hasColumn('appointments', 'created_by_user_id')) {
                    $table->dropConstrainedForeignId('created_by_user_id');
                }
                if (Schema::hasColumn('appointments', 'staff_id')) {
                    $table->dropConstrainedForeignId('staff_id');
                }
            });

            $scalarCols = array_values(array_filter([
                'staff_name_snapshot',
                'staff_selection_mode',
                'booking_source',
                'is_guest_customer',
                'guest_customer_name',
                'guest_customer_phone',
                'guest_customer_consent',
            ], fn (string $col) => Schema::hasColumn('appointments', $col)));

            if ($scalarCols !== []) {
                Schema::table('appointments', function (Blueprint $table) use ($scalarCols) {
                    $table->dropColumn($scalarCols);
                });
            }

            if (!DB::table('appointments')->whereNull('customer_user_id')->exists()) {
                if ($isMysql) {
                    Schema::table('appointments', function (Blueprint $table) {
                        $table->dropForeign(['customer_user_id']);
                    });
                }
                Schema::table('appointments', function (Blueprint $table) {
                    $table->unsignedBigInteger('customer_user_id')->nullable(false)->change();
                });
                if ($isMysql) {
                    Schema::table('appointments', function (Blueprint $table) {
                        $table->foreign('customer_user_id')
                            ->references('id')
                            ->on('users')
                            ->cascadeOnDelete();
                    });
                }
            }
        }

        if (Schema::hasTable('user_push_preferences') && Schema::hasColumn('user_push_preferences', 'birthday_greeting_enabled')) {
            Schema::table('user_push_preferences', function (Blueprint $table) {
                $table->dropColumn('birthday_greeting_enabled');
            });
        }

        Schema::dropIfExists('birthday_greeting_deliveries');
        Schema::dropIfExists('provider_birthday_settings');
        Schema::dropIfExists('provider_staff_time_offs');
        Schema::dropIfExists('provider_staff_schedule_breaks');
        Schema::dropIfExists('provider_staff_weekly_schedules');
        Schema::dropIfExists('provider_staff_services');
        Schema::dropIfExists('provider_staff');
    }
};
