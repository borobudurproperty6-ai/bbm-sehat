<?php

namespace App\Services;

use App\Enums\AccountStatus;
use App\Models\DeviceToken;
use App\Models\Employee;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Throwable;

class WalkReminderService
{
    // Consistent with MonitoringService's sanity-check — a reading above
    // this is more likely a sensor/sync glitch than a real day's steps, so
    // it's treated as unreliable (falls back to 0) rather than trusted as
    // proof the employee already hit their target.
    private const MAX_PLAUSIBLE_DAILY_STEPS = 50000;

    public function __construct(
        private readonly StepTargetResolver $targets,
        private readonly FirebaseNotificationService $notifications,
    ) {}

    /**
     * Sends a personalized "Ayo Jalan Kaki!" push to every active employee
     * who hasn't reached their step target yet today and has a registered
     * device token. Employees who already hit their target, or who have no
     * device registered, are skipped (not counted as failures) — only an
     * actual send attempt that throws (bad/expired token, transport error)
     * counts as a failure, so one bad token never stops the rest.
     *
     * $dedupSlot identifies *which* scheduled run this is (e.g. "afternoon",
     * "evening") — see SendWalkReminders. When set, an employee already
     * reminded under this exact slot today is skipped, so an accidental
     * re-run of the same scheduled slot (overlapping cron, a retry, etc.)
     * can't double-send. Left null for the manual "Kirim Reminder Jalan
     * Kaki" admin button, which is deliberately exempt — an admin
     * re-triggering it on purpose should always actually send.
     */
    public function sendToEmployeesBelowTarget(?string $dedupSlot = null): array
    {
        $today = now()->toDateString();

        $stepsToday = DB::table('daily_activity_logs')
            ->where('activity_date', $today)
            ->where('steps', '<=', self::MAX_PLAUSIBLE_DAILY_STEPS)
            ->pluck('steps', 'employee_id');

        $deviceTokens = DeviceToken::pluck('fcm_token', 'employee_id');

        $sentTo = [];
        $skippedNoDevice = [];
        $skippedDuplicate = [];
        $failed = [];

        $employees = Employee::query()->where('account_status', AccountStatus::Active)->get();

        foreach ($employees as $employee) {
            $steps = (int) ($stepsToday[$employee->id] ?? 0);
            $target = $this->targets->resolve($employee, $today);

            if ($steps >= $target) {
                continue;
            }

            $token = $deviceTokens[$employee->id] ?? null;
            if ($token === null) {
                $skippedNoDevice[] = $employee->full_name;
                continue;
            }

            $dedupKey = $dedupSlot !== null
                ? "walk_reminder_sent:{$employee->id}:{$today}:{$dedupSlot}"
                : null;

            if ($dedupKey !== null && Cache::has($dedupKey)) {
                $skippedDuplicate[] = $employee->full_name;
                continue;
            }

            $remaining = $target - $steps;

            try {
                $this->notifications->sendToDevice(
                    $token,
                    'Ayo Jalan Kaki!',
                    "Hai {$employee->full_name}, kamu masih perlu {$remaining} langkah lagi menuju target {$target} langkah hari ini!",
                    ['type' => 'walk_reminder'],
                );
                $sentTo[] = $employee->full_name;

                // Marked only after a confirmed successful send — a failed
                // attempt must remain eligible for the next check (this
                // same slot retried, or the next slot later today).
                if ($dedupKey !== null) {
                    Cache::put($dedupKey, true, now()->endOfDay());
                }
            } catch (Throwable $e) {
                $failed[] = [
                    'employee_id' => $employee->id,
                    'full_name' => $employee->full_name,
                    'reason' => $e->getMessage(),
                ];
            }
        }

        return [
            'sent_count' => count($sentTo),
            'skipped_no_device_count' => count($skippedNoDevice),
            'skipped_duplicate_count' => count($skippedDuplicate),
            'failed_count' => count($failed),
            'failed' => $failed,
        ];
    }
}
