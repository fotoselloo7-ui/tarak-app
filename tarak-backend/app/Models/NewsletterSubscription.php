<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class NewsletterSubscription extends Model
{
    public const STATUS_SUBSCRIBED = 'SUBSCRIBED';
    public const STATUS_UNSUBSCRIBED = 'UNSUBSCRIBED';

    protected $fillable = [
        'email',
        'status',
        'unsubscribe_token',
        'unsubscribed_at',
    ];

    protected function casts(): array
    {
        return ['unsubscribed_at' => 'datetime'];
    }
}
