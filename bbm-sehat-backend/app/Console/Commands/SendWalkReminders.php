<?php

namespace App\Console\Commands;

use App\Services\WalkReminderService;
use Illuminate\Console\Attributes\Description;
use Illuminate\Console\Attributes\Signature;
use Illuminate\Console\Command;

#[Signature('walk-reminders:send {slot : Identifies this scheduled run (e.g. afternoon, evening) — prevents a duplicate send to the same employee if this exact slot ends up running more than once today}')]
#[Description('Send "Ayo Jalan Kaki!" push reminders to active employees below their step target today.')]
class SendWalkReminders extends Command
{
    public function handle(WalkReminderService $reminders): int
    {
        $slot = $this->argument('slot');
        $result = $reminders->sendToEmployeesBelowTarget(dedupSlot: $slot);

        $this->info(sprintf(
            'Slot [%s]: terkirim %d, dilewati (belum ada device) %d, dilewati (duplikat) %d, gagal %d.',
            $slot,
            $result['sent_count'],
            $result['skipped_no_device_count'],
            $result['skipped_duplicate_count'],
            $result['failed_count'],
        ));

        foreach ($result['failed'] as $failure) {
            $this->warn("Gagal untuk {$failure['full_name']} (id={$failure['employee_id']}): {$failure['reason']}");
        }

        return self::SUCCESS;
    }
}
