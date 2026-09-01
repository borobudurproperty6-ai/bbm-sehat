<?php

namespace App\Console\Commands;

use App\Models\DailyActivityLog;
use App\Models\Employee;
use App\Services\PointService;
use App\Services\StepTargetResolver;
use Illuminate\Console\Command;
use Illuminate\Support\Carbon;

/**
 * DEVELOPMENT-ONLY testing aid — not part of the shipped application.
 *
 * Backfills the 4 most recent workdays strictly before today with
 * above-target daily_activity_logs (and their DAILY_TARGET_MET points), so
 * the rolling 5-day WEEKLY_STREAK_5 bonus can be exercised without waiting
 * for 5 real workdays to pass. Run a real sync for *today* above target
 * afterward to complete the streak and trigger the bonus.
 */
class SeedStreakTestData extends Command
{
    protected $signature = 'test:seed-streak {employee_id}';

    protected $description = '[DEV ONLY] Backfill above-target activity for recent workdays to test the streak bonus';

    private const DAYS_TO_BACKFILL = 4;

    public function handle(StepTargetResolver $targets, PointService $points): int
    {
        $employee = Employee::find($this->argument('employee_id'));
        if ($employee === null) {
            $this->error("Employee {$this->argument('employee_id')} not found.");

            return self::FAILURE;
        }

        $cursor = Carbon::yesterday();
        $seeded = 0;

        while ($seeded < self::DAYS_TO_BACKFILL) {
            if ($cursor->isWeekend()) {
                $cursor = $cursor->copy()->subDay();
                continue;
            }

            $date = $cursor->toDateString();
            $targetSteps = $targets->resolve($employee, $date);
            $steps = $targetSteps + 500;

            DailyActivityLog::updateOrCreate(
                ['employee_id' => $employee->id, 'activity_date' => $date],
                ['steps' => $steps, 'distance_meters' => null, 'source' => 'manual_test', 'synced_at' => now()]
            );
            $points->awardForDailySync($employee, $date, $steps, $targetSteps);

            $this->line("Seeded {$date}: {$steps} steps (target {$targetSteps}).");
            $seeded++;
            $cursor = $cursor->copy()->subDay();
        }

        $streakSoFar = $points->currentStreakDays($employee, Carbon::yesterday()->toDateString());
        $this->info(
            "Done — {$employee->full_name} now has a {$streakSoFar}-day streak through yesterday. ".
            'Sync today\'s steps above target (e.g. via the app\'s "Sync Sekarang" button, or '.
            'POST /api/activity/sync) to complete day 5 and trigger the +20 WEEKLY_STREAK_5 bonus.'
        );

        return self::SUCCESS;
    }
}
