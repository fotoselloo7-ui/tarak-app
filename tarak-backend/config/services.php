<?php

return [
    'google_maps' => ['browser_api_key' => env('GOOGLE_MAPS_BROWSER_API_KEY', '')],
    'google_oauth' => ['web_client_id' => env('GOOGLE_OAUTH_WEB_CLIENT_ID', '')],
    'apple_oauth' => [
        'bundle_id' => env('APPLE_OAUTH_BUNDLE_ID', 'app.tarak.mobile'),
        // Apple Developer Services ID (web audience). NOT an Apple private key.
        'web_client_id' => env('APPLE_OAUTH_WEB_CLIENT_ID', ''),
        'web_redirect_uri' => env('APPLE_OAUTH_WEB_REDIRECT_URI', ''),
    ],
    'registration' => ['require_verification' => env('REGISTRATION_VERIFICATION_REQUIRED', false)],

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

    'service_start' => [
        'ttl_minutes' => (int) env('SERVICE_START_CODE_TTL_MINUTES', 1440),
        'max_attempts' => (int) env('SERVICE_START_MAX_ATTEMPTS', 5),
        'lock_minutes' => (int) env('SERVICE_START_LOCK_MINUTES', 5),
    ],

];
