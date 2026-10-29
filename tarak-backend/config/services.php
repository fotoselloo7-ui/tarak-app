<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Mailgun, Postmark, AWS and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'postmark' => [
        'token' => env('POSTMARK_TOKEN'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    'resend' => [
        'key' => env('RESEND_KEY'),
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],

    'location_share' => [
        'ttl_minutes' => (int) env('LOCATION_SHARE_TTL_MINUTES', 120),
    ],

    'registration' => [
        // Temporary compatibility for store builds released before consent/OTP
        // fields were added. Disable after build 5+ adoption.
        'legacy_mobile_compat' => filter_var(env('ALLOW_LEGACY_MOBILE_REGISTRATION', true), FILTER_VALIDATE_BOOL),
        // Registration SMS verification is independent from the general SMS
        // integration. Keeping SMS notifications enabled must not make signup
        // OTP mandatory unless this flag is explicitly enabled.
        'sms_verification_enabled' => filter_var(env('REGISTRATION_SMS_VERIFICATION_ENABLED', false), FILTER_VALIDATE_BOOL),
    ],

    'google' => [
        'web_client_id' => env('GOOGLE_WEB_CLIENT_ID', ''),
        'ios_client_id' => env('GOOGLE_IOS_CLIENT_ID', ''),
        'client_ids' => array_values(array_filter([
            env('GOOGLE_WEB_CLIENT_ID', ''),
            env('GOOGLE_ANDROID_CLIENT_ID', ''),
            env('GOOGLE_IOS_CLIENT_ID', ''),
        ])),
    ],

    'apple' => [
        'service_id' => env('APPLE_SERVICE_ID', ''),
        'client_ids' => array_values(array_filter([
            env('APPLE_SERVICE_ID', ''),
            env('APPLE_BUNDLE_ID', ''),
        ])),
        'client_secret' => env('APPLE_CLIENT_SECRET', ''),
        'redirect_uri' => env('APPLE_REDIRECT_URI', ''),
    ],

    'service_start' => [
        'ttl_minutes' => (int) env('SERVICE_START_CODE_TTL_MINUTES', 1440),
        'max_attempts' => (int) env('SERVICE_START_MAX_ATTEMPTS', 5),
        'lock_minutes' => (int) env('SERVICE_START_LOCK_MINUTES', 5),
    ],

];
