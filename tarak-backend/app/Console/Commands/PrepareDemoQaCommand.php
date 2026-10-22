<?php

namespace App\Console\Commands;

use App\Models\CommissionReservation;
use App\Models\LocationShareGrant;
use App\Models\ServiceOffer;
use App\Models\ServicePayment;
use App\Models\ServiceRequest;
use App\Models\User;
use App\Models\Wallet;
use App\Models\WalletTransaction;
use App\Services\FinancialService;
use App\Services\LocationGrantService;
use App\Services\ServiceLifecycleService;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use RuntimeException;

/** Explicit local QA preparation; never a production seed or HTTP capability. */
class PrepareDemoQaCommand extends Command
{
    protected $signature = 'qa:prepare-demo {--request= : Unstarted demo request to cancel} {--commission=6000 : Minimum usable demo commission in TRY}';
    protected $description = 'Prepare the named local demo provider without altering production financial rules';

    public function handle(FinancialService $finance, LocationGrantService $location, ServiceLifecycleService $lifecycle): int
    {
        if (!app()->environment(['local', 'testing'])) {
            $this->error('Demo QA preparation is restricted to local/testing.');
            return self::FAILURE;
        }
        if (app()->environment('local') && !in_array(config('database.connections.'.config('database.default').'.host'), ['127.0.0.1', 'localhost', '::1'], true)) {
            $this->error('Local QA requires a loopback database.');
            return self::FAILURE;
        }

        try {
            $target = FinancialService::parseToCents($this->option('commission'));
            if ($target < 500000 || $target > 1000000) {
                throw new RuntimeException('Demo usable commission target must be between TRY 5000 and 10000.');
            }
            $result = DB::transaction(function () use ($target, $finance, $location, $lifecycle) {
                $customer = User::where('email', 'customer@berberimgelsin.com')->where('role', 'CUSTOMER')->firstOrFail();
                $provider = User::where('email', 'provider@berberimgelsin.com')->where('role', 'PROVIDER')->firstOrFail();
                $requestId = $this->option('request');
                if ($requestId !== null) {
                    $request = ServiceRequest::lockForUpdate()->findOrFail((int) $requestId);
                    if ((int) $request->customer_user_id !== (int) $customer->id
                        || !in_array((int) ($request->assigned_provider_user_id ?? $request->target_provider_user_id), [(int) $provider->id], true)
                        || !((int) $request->id === 232 || str_starts_with($request->customer_note ?? '', 'FAZ4_QA'))
                        || !in_array($request->status, ['OPEN', 'ASSIGNED', 'CANCELLED'], true)
                        || $request->service_started_at !== null) {
                        throw new RuntimeException('Only this demo pair\'s named, unstarted QA request may be reset.');
                    }
                    $type = LocationShareGrant::RESOURCE_INSTANT_REQUEST;
                    $payment = ServicePayment::where('resource_type', $type)->where('resource_id', $request->id)->lockForUpdate()->first();
                    $reservation = CommissionReservation::where('resource_type', $type)->where('resource_id', $request->id)->lockForUpdate()->first();
                    if (($payment && (!in_array($payment->status, ['PENDING', 'CANCELLED'], true)
                            || $payment->gateway_reference || $payment->held_at || $payment->settled_at || $payment->refunds()->exists()))
                        || ($reservation && !in_array($reservation->status, ['RESERVED', 'RELEASED'], true))) {
                        throw new RuntimeException('Paid, captured, disputed or gateway-linked financial records cannot be QA reset.');
                    }
                    if ($request->status !== ServiceRequest::STATUS_CANCELLED) {
                        $finance->releaseCashCommission($type, $request->id, 'LOCAL_DEMO_QA_RESET');
                        $finance->cancelOnlinePayment($type, $request->id);
                        $location->expireGrantsForResource($type, $request->id, 'LOCAL_DEMO_QA_RESET');
                        $lifecycle->cancelVerificationForResource($type, $request->id);
                        $request->offers()->whereIn('status', ['PENDING', 'ACCEPTED'])
                            ->update(['status' => ServiceOffer::STATUS_REJECTED, 'rejected_at' => now()]);
                        $request->update(['status' => ServiceRequest::STATUS_CANCELLED,
                            'cancelled_at' => now(), 'accepted_offer_id' => null]);
                        // Historical provider/assigned_at remain; CANCELLED is non-active.
                    }
                }
                $wallet = Wallet::where('user_id', $provider->id)->lockForUpdate()->firstOrFail();
                if ($wallet->is_frozen) throw new RuntimeException('Frozen wallet must not be bypassed.');
                $delta = max(0, $target - FinancialService::parseToCents($wallet->usable_commission_balance));
                if ($delta > 0) {
                    $wallet->promo_balance = FinancialService::formatFromCents(FinancialService::parseToCents($wallet->promo_balance) + $delta);
                    $wallet->save();
                    WalletTransaction::create([
                        'wallet_id' => $wallet->id, 'user_id' => $provider->id,
                        'type' => WalletTransaction::TYPE_ADMIN_ADJUSTMENT,
                        'direction' => WalletTransaction::DIRECTION_CREDIT,
                        'bucket' => WalletTransaction::BUCKET_PROMO,
                        'amount' => FinancialService::formatFromCents($delta),
                        'reference_type' => 'LOCAL_DEMO_QA', 'reference_id' => $provider->id,
                        'idempotency_key' => 'LOCAL_DEMO_QA:'.(string) \Illuminate\Support\Str::uuid(),
                        'description' => 'Yerel demo test başlangıç bakiyesi',
                        'metadata' => ['environment' => app()->environment(), 'usable_target' => FinancialService::formatFromCents($target)],
                        'created_at' => now(),
                    ]);
                }
                return ['request_id' => $requestId, 'demo_credit' => FinancialService::formatFromCents($delta),
                    'usable_commission' => $wallet->fresh()->usable_commission_balance];
            });
            $this->line(json_encode($result, JSON_UNESCAPED_UNICODE));
            return self::SUCCESS;
        } catch (\Throwable $error) {
            $this->error($error->getMessage());
            return self::FAILURE;
        }
    }
}
