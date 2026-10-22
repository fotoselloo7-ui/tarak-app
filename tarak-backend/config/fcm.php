<?php

return [
    /*
    |--------------------------------------------------------------------------
    | Firebase Cloud Messaging (FCM HTTP v1) Configuration
    |--------------------------------------------------------------------------
    |
    | Configuration for server-side push notification delivery using the
    | Google FCM HTTP v1 REST API with short-lived OAuth 2.0 tokens.
    |
    */

    'enabled' => filter_var(env('FCM_ENABLED', false), FILTER_VALIDATE_BOOLEAN),

    'project_id' => env('FCM_PROJECT_ID'),

    'credentials_path' => env('GOOGLE_APPLICATION_CREDENTIALS'),

    'access_token_cache_key' => 'fcm_http_v1_access_token',

    // Refresh token 5 minutes before expiration to avoid 401s during delivery
    'access_token_ttl_buffer' => 300,
];
