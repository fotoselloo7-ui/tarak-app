<?php

namespace App\Console\Commands;

use App\Models\Appointment;
use App\Models\UserNotification;
use App\Models\UserPushPreference;
use App\Services\NotificationService;
use Carbon\Carbon;
use Illuminate\Console\Command;

class SendAppointmentRemindersCommand extends Command
{
    protected $signature = 'appointments:send-reminders';

    protected $description = 'Send configurable approaching-appointment reminders and exact-time alerts';

    public function handle(NotificationService $notifications): int
    {
        $tz = (string) config('app.timezone', 'Europe/Istanbul');
        $now = Carbon::now($tz);

        $appointments = Appointment::query()
            ->with(['customer', 'provider.providerProfile', 'staff', 'services'])
            ->where('status', Appointment::STATUS_CONFIRMED)
            ->whereBetween('appointment_date', [
                $now->copy()->subDay()->toDateString(),
                $now->copy()->addDays(2)->toDateString(),
            ])
            ->get();

        if ($appointments->isEmpty()) {
            $this->info('Sent appointment reminders: 0');
            return self::SUCCESS;
        }

        $userIds = $appointments
            ->flatMap(fn (Appointment $appt) => [$appt->customer_user_id, $appt->provider_user_id])
            ->filter()
            ->unique()
            ->values();

        $prefsByUser = UserPushPreference::query()
            ->whereIn('user_id', $userIds)
            ->get()
            ->keyBy('user_id');

        $hasReminderCols = UserPushPreference::hasReminderColumns();
        $sent = 0;

        foreach ($appointments as $appointment) {
            if (!$appointment->appointment_date || !$appointment->start_time) {
                continue;
            }

            $dateStr = $appointment->appointment_date->format('Y-m-d');
            $timeHm = substr((string) $appointment->start_time, 0, 5);
            try {
                $startAt = Carbon::parse("{$dateStr} {$timeHm}:00", $tz);
            } catch (\Throwable) {
                continue;
            }

            $minutesUntilStart = ($startAt->getTimestamp() - $now->getTimestamp()) / 60.0;
            $providerName = trim((string) ($appointment->provider?->providerProfile?->business_name ?: $appointment->provider?->name ?: 'Hizmet Veren'));
            $customerName = $appointment->customerDisplayName();
            $staffName = $appointment->staffDisplayName();
            $serviceSummary = $appointment->services->pluck('name')->filter()->implode(', ');

            // 1. Provider approaching-appointment reminder (works for both Tarak & guest manual appts)
            $providerPref = $prefsByUser->get($appointment->provider_user_id);
            $providerReminderEnabled = ($providerPref && $hasReminderCols && $providerPref->appointment_reminder_enabled !== null)
                ? (bool) $providerPref->appointment_reminder_enabled
                : true;
            $providerMinutes = ($providerPref && $hasReminderCols && $providerPref->appointment_reminder_minutes !== null)
                ? max(
                    UserPushPreference::MIN_REMINDER_MINUTES,
                    min(UserPushPreference::MAX_REMINDER_MINUTES, (int) $providerPref->appointment_reminder_minutes)
                )
                : UserPushPreference::DEFAULT_REMINDER_MINUTES;

            if ($providerReminderEnabled && $minutesUntilStart > 0 && $minutesUntilStart <= $providerMinutes) {
                $remaining = min($providerMinutes, max(1, (int) round($minutesUntilStart)));
                $staffClause = $staffName ? " ({$staffName})" : '';
                $notifications->notifyUser(
                    $appointment->provider_user_id,
                    UserNotification::TYPE_APPOINTMENT_REMINDER,
                    'Yaklaşan Randevu Hatırlatması',
                    "{$customerName} ile{$staffClause} saat {$timeHm} randevunuza {$remaining} dakika kaldı.",
                    UserNotification::RESOURCE_SCHEDULED_APPOINTMENT,
                    $appointment->id,
                    '/barber',
                    [
                        'appointment_date' => $dateStr,
                        'start_time' => $timeHm,
                        'staff_id' => $appointment->staff_id,
                        'staff_name' => $staffName,
                        'reminder_minutes' => $providerMinutes,
                        'reminder_stage' => 'approaching',
                    ],
                    "APPOINTMENT_REMINDER:PROVIDER:{$appointment->id}:{$dateStr}_{$timeHm}"
                );
                $sent++;
            }

            // Guest-only manual appointments never belong to a Tarak user account
            if ($appointment->customer_user_id === null || $appointment->is_guest_customer) {
                continue;
            }

            // 2. Customer approaching-appointment reminder (configurable minutes before)
            $customerPref = $prefsByUser->get($appointment->customer_user_id);
            $customerReminderEnabled = ($customerPref && $hasReminderCols && $customerPref->appointment_reminder_enabled !== null)
                ? (bool) $customerPref->appointment_reminder_enabled
                : true;
            $customerMinutes = ($customerPref && $hasReminderCols && $customerPref->appointment_reminder_minutes !== null)
                ? max(
                    UserPushPreference::MIN_REMINDER_MINUTES,
                    min(UserPushPreference::MAX_REMINDER_MINUTES, (int) $customerPref->appointment_reminder_minutes)
                )
                : UserPushPreference::DEFAULT_REMINDER_MINUTES;

            if ($customerReminderEnabled && $minutesUntilStart > 0 && $minutesUntilStart <= $customerMinutes) {
                $remaining = min($customerMinutes, max(1, (int) round($minutesUntilStart)));
                $custMsg = $staffName
                    ? "{$providerName}'nde {$staffName} ile" . ($serviceSummary !== '' ? " {$serviceSummary}" : '') . " saat {$timeHm} randevunuza {$remaining} dakika kaldı."
                    : "{$providerName} ile" . ($serviceSummary !== '' ? " {$serviceSummary}" : '') . " saat {$timeHm} randevunuza {$remaining} dakika kaldı.";

                $notifications->notifyUser(
                    $appointment->customer_user_id,
                    UserNotification::TYPE_APPOINTMENT_REMINDER,
                    'Randevu Hatırlatması',
                    $custMsg,
                    UserNotification::RESOURCE_SCHEDULED_APPOINTMENT,
                    $appointment->id,
                    '/customer',
                    [
                        'appointment_date' => $dateStr,
                        'start_time' => $timeHm,
                        'provider_name' => $providerName,
                        'staff_id' => $appointment->staff_id,
                        'staff_name' => $staffName,
                        'reminder_minutes' => $customerMinutes,
                        'reminder_stage' => 'approaching',
                    ],
                    "APPOINTMENT_REMINDER:CUSTOMER:{$appointment->id}:{$dateStr}_{$timeHm}"
                );
                $sent++;
            }

            // 3. Customer exact appointment-time alert (provider name, optional staff name, and exact time)
            $customerStartAlertEnabled = ($customerPref && $hasReminderCols && $customerPref->appointment_start_alert_enabled !== null)
                ? (bool) $customerPref->appointment_start_alert_enabled
                : true;

            if ($customerStartAlertEnabled && $minutesUntilStart <= 0 && $minutesUntilStart >= -10) {
                $startMsg = $staffName
                    ? "{$providerName}'nde {$staffName} ile saat {$timeHm} randevunuz başlıyor."
                    : "{$providerName} ile saat {$timeHm} randevunuz başlıyor.";

                $notifications->notifyUser(
                    $appointment->customer_user_id,
                    UserNotification::TYPE_APPOINTMENT_REMINDER,
                    'Randevu Saatiniz Geldi',
                    $startMsg,
                    UserNotification::RESOURCE_SCHEDULED_APPOINTMENT,
                    $appointment->id,
                    '/customer',
                    [
                        'appointment_date' => $dateStr,
                        'start_time' => $timeHm,
                        'provider_name' => $providerName,
                        'staff_id' => $appointment->staff_id,
                        'staff_name' => $staffName,
                        'reminder_stage' => 'start',
                    ],
                    "APPOINTMENT_START:CUSTOMER:{$appointment->id}:{$dateStr}_{$timeHm}"
                );
                $sent++;
            }
        }

        $this->info("Sent appointment reminders: {$sent}");
        return self::SUCCESS;
    }
}
