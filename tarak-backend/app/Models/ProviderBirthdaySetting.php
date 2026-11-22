<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ProviderBirthdaySetting extends Model
{
    use HasFactory;

    public const TEMPLATES = [
        'classic' => [
            'label' => 'Klasik Tebrik',
            'body' => '{isletme} ailesi olarak yeni yaşında sana sağlık ve mutluluklar dileriz! 🎉',
        ],
        'warm' => [
            'label' => 'Samimi Kutlama',
            'body' => 'Mutlu yıllar {ad}! {isletme} olarak güzel günler ve keyifli anlar dileriz.',
        ],
        'vip' => [
            'label' => 'Özel Bakım Günü',
            'body' => 'İyi ki doğdun {ad}! {isletme} ekibi olarak yeni yaşını en içten dileklerimizle kutlarız.',
        ],
    ];

    protected $fillable = [
        'provider_profile_id',
        'is_enabled',
        'send_on_birthday',
        'send_one_day_before',
        'send_two_days_before',
        'send_time',
        'template_key',
        'custom_message',
        'required_plan_tier',
    ];

    protected function casts(): array
    {
        return [
            'is_enabled' => 'boolean',
            'send_on_birthday' => 'boolean',
            'send_one_day_before' => 'boolean',
            'send_two_days_before' => 'boolean',
        ];
    }

    public function providerProfile(): BelongsTo
    {
        return $this->belongsTo(ProviderProfile::class);
    }

    /**
     * Future-ready plan entitlement hook (PRO / BUSINESS), open without payment gate for now.
     */
    public function isEntitled(): bool
    {
        return true;
    }

    public function renderMessage(string $firstName, string $businessName): string
    {
        $templateKey = $this->template_key ?: 'classic';
        $raw = $templateKey === 'custom' && trim((string) $this->custom_message) !== ''
            ? trim((string) $this->custom_message)
            : (self::TEMPLATES[$templateKey]['body'] ?? self::TEMPLATES['classic']['body']);

        return strtr($raw, [
            '{ad}' => trim($firstName) !== '' ? trim($firstName) : 'Değerli Müşterimiz',
            '{isletme}' => trim($businessName) !== '' ? trim($businessName) : 'İşletmemiz',
        ]);
    }
}
