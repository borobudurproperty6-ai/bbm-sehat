<?php

namespace App\Support;

/**
 * Replaces the old random-character temporary password (Str::password(12))
 * with a "Word+4digits" format (e.g. "Sehat4271") that's actually easy to
 * read aloud and retype from a printed slip or a WhatsApp message — the
 * old format mixed visually similar characters (l/1/I, 0/O) that are hard
 * to relay correctly over the phone.
 *
 * Only used where an admin hands a password to someone else to type in
 * once (new account, reset) — every such account also has
 * must_change_password=true, forcing it to be replaced on first login
 * (see Employee::$fillable / the mobile app's mandatory
 * ChangePasswordScreen), which is what makes the much smaller keyspace
 * here (~116 words x 8^4 digits) an acceptable trade for readability: the
 * exposure window is a single login.
 */
class TemporaryPasswordGenerator
{
    // Digits 0 and 1 excluded — visually ambiguous with letters O and l/I
    // when handwritten or read off a slip.
    private const DIGITS = ['2', '3', '4', '5', '6', '7', '8', '9'];

    public static function generate(): string
    {
        $word = PasswordWords::LIST[random_int(0, count(PasswordWords::LIST) - 1)];

        $digits = '';
        for ($i = 0; $i < 4; $i++) {
            $digits .= self::DIGITS[random_int(0, count(self::DIGITS) - 1)];
        }

        return $word.$digits;
    }
}
