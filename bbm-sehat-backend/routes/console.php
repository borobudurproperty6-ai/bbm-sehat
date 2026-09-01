<?php

use App\Console\Commands\SendWalkReminders;
use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

// ── Walk reminders — two nudges a day for anyone still below their step
//    target: a mid-afternoon one (there's still time left in the day to
//    act on it) and an evening one (last call before the day resets).
//    Explicit ::timezone() rather than relying on config('app.timezone')
//    (which is UTC here) — WITA (Asia/Makassar, UTC+8) per the original
//    request. Both entries guard against the exact failure this was built
//    to prevent: a double-fire of the *same* slot (overlapping run, a
//    retry, a second scheduler process) re-sending to someone already
//    reminded under that slot today — see WalkReminderService's
//    $dedupSlot. ─────────────────────────────────────────────────────────
Schedule::command(SendWalkReminders::class, ['afternoon'])
    ->dailyAt('15:00')
    ->timezone('Asia/Makassar')
    ->withoutOverlapping()
    ->onOneServer();

Schedule::command(SendWalkReminders::class, ['evening'])
    ->dailyAt('19:00')
    ->timezone('Asia/Makassar')
    ->withoutOverlapping()
    ->onOneServer();
