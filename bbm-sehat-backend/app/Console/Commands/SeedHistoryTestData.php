<?php

namespace App\Console\Commands;

use App\Models\DailyActivityLog;
use App\Models\Employee;
use App\Services\StepTargetResolver;
use Illuminate\Console\Command;

/**
 * DEVELOPMENT-ONLY testing aid — not part of the shipped application.
 *
 * Backfills the last N days (including today) with a random mix of
 * above/below-target steps, so the Riwayat history chart has enough real
 * variety to look meaningful without waiting for real usage. Never
 * overwrites a date that already has a log — real synced data always wins.
 */
class SeedHistoryTestData extends Command
{
    protected $signature = 'test:seed-history {employee_id} {days=14}';

    protected $description = '[DEV ONLY] Backfill recent daily_activity_logs with varied steps to test the Riwayat history chart';

    public function handle(StepTargetResolver $targets): int
    {
        $employee = Employee::find($this->argument('employee_id'));
        if ($employee === null) {
            $this->error("Employee {$this->argument('employee_id')} not found.");

            return self::FAILURE;
        }

        $days = (int) $this->argument('days');
        $seeded = 0;
        $skipped = 0;

        for ($i = 0; $i < $days; $i++) {
            $date = now()->subDays($i)->toDateString();

            if (DailyActivityLog::where('employee_id', $employee->id)->where('activity_date', $date)->exists()) {
                $skipped++;
                continue;
            }

            $targetSteps = $targets->resolve($employee, $date);
            // ~60% of days land above target, ~40% below — a flat "always
            // above" seed wouldn't exercise the chart's two bar colors.
            $steps = random_int(0, 99) < 60
                ? $targetSteps + random_int(200, 3000)
                : max(0, $targetSteps - random_int(500, 4000));

            DailyActivityLog::create([
                'employee_id' => $employee->id,
                'activity_date' => $date,
                'steps' => $steps,
                'distance_meters' => round($steps * 0.7, 2),
                'source' => 'manual_test',
                'synced_at' => now(),
            ]);
            $seeded++;
            $this->line("Seeded {$date}: {$steps} steps (target {$targetSteps}).");
        }

        $this->info("Done — seeded {$seeded} day(s), skipped {$skipped} day(s) that already had data, for {$employee->full_name}.");

        return self::SUCCESS;
    }
}
