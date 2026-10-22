<?php

namespace App\Support;

/**
 * Customer-written notes are user content, but the platform's own QA and
 * internal bookkeeping sometimes lands in the same column. Those markers must
 * never reach a customer or provider screen.
 *
 * This is a display rule only: the stored value is left untouched, so audit
 * and history records stay intact.
 */
final class CustomerNote
{
    /** Internal markers: FAZ/QA bookkeeping, closure runs, and admin/debug tags. */
    private const INTERNAL_PATTERN =
        '/^\s*(FAZ\s*\d*[\s_]|QA[_\s]|.*closure_|.*internal_note|.*admin_note|debug\b|test note\b|MOCK\b|DEMO\b|PLACEHOLDER\b|Yerel demo test\b)/iu';

    public static function forMessage(?string $body): string
    {
        return self::forDisplay($body) ?? 'Bu mesajın içeriği gizlendi.';
    }

    public static function forNotification(?string $message): ?string
    {
        if (self::forDisplay($message) === null) {
            return 'Yeni bir bildiriminiz var.';
        }
        // Message notifications prefix the preview with the sender's name.
        $parts = explode(': ', $message, 2);
        if (count($parts) === 2 && self::forDisplay($parts[1]) === null) {
            return $parts[0] . ': Yeni bir mesajınız var.';
        }
        return $message;
    }

    public static function forDisplay(?string $note): ?string
    {
        if ($note === null) {
            return null;
        }

        $trimmed = trim($note);
        if ($trimmed === '') {
            return null;
        }

        return preg_match(self::INTERNAL_PATTERN, $trimmed) === 1 ? null : $trimmed;
    }
}
