<?php

namespace App\Services;

class IbanValidator
{
    /**
     * Normalize IBAN: strip all whitespace and convert to uppercase.
     */
    public static function normalize(string $iban): string
    {
        return strtoupper(preg_replace('/\s+/', '', $iban));
    }

    /**
     * Validate Turkish IBAN format and ISO 7064 MOD 97-10 checksum.
     */
    public static function validate(string $iban): bool
    {
        $normalized = self::normalize($iban);

        // Turkish IBAN must be exactly 26 characters: "TR" + 24 numeric digits
        if (!preg_match('/^TR[0-9]{24}$/', $normalized)) {
            return false;
        }

        // Move first 4 characters to end: TRxx -> end
        $rearranged = substr($normalized, 4) . substr($normalized, 0, 4);

        // Replace letters with A=10 .. Z=35 (T=29, R=27)
        $numericString = '';
        for ($i = 0; $i < strlen($rearranged); $i++) {
            $char = $rearranged[$i];
            if (ctype_alpha($char)) {
                $numericString .= (ord($char) - 55);
            } else {
                $numericString .= $char;
            }
        }

        // Modulo 97 using Horner's rule (prevents integer overflow)
        $remainder = 0;
        for ($i = 0; $i < strlen($numericString); $i++) {
            $remainder = ($remainder * 10 + (int) $numericString[$i]) % 97;
        }

        return $remainder === 1;
    }

    /**
     * Mask IBAN: "TR••••••••••••••••••••1234"
     */
    public static function mask(?string $iban): string
    {
        if (empty($iban)) {
            return '';
        }

        $normalized = self::normalize($iban);
        if (strlen($normalized) < 4) {
            return $normalized;
        }

        $last4 = substr($normalized, -4);
        return 'TR' . str_repeat('•', 20) . $last4;
    }

    /**
     * Generate a syntactically and checksum-valid Turkish IBAN for testing or fixtures.
     * $account22: 22-digit string (5-digit bank code + 1-digit national code + 16-digit account number).
     */
    public static function generateValidTrIban(string $account22 = '0006100519786457841235'): string
    {
        $account22 = str_pad(preg_replace('/[^0-9]/', '', $account22), 22, '0', STR_PAD_LEFT);
        $account22 = substr($account22, 0, 22);

        // Compute check digits: account22 + TR00 (TR=2927, 00)
        $numStr = $account22 . '292700';
        $rem = 0;
        for ($i = 0; $i < strlen($numStr); $i++) {
            $rem = ($rem * 10 + (int) $numStr[$i]) % 97;
        }

        $check = 98 - $rem;
        $checkStr = sprintf('%02d', $check);

        return 'TR' . $checkStr . $account22;
    }
}
