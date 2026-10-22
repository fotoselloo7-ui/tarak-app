<?php

return [
    /*
    |--------------------------------------------------------------------------
    | Chat Configuration
    |--------------------------------------------------------------------------
    |
    | Configuration for Tarak customer-provider resource-scoped chat.
    |
    */

    // Hours after resource completion during which chat remains open for messages
    'after_completion_hours' => (int) env('CHAT_AFTER_COMPLETION_HOURS', 72),

    // Max message length in characters
    'max_message_length' => (int) env('CHAT_MAX_MESSAGE_LENGTH', 2000),

    // Rate limit for sending messages (requests per minute per user)
    'rate_limit_per_minute' => (int) env('CHAT_RATE_LIMIT_PER_MINUTE', 60),
];
