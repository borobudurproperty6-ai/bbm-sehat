<?php

namespace App\Services;

use App\Models\DailyActivityLog;
use App\Models\Employee;
use Illuminate\Support\Carbon;

/**
 * Builds GET /api/activity/history's entries — always the full current
 * week (Mon-Sun) or current month (grouped into 7-day chunks), zero-filled
 * for any day/week without a synced log, never trimmed to just the days
 * that happen to have data — a chart with silently missing bars would be
 * misleading, not cleaner.
 */
class ActivityHistoryService
{
    private const WEEKDAY_LABELS = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

    /** @return array{entries: array<int, array<string, mixed>>, average_daily_steps: int} */
    public function weekly(Employee $employee, StepTargetResolver $targets): array
    {
        $monday = now()->startOfWeek(Carbon::MONDAY);
        $dates = [];
        for ($i = 0; $i < 7; $i++) {
            $dates[] = $monday->copy()->addDays($i)->toDateString();
        }

        $stepsByDate = $this->stepsByDate($employee, $dates[0], $dates[6]);

        $entries = [];
        foreach ($dates as $i => $date) {
            $steps = $stepsByDate[$date] ?? 0;
            $entries[] = [
                'label' => self::WEEKDAY_LABELS[$i],
                'date' => $date,
                'steps' => $steps,
                'target_met' => $steps >= $targets->resolve($employee, $date),
            ];
        }

        return [
            'entries' => $entries,
            'average_daily_steps' => $this->average($entries),
        ];
    }

    /** @return array{entries: array<int, array<string, mixed>>, average_daily_steps: int} */
    public function monthly(Employee $employee): array
    {
        $start = now()->startOfMonth();
        $end = now()->endOfMonth();
        $stepsByDate = $this->stepsByDate($employee, $start->toDateString(), $end->toDateString());

        $daysInMonth = $end->day;
        $weekCount = (int) ceil($daysInMonth / 7);

        $entries = [];
        for ($w = 0; $w < $weekCount; $w++) {
            $firstDay = $w * 7 + 1;
            $lastDay = min($firstDay + 6, $daysInMonth);

            $total = 0;
            for ($day = $firstDay; $day <= $lastDay; $day++) {
                $date = $start->copy()->day($day)->toDateString();
                $total += $stepsByDate[$date] ?? 0;
            }

            $entries[] = ['label' => 'Minggu '.($w + 1), 'steps' => $total];
        }

        return [
            'entries' => $entries,
            'average_daily_steps' => $this->average($entries),
        ];
    }

    /** @return array<string, int> keyed by Y-m-d */
    private function stepsByDate(Employee $employee, string $start, string $end): array
    {
        return DailyActivityLog::where('employee_id', $employee->id)
            ->whereBetween('activity_date', [$start, $end])
            ->get()
            ->mapWithKeys(fn (DailyActivityLog $log) => [$log->activity_date->toDateString() => (int) $log->steps])
            ->all();
    }

    /** @param array<int, array<string, mixed>> $entries */
    private function average(array $entries): int
    {
        if ($entries === []) {
            return 0;
        }

        $total = array_sum(array_column($entries, 'steps'));

        return (int) round($total / count($entries));
    }
}
