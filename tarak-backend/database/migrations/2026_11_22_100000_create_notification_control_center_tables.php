<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Notification Control Center, Promo-First Billing & Anti-Abuse Protection.
 * Purely additive: preserves existing wallet/commission/ad/birthday tables and immutable ledger rows.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('notification_ad_settings')) {
            Schema::table('notification_ad_settings', function (Blueprint $table) {
                if (!Schema::hasColumn('notification_ad_settings', 'birthday_unit_price')) {
                    $table->decimal('birthday_unit_price', 10, 2)->default(0.00);
                }
                if (!Schema::hasColumn('notification_ad_settings', 'allow_promo_for_birthday')) {
                    $table->boolean('allow_promo_for_birthday')->default(true);
                }
                if (!Schema::hasColumn('notification_ad_settings', 'allow_promo_for_notification_ads')) {
                    $table->boolean('allow_promo_for_notification_ads')->default(true);
                }
                if (!Schema::hasColumn('notification_ad_settings', 'fallback_to_cash_when_promo_insufficient')) {
                    $table->boolean('fallback_to_cash_when_promo_insufficient')->default(true);
                }
                if (!Schema::hasColumn('notification_ad_settings', 'default_daily_paid_notification_limit')) {
                    $table->unsignedSmallInteger('default_daily_paid_notification_limit')->default(100);
                }
                if (!Schema::hasColumn('notification_ad_settings', 'default_daily_unique_recipient_limit')) {
                    $table->unsignedSmallInteger('default_daily_unique_recipient_limit')->default(200);
                }
                if (!Schema::hasColumn('notification_ad_settings', 'birthday_max_per_provider_per_day')) {
                    $table->unsignedSmallInteger('birthday_max_per_provider_per_day')->default(100);
                }
                if (!Schema::hasColumn('notification_ad_settings', 'duplicate_content_window_hours')) {
                    $table->unsignedSmallInteger('duplicate_content_window_hours')->default(24);
                }
                if (!Schema::hasColumn('notification_ad_settings', 'rapid_campaign_window_minutes')) {
                    $table->unsignedSmallInteger('rapid_campaign_window_minutes')->default(30);
                }
                if (!Schema::hasColumn('notification_ad_settings', 'rapid_campaign_threshold')) {
                    $table->unsignedTinyInteger('rapid_campaign_threshold')->default(3);
                }
                if (!Schema::hasColumn('notification_ad_settings', 'auto_suspend_on_abuse')) {
                    $table->boolean('auto_suspend_on_abuse')->default(true);
                }
            });
        }

        if (!Schema::hasTable('provider_notification_controls')) {
            Schema::create('provider_notification_controls', function (Blueprint $table) {
                $table->id();
                $table->foreignId('provider_user_id')->unique()->constrained('users')->cascadeOnDelete();
                $table->boolean('can_send_notification_ads')->default(true);
                $table->timestamp('notification_ads_blocked_until')->nullable();
                $table->boolean('can_send_birthday_greetings')->default(true);
                $table->timestamp('birthday_blocked_until')->nullable();
                $table->boolean('can_send_auto_special_day')->default(true);
                $table->timestamp('auto_special_day_blocked_until')->nullable();
                $table->unsignedInteger('daily_paid_notification_limit')->nullable();
                $table->unsignedInteger('daily_unique_recipient_limit')->nullable();
                $table->string('restriction_reason', 500)->nullable();
                $table->foreignId('restricted_by_admin_id')->nullable()->constrained('users')->nullOnDelete();
                $table->timestamp('restricted_at')->nullable();
                $table->boolean('is_auto_restricted')->default(false);
                $table->timestamps();
            });
        }

        if (!Schema::hasTable('notification_dispatches')) {
            Schema::create('notification_dispatches', function (Blueprint $table) {
                $table->id();
                $table->string('reference_code', 80)->unique();
                $table->foreignId('provider_user_id')->constrained('users')->cascadeOnDelete();
                $table->foreignId('provider_profile_id')->nullable()->constrained('provider_profiles')->nullOnDelete();
                $table->string('notification_type', 40)->index();
                $table->string('source_type', 40)->nullable();
                $table->unsignedBigInteger('source_id')->nullable();
                $table->string('title', 200);
                $table->text('body');
                $table->string('pricing_mode', 24)->default('FREE');
                $table->decimal('unit_price', 10, 2)->default(0.00);
                $table->decimal('total_cost', 12, 2)->default(0.00);
                $table->decimal('reserved_promo_amount', 12, 2)->default(0.00);
                $table->decimal('reserved_cash_amount', 12, 2)->default(0.00);
                $table->decimal('captured_promo_amount', 12, 2)->default(0.00);
                $table->decimal('captured_cash_amount', 12, 2)->default(0.00);
                $table->decimal('refunded_promo_amount', 12, 2)->default(0.00);
                $table->decimal('refunded_cash_amount', 12, 2)->default(0.00);
                $table->string('balance_source', 24)->default('NONE');
                $table->unsignedInteger('targeted_count')->default(0);
                $table->unsignedInteger('eligible_count')->default(0);
                $table->unsignedInteger('attempted_count')->default(0);
                $table->unsignedInteger('fcm_accepted_count')->default(0);
                $table->unsignedInteger('failed_count')->default(0);
                $table->unsignedInteger('skipped_count')->default(0);
                $table->string('status', 30)->default('QUEUED')->index();
                $table->string('status_reason', 500)->nullable();
                $table->timestamp('sent_at')->nullable();
                $table->timestamp('completed_at')->nullable();
                $table->timestamps();

                $table->index(['provider_user_id', 'created_at'], 'notif_disp_prov_created_idx');
                $table->index(['notification_type', 'created_at'], 'notif_disp_type_created_idx');
                $table->index(['status', 'created_at'], 'notif_disp_status_created_idx');
                $table->index(['source_type', 'source_id'], 'notif_disp_source_idx');
            });
        }

        if (!Schema::hasTable('notification_dispatch_recipients')) {
            Schema::create('notification_dispatch_recipients', function (Blueprint $table) {
                $table->id();
                $table->foreignId('dispatch_id')->constrained('notification_dispatches')->cascadeOnDelete();
                $table->foreignId('provider_user_id')->constrained('users')->cascadeOnDelete();
                $table->foreignId('recipient_user_id')->constrained('users')->cascadeOnDelete();
                $table->foreignId('user_notification_id')->nullable()->constrained('user_notifications')->nullOnDelete();
                $table->foreignId('birthday_delivery_id')->nullable()->constrained('birthday_greeting_deliveries')->nullOnDelete();
                $table->string('billing_reference', 120)->unique();
                $table->decimal('unit_price', 10, 2)->default(0.00);
                $table->decimal('reserved_promo_amount', 10, 2)->default(0.00);
                $table->decimal('reserved_cash_amount', 10, 2)->default(0.00);
                $table->decimal('captured_promo_amount', 10, 2)->default(0.00);
                $table->decimal('captured_cash_amount', 10, 2)->default(0.00);
                $table->string('billing_status', 24)->default('FREE')->index();
                $table->string('delivery_status', 30)->default('QUEUED')->index();
                $table->string('delivery_error_code', 64)->nullable();
                $table->unsignedSmallInteger('device_attempts_count')->default(0);
                $table->unsignedSmallInteger('fcm_accepted_devices_count')->default(0);
                $table->timestamp('attempted_at')->nullable();
                $table->timestamp('settled_at')->nullable();
                $table->timestamps();

                $table->unique(['dispatch_id', 'recipient_user_id'], 'notif_disp_rec_unique');
                $table->index(['provider_user_id', 'recipient_user_id', 'created_at'], 'notif_disp_rec_prov_user_idx');
                $table->index(['user_notification_id'], 'notif_disp_rec_notif_idx');
            });
        }

        if (!Schema::hasTable('notification_abuse_alerts')) {
            Schema::create('notification_abuse_alerts', function (Blueprint $table) {
                $table->id();
                $table->foreignId('provider_user_id')->nullable()->constrained('users')->nullOnDelete();
                $table->foreignId('dispatch_id')->nullable()->constrained('notification_dispatches')->nullOnDelete();
                $table->string('alert_type', 50)->index();
                $table->string('severity', 16)->default('WARNING');
                $table->string('summary', 255);
                $table->json('details')->nullable();
                $table->string('auto_action_taken', 64)->nullable();
                $table->string('status', 20)->default('OPEN')->index();
                $table->foreignId('resolved_by_admin_id')->nullable()->constrained('users')->nullOnDelete();
                $table->timestamp('resolved_at')->nullable();
                $table->timestamps();
            });
        }

        if (Schema::hasTable('birthday_greeting_deliveries')) {
            Schema::table('birthday_greeting_deliveries', function (Blueprint $table) {
                if (!Schema::hasColumn('birthday_greeting_deliveries', 'dispatch_id')) {
                    $table->foreignId('dispatch_id')->nullable()->constrained('notification_dispatches')->nullOnDelete();
                }
                if (!Schema::hasColumn('birthday_greeting_deliveries', 'unit_price')) {
                    $table->decimal('unit_price', 10, 2)->default(0.00);
                }
                if (!Schema::hasColumn('birthday_greeting_deliveries', 'charged_amount')) {
                    $table->decimal('charged_amount', 10, 2)->default(0.00);
                }
                if (!Schema::hasColumn('birthday_greeting_deliveries', 'promo_amount')) {
                    $table->decimal('promo_amount', 10, 2)->default(0.00);
                }
                if (!Schema::hasColumn('birthday_greeting_deliveries', 'cash_amount')) {
                    $table->decimal('cash_amount', 10, 2)->default(0.00);
                }
                if (!Schema::hasColumn('birthday_greeting_deliveries', 'balance_source')) {
                    $table->string('balance_source', 20)->default('NONE');
                }
                if (!Schema::hasColumn('birthday_greeting_deliveries', 'billing_status')) {
                    $table->string('billing_status', 24)->default('FREE');
                }
                if (!Schema::hasColumn('birthday_greeting_deliveries', 'delivery_status')) {
                    $table->string('delivery_status', 30)->default('QUEUED');
                }
                if (!Schema::hasColumn('birthday_greeting_deliveries', 'failure_reason')) {
                    $table->string('failure_reason', 250)->nullable();
                }
                if (!Schema::hasColumn('birthday_greeting_deliveries', 'title_snapshot')) {
                    $table->string('title_snapshot', 200)->nullable();
                }
                if (!Schema::hasColumn('birthday_greeting_deliveries', 'message_snapshot')) {
                    $table->text('message_snapshot')->nullable();
                }
            });
        }

        if (Schema::hasTable('notification_ads')) {
            Schema::table('notification_ads', function (Blueprint $table) {
                if (!Schema::hasColumn('notification_ads', 'dispatch_id')) {
                    $table->foreignId('dispatch_id')->nullable()->constrained('notification_dispatches')->nullOnDelete();
                }
                if (!Schema::hasColumn('notification_ads', 'promo_amount')) {
                    $table->decimal('promo_amount', 10, 2)->default(0.00);
                }
                if (!Schema::hasColumn('notification_ads', 'cash_amount')) {
                    $table->decimal('cash_amount', 10, 2)->default(0.00);
                }
                if (!Schema::hasColumn('notification_ads', 'balance_source')) {
                    $table->string('balance_source', 20)->nullable();
                }
                if (!Schema::hasColumn('notification_ads', 'targeted_count')) {
                    $table->unsignedInteger('targeted_count')->default(0);
                }
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasTable('notification_ads')) {
            Schema::table('notification_ads', function (Blueprint $table) {
                if (Schema::hasColumn('notification_ads', 'dispatch_id')) {
                    $table->dropConstrainedForeignId('dispatch_id');
                }
                $cols = array_values(array_filter(['promo_amount', 'cash_amount', 'balance_source', 'targeted_count'], fn ($c) => Schema::hasColumn('notification_ads', $c)));
                if ($cols !== []) {
                    $table->dropColumn($cols);
                }
            });
        }

        if (Schema::hasTable('birthday_greeting_deliveries')) {
            Schema::table('birthday_greeting_deliveries', function (Blueprint $table) {
                if (Schema::hasColumn('birthday_greeting_deliveries', 'dispatch_id')) {
                    $table->dropConstrainedForeignId('dispatch_id');
                }
                $cols = array_values(array_filter([
                    'unit_price', 'charged_amount', 'promo_amount', 'cash_amount',
                    'balance_source', 'billing_status', 'delivery_status',
                    'failure_reason', 'title_snapshot', 'message_snapshot',
                ], fn ($c) => Schema::hasColumn('birthday_greeting_deliveries', $c)));
                if ($cols !== []) {
                    $table->dropColumn($cols);
                }
            });
        }

        Schema::dropIfExists('notification_abuse_alerts');
        Schema::dropIfExists('notification_dispatch_recipients');
        Schema::dropIfExists('notification_dispatches');
        Schema::dropIfExists('provider_notification_controls');

        if (Schema::hasTable('notification_ad_settings')) {
            Schema::table('notification_ad_settings', function (Blueprint $table) {
                $cols = array_values(array_filter([
                    'birthday_unit_price',
                    'allow_promo_for_birthday',
                    'allow_promo_for_notification_ads',
                    'fallback_to_cash_when_promo_insufficient',
                    'default_daily_paid_notification_limit',
                    'default_daily_unique_recipient_limit',
                    'birthday_max_per_provider_per_day',
                    'duplicate_content_window_hours',
                    'rapid_campaign_window_minutes',
                    'rapid_campaign_threshold',
                    'auto_suspend_on_abuse',
                ], fn ($c) => Schema::hasColumn('notification_ad_settings', $c)));
                if ($cols !== []) {
                    $table->dropColumn($cols);
                }
            });
        }
    }
};
