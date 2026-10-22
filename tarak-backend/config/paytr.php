<?php

return [
    /*
    |--------------------------------------------------------------------------
    | PayTR Gateway Credentials & Settings
    |--------------------------------------------------------------------------
    */

    'merchant_id' => env('PAYTR_MERCHANT_ID', ''),
    'merchant_key' => env('PAYTR_MERCHANT_KEY', ''),
    'merchant_salt' => env('PAYTR_MERCHANT_SALT', ''),

    'test_mode' => (int) env('PAYTR_TEST_MODE', 1),
    'debug_on' => (int) env('PAYTR_DEBUG_ON', 1),
    'iframe_v2' => (int) env('PAYTR_IFRAME_V2', 1),

    'ok_url' => env('PAYTR_OK_URL', 'http://localhost:8030/payment-result/success'),
    'fail_url' => env('PAYTR_FAIL_URL', 'http://localhost:8030/payment-result/fail'),

    'timeout_limit' => (int) env('PAYTR_TIMEOUT_LIMIT', 30),
    'currency' => env('PAYTR_CURRENCY', 'TL'),
];
