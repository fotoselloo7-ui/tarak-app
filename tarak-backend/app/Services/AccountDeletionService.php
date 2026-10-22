<?php

namespace App\Services;

use App\Models\Appointment;
use App\Models\DisputeCase;
use App\Models\ServiceRequest;
use App\Models\User;
use Illuminate\Support\Facades\DB;

/**
 * Account closing rules shared by self-service deletion (AuthController) and the
 * admin panel: an account with open work cannot be closed, and a closed account
 * is anonymised and soft-deleted so history (payments, reviews) stays consistent.
 */
class AccountDeletionService
{
    /** Turkish reason the account cannot be closed yet, or null when it may be. */
    public function blockingReason(User $user): ?string
    {
        $hasOpenServiceRequest = ServiceRequest::query()
            ->where(function ($q) use ($user) {
                $q->where('customer_user_id', $user->id)
                    ->orWhere('assigned_provider_user_id', $user->id)
                    ->orWhere('target_provider_user_id', $user->id);
            })
            ->whereIn('status', [
                ServiceRequest::STATUS_OPEN,
                ServiceRequest::STATUS_ASSIGNED,
                ServiceRequest::STATUS_IN_PROGRESS,
                ServiceRequest::STATUS_AWAITING_CUSTOMER_CONFIRMATION,
            ])
            ->exists();

        if ($hasOpenServiceRequest) {
            return 'Devam eden bir Hemen Çağır talebiniz var. Hesabınızı silmeden önce bu talebi tamamlayın veya iptal edin.';
        }

        $hasOpenAppointment = Appointment::query()
            ->where(function ($q) use ($user) {
                $q->where('customer_user_id', $user->id)
                    ->orWhere('provider_user_id', $user->id);
            })
            ->whereIn('status', [
                Appointment::STATUS_PENDING,
                Appointment::STATUS_ALTERNATIVE_PROPOSED,
                Appointment::STATUS_CONFIRMED,
                Appointment::STATUS_IN_PROGRESS,
                Appointment::STATUS_AWAITING_CUSTOMER_CONFIRMATION,
            ])
            ->exists();

        if ($hasOpenAppointment) {
            return 'Devam eden bir randevunuz var. Hesabınızı silmeden önce bu randevuyu tamamlayın veya iptal edin.';
        }

        $hasOpenDispute = DisputeCase::query()
            ->where(function ($q) use ($user) {
                $q->where('customer_user_id', $user->id)
                    ->orWhere('provider_user_id', $user->id);
            })
            ->whereIn('status', [
                DisputeCase::STATUS_OPEN,
                DisputeCase::STATUS_UNDER_REVIEW,
            ])
            ->exists();

        if ($hasOpenDispute) {
            return 'Devam eden bir uyuşmazlık kaydınız var. Hesabınızı silmeden önce destek ekibiyle çözüme kavuşturun.';
        }

        if ($user->role === User::ROLE_PROVIDER) {
            $wallet = $user->wallet;
            if ($wallet && ((float) $wallet->balance > 0 || (float) $wallet->reserved_cash_balance > 0)) {
                return 'Cüzdanınızda bakiye bulunuyor. Hesabınızı silmeden önce bakiyenizi çekin veya destek ekibiyle iletişime geçin.';
            }
        }

        return null;
    }

    /** Revokes sessions, anonymises personal fields and soft-deletes the user. */
    public function anonymizeAndDelete(User $user): void
    {
        DB::transaction(function () use ($user) {
            $user->tokens()->delete();

            $user->update([
                'first_name' => 'Silinmiş',
                'last_name' => 'Kullanıcı',
                'name' => 'Silinmiş Kullanıcı',
                'email' => $user->email ? 'deleted_user_' . $user->id . '@berberimgelsin.invalid' : null,
                'phone' => null,
                'avatar_url' => null,
                'status' => 'deleted',
            ]);

            $user->delete();
        });
    }
}
