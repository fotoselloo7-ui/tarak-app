<?php

namespace App\Services;

use Illuminate\Validation\ValidationException;

class MessageContentPolicyService
{
    public const BLOCKED_MESSAGE = 'Güvenliğiniz için telefon, sosyal medya, e-posta, bağlantı veya ödeme bilgilerini mesajlarda paylaşamazsınız.';

    /**
     * Validate message content against platform anti-bypass and safety rules.
     * Throws ValidationException with user-friendly 422 message if blocked.
     *
     * @param string $body
     * @throws ValidationException
     */
    public function validateContent(string $body): void
    {
        $violation = $this->detectViolation($body);

        if ($violation !== null) {
            throw ValidationException::withMessages([
                'body' => [self::BLOCKED_MESSAGE],
            ]);
        }
    }

    /**
     * Check if the message contains any contact or policy violation.
     * Returns true if safe, false if blocked.
     */
    public function isClean(string $body): bool
    {
        return $this->detectViolation($body) === null;
    }

    /**
     * Detect violation type (returns internal category or null if clean).
     * Does not expose internal category to the end user.
     */
    public function detectViolation(string $body): ?string
    {
        $text = trim($body);
        if ($text === '') {
            return null;
        }

        // 1. Email check
        if (preg_match('/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/i', $text)) {
            return 'EMAIL';
        }

        // 2. URL & Domain check (https://, http://, www., or standard TLDs)
        if (preg_match('/(?:https?:\/\/|www\.)[^\s]+/i', $text)) {
            return 'URL';
        }
        if (preg_match('/\b[a-zA-Z0-9-]{2,}\.(?:com|net|org|com\.tr|edu|gov\.tr|me|io|co|xyz|site|online|app)\b/i', $text)) {
            return 'DOMAIN';
        }

        // 3. IBAN check (Turkish IBANs start with TR followed by 24 digits, with optional spaces)
        if (preg_match('/\bTR\s*(?:[0-9]\s*){16,26}\b/i', $text)) {
            return 'IBAN';
        }
        if (preg_match('/\biban\s*[:=\-]?\s*[0-9A-Z\s]{10,}/iu', $text)) {
            return 'IBAN';
        }

        // 4. Social Media & Messaging bypass keywords
        // WhatsApp
        if (preg_match('/(?:whatsapp|watsap|watsapp|wa\.me|\bwp(?:[\'’]?[td]en|\s*yaz|\s*gel|\s*ge[cç]|\b))/iu', $text)) {
            return 'WHATSAPP';
        }
        // Telegram
        if (preg_match('/(?:telegram|t\.me|\btg(?:[\'’]?[td]en|\s*yaz|\s*gel|\s*ge[cç]|\b))/iu', $text)) {
            return 'TELEGRAM';
        }
        // Instagram
        if (preg_match('/(?:instagram|instadan|instaya|insta[\'’]dan|\binsta\b|\big\s*:\s*[a-zA-Z0-9_.]+)/iu', $text)) {
            return 'INSTAGRAM';
        }

        // 5. Explicit bypass phrases
        if (preg_match('/(?:beni\s+ara\b|ara\s+beni\b|numaram[ıi]?\s*[:=\-]?\s*\d|telefonum[ıi]?\s*[:=\-]?\s*\d|özelden\s+(?:yaz|görüş|ulaş|ara)|dışarıdan\s+halled)/iu', $text)) {
            return 'BYPASS_PHRASE';
        }

        // 6. Phone number normalization & detection
        if ($this->containsPhoneNumber($text)) {
            return 'PHONE';
        }

        return null;
    }

    /**
     * Robust phone number detection avoiding false positives on times (15:30), prices (500 TL), or 4-digit codes (1234).
     */
    protected function containsPhoneNumber(string $text): bool
    {
        // Check standard Turkish mobile format patterns: 05xx xxx xx xx, +90 5xx, 905xx, 5xx-xxx-xx-xx
        $phonePatterns = [
            '/(?:\+?90\s*|0)?\s*5[0-9]{2}[\s\-\.]*[0-9]{3}[\s\-\.]*[0-9]{2}[\s\-\.]*[0-9]{2}/',
            '/(?:\+?90\s*|0)?\s*5[0-9]{2}[\s\-\.]*[0-9]{3}[\s\-\.]*[0-9]{4}/',
            '/(?:\+?90\s*)?[0-9]{3}[\s\-\.]*[0-9]{3}[\s\-\.]*[0-9]{4}/',
        ];

        foreach ($phonePatterns as $pattern) {
            if (preg_match($pattern, $text)) {
                return true;
            }
        }

        // Normalize string by removing non-digits to test continuous digit blocks
        // Guard: preserve time (e.g. 15:30), date (18.09.2026), price (500 TL)
        // Extract isolated sequences of digits and check if any forms a 10-11 digit phone number
        preg_match_all('/\b\d+(?:[\s\-\.]\d+)+\b/', $text, $matches);
        if (!empty($matches[0])) {
            foreach ($matches[0] as $candidate) {
                // If it looks like a time: 2 digits : 2 digits, ignore
                if (preg_match('/^\d{1,2}:\d{2}$/', trim($candidate))) {
                    continue;
                }
                // Strip separators
                $digits = preg_replace('/[^\d]/', '', $candidate);
                // 10 digits starting with 5 (e.g. 5321112233) or 11 digits starting with 05 (05321112233)
                if (strlen($digits) === 10 && str_starts_with($digits, '5')) {
                    return true;
                }
                if (strlen($digits) === 11 && str_starts_with($digits, '05')) {
                    return true;
                }
                if (strlen($digits) === 12 && str_starts_with($digits, '905')) {
                    return true;
                }
            }
        }

        // Also check if text has a continuous digit string of 10 or 11 digits starting with 05 or 5
        if (preg_match('/\b05[0-9]{9}\b/', $text) || preg_match('/\b5[0-9]{9}\b/', $text) || preg_match('/\b905[0-9]{9}\b/', $text)) {
            return true;
        }

        return false;
    }
}
