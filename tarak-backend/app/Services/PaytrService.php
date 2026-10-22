<?php

namespace App\Services;

use App\Models\Appointment;
use App\Models\PaymentGatewayAttempt;
use App\Models\ServiceLifecycleEvent;
use App\Models\ServicePayment;
use App\Models\ServiceRequest;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException;
use Symfony\Component\HttpKernel\Exception\UnprocessableEntityHttpException;

class PaytrService
{
    public function __construct(protected IntegrationSettings $settings)
    {
    }

    /**
     * CANONICAL credential resolver for the whole PayTR surface
     * (payment token, callback hash, refund, marketplace payout).
     *
     * Priority — matches the contract documented on IntegrationSettings:
     *   1. encrypted admin override (integration_settings)
     *   2. ENV / config('paytr.*')
     *   3. null
     *
     * Never log or return these values; callers use them only to build
     * provider requests/hashes.
     */
    protected function credential(string $key, mixed $default = null): mixed
    {
        return $this->settings->get('paytr', $key, $default);
    }

    /**
     * Check if PayTR credentials are configured (admin override OR environment).
     */
    public function isConfigured(): bool
    {
        return !empty($this->credential('merchant_id'))
            && !empty($this->credential('merchant_key'))
            && !empty($this->credential('merchant_salt'));
    }

    /**
     * Generate unique, alphanumeric merchant_oid (<= 64 chars).
     */
    public function generateMerchantOid(string $prefix = 'BG'): string
    {
        do {
            $oid = $prefix . date('ymdHis') . strtoupper(Str::random(12));
        } while (PaymentGatewayAttempt::where('merchant_oid', $oid)->exists()
            || \App\Models\FeaturedOrder::where('merchant_oid', $oid)->exists()
            || \App\Models\NotificationAd::where('merchant_oid', $oid)->exists());

        return $oid;
    }

    /**
     * PayTR iFrame token for a payment that is not a customer service payment (e.g. a provider
     * buying an "öne çıkarma" package). Same credentials, hash formula and endpoint as
     * requestIframeToken(); the caller owns the order record and the callback handling.
     *
     * @param list<array{0: string, 1: string, 2: int}> $basket [name, unit price "99.00", quantity]
     * @return array{token: string, iframe_url: string}
     */
    public function requestHostedToken(string $merchantOid, int $amountMinor, array $basket, string $email, string $name, string $phone, ?string $clientIp = null): array
    {
        if (!$this->isConfigured()) {
            throw new \LogicException('PayTR ödeme sistemi henüz yapılandırılmamış.');
        }

        $merchantId = (string) $this->credential('merchant_id');
        $merchantKey = (string) $this->credential('merchant_key');
        $merchantSalt = (string) $this->credential('merchant_salt');

        $ip = $clientIp ?: request()->ip() ?: '127.0.0.1';
        $userBasket = base64_encode(json_encode($basket, JSON_UNESCAPED_UNICODE));
        $noInstallment = 1;
        $maxInstallment = 0;
        $currency = (string) config('paytr.currency', 'TL');
        $testMode = (int) $this->credential('test_mode', 1);

        $hashStr = $merchantId . $ip . $merchantOid . $email . $amountMinor . $userBasket . $noInstallment . $maxInstallment . $currency . $testMode;
        $paytrToken = base64_encode(hash_hmac('sha256', $hashStr . $merchantSalt, $merchantKey, true));

        $response = Http::asForm()->timeout(20)->post('https://www.paytr.com/odeme/api/get-token', [
            'merchant_id' => $merchantId,
            'user_ip' => $ip,
            'merchant_oid' => $merchantOid,
            'email' => $email,
            'payment_amount' => $amountMinor,
            'paytr_token' => $paytrToken,
            'user_basket' => $userBasket,
            'user_name' => $name,
            'user_address' => 'İstanbul',
            'user_phone' => $phone,
            'merchant_ok_url' => $this->credential('ok_url'),
            'merchant_fail_url' => $this->credential('fail_url'),
            'timeout_limit' => config('paytr.timeout_limit', 30),
            'currency' => $currency,
            'test_mode' => $testMode,
            'no_installment' => $noInstallment,
            'max_installment' => $maxInstallment,
            'debug_on' => config('paytr.debug_on', 1),
            'client_lang' => 'tr',
            'payment_type' => 'card',
            'iframe_v2' => config('paytr.iframe_v2', 1),
        ]);

        if (!$response->successful()) {
            throw new UnprocessableEntityHttpException('PayTR servisine bağlanılamadı.');
        }

        $data = $response->json();
        if (($data['status'] ?? null) !== 'success' || empty($data['token'])) {
            throw new UnprocessableEntityHttpException('PayTR token oluşturulamadı: ' . ($data['reason'] ?? 'Bilinmeyen hata'));
        }

        return ['token' => $data['token'], 'iframe_url' => "https://www.paytr.com/odeme/guvenli/{$data['token']}"];
    }

    /**
     * Build PayTR user_basket JSON string encoded in base64.
     */
    public function buildUserBasket(ServicePayment $payment): string
    {
        $items = [];

        if ($payment->resource_type === ServicePayment::RESOURCE_INSTANT_REQUEST) {
            $req = ServiceRequest::with('services')->find($payment->resource_id);
            if ($req && $req->services->isNotEmpty()) {
                $count = $req->services->count();
                $splitPrice = number_format((float) $payment->gross_amount / max(1, $count), 2, '.', '');
                foreach ($req->services as $s) {
                    $items[] = [$s->name, $splitPrice, 1];
                }
            }
        } elseif ($payment->resource_type === ServicePayment::RESOURCE_SCHEDULED_APPOINTMENT) {
            $appt = Appointment::with('services')->find($payment->resource_id);
            if ($appt && $appt->services->isNotEmpty()) {
                foreach ($appt->services as $s) {
                    $price = isset($s->pivot->price_snapshot)
                        ? number_format((float) $s->pivot->price_snapshot, 2, '.', '')
                        : number_format((float) $payment->gross_amount / max(1, $appt->services->count()), 2, '.', '');
                    $items[] = [$s->name, $price, 1];
                }
            }
        }

        if (empty($items)) {
            $items[] = ['Tarak Hizmet Bedeli', number_format((float) $payment->gross_amount, 2, '.', ''), 1];
        }

        return base64_encode(json_encode($items, JSON_UNESCAPED_UNICODE));
    }

    /**
     * Request PayTR iFrame token for a customer's pending online payment.
     */
    public function requestIframeToken(ServicePayment $payment, User $customer, ?string $clientIp = null): array
    {
        if (!$this->isConfigured()) {
            throw new \LogicException('PayTR ödeme sistemi henüz yapılandırılmamış.');
        }

        if (strtoupper($payment->payment_method) !== 'ONLINE') {
            throw new UnprocessableEntityHttpException('Bu işlem yalnızca online ödemeler için geçerlidir.');
        }

        if ($payment->status !== ServicePayment::STATUS_PENDING) {
            throw new UnprocessableEntityHttpException("Ödeme bekleyen durumda değil (Mevcut durum: {$payment->status}).");
        }

        if ($payment->customer_user_id !== $customer->id) {
            throw new AccessDeniedHttpException('Bu ödeme kaydı size ait değil.');
        }

        // Verify resource is not cancelled
        if ($payment->resource_type === ServicePayment::RESOURCE_INSTANT_REQUEST) {
            $req = ServiceRequest::find($payment->resource_id);
            if (!$req || $req->status === ServiceRequest::STATUS_CANCELLED) {
                throw new UnprocessableEntityHttpException('İptal edilmiş bir talep için ödeme başlatılamaz.');
            }
        } elseif ($payment->resource_type === ServicePayment::RESOURCE_SCHEDULED_APPOINTMENT) {
            $appt = Appointment::find($payment->resource_id);
            if (!$appt || in_array($appt->status, [Appointment::STATUS_CANCELLED, Appointment::STATUS_REJECTED])) {
                throw new UnprocessableEntityHttpException('İptal edilmiş veya reddedilmiş randevu için ödeme başlatılamaz.');
            }
        }

        $merchantId = (string) $this->credential('merchant_id');
        $merchantKey = (string) $this->credential('merchant_key');
        $merchantSalt = (string) $this->credential('merchant_salt');

        $ip = $clientIp ?: request()->ip() ?: '127.0.0.1';
        $email = $customer->email ?: 'musteri@berberimgelsin.com';
        $paymentAmountMinor = FinancialService::parseToCents($payment->gross_amount);
        $merchantOid = $this->generateMerchantOid();
        $userBasket = $this->buildUserBasket($payment);

        $noInstallment = 1;
        $maxInstallment = 0;
        $currency = (string) config('paytr.currency', 'TL');
        $testMode = (int) $this->credential('test_mode', 1);

        // PayTR official token hash formula:
        // $hash_str = $merchant_id . $user_ip . $merchant_oid . $email . $payment_amount . $user_basket . $no_installment . $max_installment . $currency . $test_mode;
        // $paytr_token = base64_encode(hash_hmac('sha256', $hash_str . $merchant_salt, $merchant_key, true));
        $hashStr = $merchantId . $ip . $merchantOid . $email . $paymentAmountMinor . $userBasket . $noInstallment . $maxInstallment . $currency . $testMode;
        $paytrToken = base64_encode(hash_hmac('sha256', $hashStr . $merchantSalt, $merchantKey, true));

        // Create attempt audit record
        $attempt = PaymentGatewayAttempt::create([
            'service_payment_id' => $payment->id,
            'gateway' => 'PAYTR',
            'merchant_oid' => $merchantOid,
            'status' => PaymentGatewayAttempt::STATUS_CREATED,
            'payment_amount_minor' => $paymentAmountMinor,
            'currency' => $currency,
            'user_ip' => $ip,
            'user_basket' => json_decode(base64_decode($userBasket), true),
        ]);

        $postData = [
            'merchant_id' => $merchantId,
            'user_ip' => $ip,
            'merchant_oid' => $merchantOid,
            'email' => $email,
            'payment_amount' => $paymentAmountMinor,
            'paytr_token' => $paytrToken,
            'user_basket' => $userBasket,
            'user_name' => $customer->name ?: 'Müşteri',
            'user_address' => 'İstanbul',
            'user_phone' => $customer->phone ?: '05555555555',
            'merchant_ok_url' => $this->credential('ok_url'),
            'merchant_fail_url' => $this->credential('fail_url'),
            'timeout_limit' => config('paytr.timeout_limit', 30),
            'currency' => $currency,
            'test_mode' => $testMode,
            'no_installment' => $noInstallment,
            'max_installment' => $maxInstallment,
            'debug_on' => config('paytr.debug_on', 1),
            'client_lang' => 'tr',
            'payment_type' => 'card',
            'iframe_v2' => config('paytr.iframe_v2', 1),
        ];

        $response = Http::asForm()->timeout(20)->post('https://www.paytr.com/odeme/api/get-token', $postData);

        if ($response->successful()) {
            $data = $response->json();
            if (isset($data['status']) && $data['status'] === 'success' && !empty($data['token'])) {
                $attempt->status = PaymentGatewayAttempt::STATUS_TOKEN_READY;
                $attempt->save();

                ServiceLifecycleEvent::create([
                    'resource_type' => $payment->resource_type,
                    'resource_id' => $payment->resource_id,
                    'event_type' => ServiceLifecycleEvent::EVENT_PAYTR_TOKEN_CREATED,
                    'actor_user_id' => $customer->id,
                    'metadata' => [
                        'payment_id' => $payment->id,
                        'merchant_oid' => $merchantOid,
                        'amount_minor' => $paymentAmountMinor,
                    ],
                    'created_at' => now(),
                ]);

                return [
                    'success' => true,
                    'token' => $data['token'],
                    'merchant_oid' => $merchantOid,
                    'iframe_url' => "https://www.paytr.com/odeme/guvenli/{$data['token']}",
                    'payment_id' => $payment->id,
                ];
            }

            $attempt->status = PaymentGatewayAttempt::STATUS_FAILED;
            $attempt->failure_message = $data['reason'] ?? 'PayTR token oluşturulamadı';
            $attempt->save();

            throw new UnprocessableEntityHttpException('PayTR token oluşturulamadı: ' . ($data['reason'] ?? 'Bilinmeyen hata'));
        }

        $attempt->status = PaymentGatewayAttempt::STATUS_FAILED;
        $attempt->failure_message = 'PayTR servisine bağlanılamadı (HTTP ' . $response->status() . ')';
        $attempt->save();

        throw new UnprocessableEntityHttpException('PayTR servisine bağlanılamadı.');
    }

    /**
     * Validate PayTR HMAC-SHA256 callback signature.
     */
    public function validateCallbackHash(array $payload): bool
    {
        $merchantSalt = (string) $this->credential('merchant_salt');
        $merchantKey = (string) $this->credential('merchant_key');

        if (empty($merchantKey) || empty($merchantSalt)) {
            return false;
        }

        if (empty($payload['merchant_oid']) || empty($payload['status']) || !isset($payload['total_amount']) || empty($payload['hash'])) {
            return false;
        }

        // Official callback hash formula:
        // $hash_str = $post['merchant_oid'] . $merchant_salt . $post['status'] . $post['total_amount'];
        // $hash = base64_encode(hash_hmac('sha256', $hash_str, $merchant_key, true));
        $hashStr = $payload['merchant_oid'] . $merchantSalt . $payload['status'] . $payload['total_amount'];
        $expectedHash = base64_encode(hash_hmac('sha256', $hashStr, $merchantKey, true));

        return hash_equals($expectedHash, $payload['hash']);
    }

    /**
     * Process PayTR callback notification.
     * Guaranteed idempotent and atomic.
     * Returns "OK" on success or standard PayTR error string on failure.
     */
    public function handleCallback(array $payload): string
    {
        if (!$this->validateCallbackHash($payload)) {
            Log::warning('PayTR callback signature validation failed', [
                'merchant_oid' => $payload['merchant_oid'] ?? null,
            ]);

            return 'PAYTR notification failed: bad hash';
        }

        // "Öne çıkarma" card orders share the same PayTR callback URL; their merchant_oid has its own prefix.
        if (str_starts_with((string) $payload['merchant_oid'], \App\Models\FeaturedOrder::OID_PREFIX)) {
            return app(\App\Services\FeaturedOrderService::class)->handleCallback($payload);
        }
        if (str_starts_with((string) $payload['merchant_oid'], \App\Models\NotificationAd::OID_PREFIX)) {
            return app(\App\Services\NotificationAdService::class)->handleCallback($payload);
        }

        return DB::transaction(function () use ($payload) {
            $attempt = PaymentGatewayAttempt::where('merchant_oid', $payload['merchant_oid'])
                ->lockForUpdate()
                ->first();

            if (!$attempt) {
                Log::warning('PayTR callback received for unknown merchant_oid', [
                    'merchant_oid' => $payload['merchant_oid'],
                ]);
                return 'OK'; // Idempotent acknowledgement
            }

            // Already processed successfully -> idempotent ACK
            if ($attempt->status === PaymentGatewayAttempt::STATUS_SUCCESS) {
                return 'OK';
            }

            $payment = ServicePayment::where('id', $attempt->service_payment_id)
                ->lockForUpdate()
                ->first();

            if (!$payment) {
                return 'OK';
            }

            $isSuccess = (strtolower($payload['status']) === 'success');

            if ($isSuccess) {
                // Check payment amount (minor unit)
                $paidAmountMinor = (int) ($payload['payment_amount'] ?? $payload['total_amount']);

                if ($paidAmountMinor < $attempt->payment_amount_minor) {
                    $attempt->status = PaymentGatewayAttempt::STATUS_FAILED;
                    $attempt->failure_code = 'AMOUNT_MISMATCH';
                    $attempt->failure_message = "Beklenen tutar ({$attempt->payment_amount_minor}) ile ödenen ({$paidAmountMinor}) eşleşmiyor.";
                    $attempt->callback_received_at = now();
                    $attempt->callback_payload = $payload;
                    $attempt->save();

                    ServiceLifecycleEvent::create([
                        'resource_type' => $payment->resource_type,
                        'resource_id' => $payment->resource_id,
                        'event_type' => ServiceLifecycleEvent::EVENT_PAYTR_AMOUNT_MISMATCH,
                        'actor_user_id' => $payment->customer_user_id,
                        'metadata' => [
                            'payment_id' => $payment->id,
                            'merchant_oid' => $payload['merchant_oid'],
                            'expected_minor' => $attempt->payment_amount_minor,
                            'paid_minor' => $paidAmountMinor,
                        ],
                        'created_at' => now(),
                    ]);

                    return 'OK';
                }

                // Transition attempt & payment
                $attempt->status = PaymentGatewayAttempt::STATUS_SUCCESS;
                $attempt->callback_received_at = now();
                $attempt->callback_payload = $payload;
                $attempt->save();

                $payment->status = ServicePayment::STATUS_HELD;
                $payment->held_at = now();
                $payment->gateway = 'PAYTR';
                $payment->gateway_reference = $payload['merchant_oid'];
                $payment->save();

                ServiceLifecycleEvent::create([
                    'resource_type' => $payment->resource_type,
                    'resource_id' => $payment->resource_id,
                    'event_type' => ServiceLifecycleEvent::EVENT_PAYTR_PAYMENT_SUCCESS,
                    'actor_user_id' => $payment->customer_user_id,
                    'metadata' => [
                        'payment_id' => $payment->id,
                        'merchant_oid' => $payload['merchant_oid'],
                        'amount_minor' => $paidAmountMinor,
                    ],
                    'created_at' => now(),
                ]);

                app(\App\Services\NotificationService::class)->notifyUser(
                    $payment->customer_user_id,
                    \App\Models\UserNotification::TYPE_PAYMENT_RECEIVED,
                    'Ödemeniz Alındı',
                    'Online ödemeniz başarıyla alındı.',
                    \App\Models\UserNotification::RESOURCE_SERVICE_PAYMENT,
                    $payment->id,
                    '/customer',
                    [
                        'payment_id' => $payment->id,
                        'gross_amount' => (float) $payment->gross_amount,
                    ],
                    "PAYMENT_RECEIVED:{$payment->id}:{$payment->customer_user_id}"
                );

                return 'OK';
            }

            // Payment failed at PayTR
            $attempt->status = PaymentGatewayAttempt::STATUS_FAILED;
            $attempt->failure_code = $payload['failed_reason_code'] ?? 'PAYTR_FAILED';
            $attempt->failure_message = $payload['failed_reason_msg'] ?? 'Ödeme tamamlanamadı.';
            $attempt->callback_received_at = now();
            $attempt->callback_payload = $payload;
            $attempt->save();

            // Note: service_payment remains PENDING to allow the customer to retry payment
            ServiceLifecycleEvent::create([
                'resource_type' => $payment->resource_type,
                'resource_id' => $payment->resource_id,
                'event_type' => ServiceLifecycleEvent::EVENT_PAYTR_PAYMENT_FAILED,
                'actor_user_id' => $payment->customer_user_id,
                'metadata' => [
                    'payment_id' => $payment->id,
                    'merchant_oid' => $payload['merchant_oid'],
                    'failure_code' => $attempt->failure_code,
                    'failure_message' => $attempt->failure_message,
                ],
                'created_at' => now(),
            ]);

            return 'OK';
        });
    }

    /**
     * Query payment status directly from PayTR Durum Sorgu API.
     */
    public function queryPaymentStatus(string $merchantOid): array
    {
        if (!$this->isConfigured()) {
            throw new \LogicException('PayTR ödeme sistemi henüz yapılandırılmamış.');
        }

        $merchantId = (string) $this->credential('merchant_id');
        $merchantKey = (string) $this->credential('merchant_key');
        $merchantSalt = (string) $this->credential('merchant_salt');

        $hashStr = $merchantOid . $merchantId . $merchantSalt;
        $paytrToken = base64_encode(hash_hmac('sha256', $hashStr, $merchantKey, true));

        try {
            $response = Http::asForm()->timeout(15)->post('https://www.paytr.com/odeme/durum-sorgu', [
                'merchant_id' => $merchantId,
                'merchant_oid' => $merchantOid,
                'paytr_token' => $paytrToken,
            ]);
        } catch (\Throwable $e) {
            Log::error('PayTR durum sorgu network error', [
                'merchant_oid' => $merchantOid,
                'error' => $e->getMessage(),
            ]);

            return [
                'status' => 'error',
                'message' => 'PayTR durum sorgulama ağ hatası: ' . $e->getMessage(),
            ];
        }

        if ($response->successful()) {
            return $response->json() ?: [];
        }

        return [
            'status' => 'error',
            'message' => 'PayTR durum sorgulama başarısız: ' . $response->status(),
        ];
    }

    /**
     * Generate unique, alphanumeric trans_id (<= 60 chars).
     */
    public function generateTransId(): string
    {
        do {
            $transId = 'TRF' . date('ymdHis') . strtoupper(Str::random(12));
        } while (\App\Models\PayoutTransfer::where('trans_id', $transId)->exists());

        return $transId;
    }

    /**
     * Generate PayTR Platform Transfer token using official hash formula:
     * merchant_id + merchant_oid + trans_id + submerchant_amount + total_amount + transfer_name + transfer_iban + merchant_salt
     * HMAC-SHA256 with merchant_key, base64 encoded.
     */
    public function generateTransferToken(
        string $merchantOid,
        string $transId,
        int $submerchantAmount,
        int $totalAmount,
        string $transferName,
        string $transferIban
    ): string {
        $merchantId = (string) $this->credential('merchant_id');
        $merchantKey = (string) $this->credential('merchant_key');
        $merchantSalt = (string) $this->credential('merchant_salt');

        $hashStr = $merchantId . $merchantOid . $transId . $submerchantAmount . $totalAmount . $transferName . $transferIban . $merchantSalt;

        return base64_encode(hash_hmac('sha256', $hashStr, $merchantKey, true));
    }

    /**
     * Request PayTR Marketplace Platform Transfer.
     * POST https://www.paytr.com/odeme/platform/transfer
     */
    public function requestPlatformTransfer(array $params): array
    {
        if (!$this->isConfigured()) {
            throw new \LogicException('PayTR transfer sistemi yapılandırılmamış.');
        }

        $merchantId = (string) $this->credential('merchant_id');
        $merchantOid = (string) $params['merchant_oid'];
        $transId = (string) $params['trans_id'];
        $submerchantAmount = (int) $params['submerchant_amount'];
        $totalAmount = (int) $params['total_amount'];
        $transferName = (string) $params['transfer_name'];
        $transferIban = (string) $params['transfer_iban'];

        $paytrToken = $this->generateTransferToken(
            $merchantOid,
            $transId,
            $submerchantAmount,
            $totalAmount,
            $transferName,
            $transferIban
        );

        $postData = [
            'merchant_id' => $merchantId,
            'merchant_oid' => $merchantOid,
            'trans_id' => $transId,
            'submerchant_amount' => $submerchantAmount,
            'total_amount' => $totalAmount,
            'transfer_name' => $transferName,
            'transfer_iban' => $transferIban,
            'paytr_token' => $paytrToken,
        ];

        try {
            $response = Http::asForm()->timeout(20)->post('https://www.paytr.com/odeme/platform/transfer', $postData);
        } catch (\Throwable $e) {
            Log::error('PayTR platform transfer network error', [
                'trans_id' => $transId,
                'error' => $e->getMessage(),
            ]);

            return [
                'success' => false,
                'status' => 'error',
                'err_no' => 'NETWORK_ERROR',
                'err_msg' => 'PayTR servisine bağlanırken ağ hatası oluştu: ' . $e->getMessage(),
            ];
        }

        if ($response->successful()) {
            $data = $response->json();
            if (isset($data['status']) && $data['status'] === 'success') {
                return [
                    'success' => true,
                    'status' => 'success',
                    'trans_id' => $transId,
                    'paytr_reference' => $data['trans_id'] ?? $transId,
                    'raw' => $data,
                ];
            }

            return [
                'success' => false,
                'status' => 'error',
                'err_no' => $data['err_no'] ?? 'TRANSFER_ERROR',
                'err_msg' => $data['err_msg'] ?? ($data['reason'] ?? 'PayTR transfer talimatı kabul edilmedi'),
                'raw' => $data,
            ];
        }

        return [
            'success' => false,
            'status' => 'error',
            'err_no' => 'HTTP_' . $response->status(),
            'err_msg' => 'PayTR servisi HTTP hatası döndürdü: ' . $response->status(),
            'raw' => $response->json() ?: $response->body(),
        ];
    }

    /**
     * Validate PayTR Platform Transfer Result Callback HMAC-SHA256 signature.
     * Formula: clean(trans_ids) + merchant_salt
     * HMAC-SHA256 with merchant_key, base64 encoded.
     */
    public function validateTransferCallbackHash(array $payload): bool
    {
        $merchantSalt = (string) $this->credential('merchant_salt');
        $merchantKey = (string) $this->credential('merchant_key');

        if (empty($merchantKey) || empty($merchantSalt)) {
            return false;
        }

        if (empty($payload['trans_ids']) || empty($payload['hash'])) {
            return false;
        }

        $cleanTransIds = str_replace('\\', '', (string) $payload['trans_ids']);
        $hashStr = $cleanTransIds . $merchantSalt;
        $expectedHash = base64_encode(hash_hmac('sha256', $hashStr, $merchantKey, true));

        return hash_equals($expectedHash, (string) $payload['hash']);
    }

    /**
     * Generate PayTR Refund API paytr_token:
     * Formula: merchant_id + merchant_oid + return_amount + merchant_salt
     * HMAC-SHA256 with merchant_key, base64 encoded.
     */
    public function generateRefundToken(string $merchantOid, string $returnAmountFormatted): string
    {
        $merchantId = (string) $this->credential('merchant_id');
        $merchantKey = (string) $this->credential('merchant_key');
        $merchantSalt = (string) $this->credential('merchant_salt');

        $hashStr = $merchantId . $merchantOid . $returnAmountFormatted . $merchantSalt;

        return base64_encode(hash_hmac('sha256', $hashStr, $merchantKey, true));
    }

    /**
     * Request PayTR Online Refund.
     * POST https://www.paytr.com/odeme/iade
     */
    public function requestRefund(array $params): array
    {
        if (!$this->isConfigured()) {
            throw new \LogicException('PayTR ödeme sistemi yapılandırılmamış.');
        }

        $merchantId = (string) $this->credential('merchant_id');
        $merchantOid = (string) $params['merchant_oid'];
        $returnAmount = (string) $params['return_amount']; // formatted e.g. "150.00"
        $referenceNo = !empty($params['reference_no']) ? (string) $params['reference_no'] : null;

        $paytrToken = $this->generateRefundToken($merchantOid, $returnAmount);

        $postData = [
            'merchant_id' => $merchantId,
            'merchant_oid' => $merchantOid,
            'return_amount' => $returnAmount,
            'paytr_token' => $paytrToken,
        ];

        if (!empty($referenceNo)) {
            $postData['reference_no'] = $referenceNo;
        }

        try {
            $response = Http::asForm()->timeout(20)->post('https://www.paytr.com/odeme/iade', $postData);
        } catch (\Throwable $e) {
            Log::error('PayTR refund network error', [
                'merchant_oid' => $merchantOid,
                'reference_no' => $referenceNo,
                'error' => $e->getMessage(),
            ]);

            return [
                'success' => false,
                'status' => 'network_error',
                'is_transient' => true,
                'err_no' => 'NETWORK_ERROR',
                'err_msg' => 'PayTR iade servisine bağlanırken ağ/bağlantı hatası oluştu: ' . $e->getMessage(),
            ];
        }

        if ($response->successful()) {
            $data = $response->json();
            if (isset($data['status']) && $data['status'] === 'success') {
                return [
                    'success' => true,
                    'status' => 'success',
                    'merchant_oid' => $merchantOid,
                    'return_amount' => $data['return_amount'] ?? $returnAmount,
                    'reference_no' => $referenceNo,
                    'raw' => $data,
                ];
            }

            return [
                'success' => false,
                'status' => 'error',
                'is_transient' => false,
                'err_no' => $data['err_no'] ?? 'REFUND_ERROR',
                'err_msg' => $data['err_msg'] ?? ($data['reason'] ?? 'PayTR iade işlemi reddedildi'),
                'raw' => $data,
            ];
        }

        $is5xx = $response->status() >= 500;
        return [
            'success' => false,
            'status' => 'error',
            'is_transient' => $is5xx,
            'err_no' => 'HTTP_' . $response->status(),
            'err_msg' => 'PayTR servisi HTTP ' . $response->status() . ' hatası döndürdü.',
            'raw' => $response->json() ?: $response->body(),
        ];
    }
}
