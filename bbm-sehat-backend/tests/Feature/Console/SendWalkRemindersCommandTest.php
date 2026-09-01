<?php

namespace Tests\Feature\Console;

use App\Enums\AccountStatus;
use App\Models\DeviceToken;
use App\Models\Division;
use App\Models\Employee;
use App\Models\Role;
use App\Services\FirebaseNotificationService;
use Database\Seeders\DivisionSeeder;
use Database\Seeders\RoleSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Tests\TestCase;

/**
 * FirebaseNotificationService is mocked throughout — this suite is about
 * the command's own behavior (which slot argument it forwards, and the
 * same-slot-same-day dedup it's specifically responsible for preventing),
 * not FCM delivery itself.
 */
class SendWalkRemindersCommandTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(DivisionSeeder::class);
        $this->seed(RoleSeeder::class);
        Cache::flush();
    }

    private function employeeBelowTargetWithDevice(string $tokenSuffix = ''): Employee
    {
        $role = Role::where('code', 'EMPLOYEE')->firstOrFail();
        $division = Division::query()->firstOrFail();

        $employee = Employee::create([
            'employee_code' => 'TEST-'.uniqid(),
            'full_name' => 'Test Employee '.uniqid(),
            'email' => 'test-'.uniqid().'@test.local',
            'division_id' => $division->id,
            'role_id' => $role->id,
            'account_status' => AccountStatus::Active,
            'password' => 'irrelevant',
            'must_change_password' => false,
        ]);

        DeviceToken::create([
            'employee_id' => $employee->id,
            'fcm_token' => 'token-'.$employee->id.$tokenSuffix,
        ]);

        return $employee;
    }

    public function test_sends_reminder_to_eligible_employee(): void
    {
        $this->mock(FirebaseNotificationService::class, function ($mock) {
            $mock->shouldReceive('sendToDevice')->once()->andReturnNull();
        });

        $this->employeeBelowTargetWithDevice();

        $this->artisan('walk-reminders:send', ['slot' => 'afternoon'])
            ->assertExitCode(0);
    }

    public function test_running_the_same_slot_twice_in_one_day_does_not_resend(): void
    {
        $this->employeeBelowTargetWithDevice();

        // Exactly one real send expected across BOTH command invocations
        // below — the second run for the same slot must be a no-op.
        $this->mock(FirebaseNotificationService::class, function ($mock) {
            $mock->shouldReceive('sendToDevice')->once()->andReturnNull();
        });

        $this->artisan('walk-reminders:send', ['slot' => 'afternoon'])->assertExitCode(0);
        $this->artisan('walk-reminders:send', ['slot' => 'afternoon'])->assertExitCode(0);
    }

    public function test_a_different_slot_the_same_day_still_sends(): void
    {
        $this->employeeBelowTargetWithDevice();

        // Two DIFFERENT slots (afternoon, evening) on the same day are not
        // "duplicates" of each other — both should genuinely send.
        $this->mock(FirebaseNotificationService::class, function ($mock) {
            $mock->shouldReceive('sendToDevice')->twice()->andReturnNull();
        });

        $this->artisan('walk-reminders:send', ['slot' => 'afternoon'])->assertExitCode(0);
        $this->artisan('walk-reminders:send', ['slot' => 'evening'])->assertExitCode(0);
    }

    public function test_a_failed_send_is_not_marked_as_sent_and_remains_eligible_for_retry(): void
    {
        $this->employeeBelowTargetWithDevice();

        $this->mock(FirebaseNotificationService::class, function ($mock) {
            $mock->shouldReceive('sendToDevice')
                ->twice()
                ->andThrow(new \RuntimeException('transport error'));
        });

        // Both runs of the SAME slot should attempt a real send — the
        // first one failing must not have marked this employee as "sent"
        // for this slot (that would wrongly skip a retry).
        $this->artisan('walk-reminders:send', ['slot' => 'afternoon'])->assertExitCode(0);
        $this->artisan('walk-reminders:send', ['slot' => 'afternoon'])->assertExitCode(0);
    }
}
