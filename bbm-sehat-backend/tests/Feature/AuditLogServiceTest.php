<?php

namespace Tests\Feature;

use App\Enums\AccountStatus;
use App\Models\AuditLog;
use App\Models\Division;
use App\Models\Employee;
use App\Models\Role;
use App\Services\AuditLogService;
use Database\Seeders\DivisionSeeder;
use Database\Seeders\RoleSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AuditLogServiceTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(DivisionSeeder::class);
        $this->seed(RoleSeeder::class);
    }

    private function employeeWithRole(string $roleCode): Employee
    {
        $role = Role::where('code', $roleCode)->firstOrFail();
        $division = Division::query()->firstOrFail();

        return Employee::create([
            'employee_code' => 'TEST-'.$roleCode.'-'.uniqid(),
            'full_name' => "Test $roleCode",
            'email' => strtolower($roleCode).'-'.uniqid().'@test.local',
            'division_id' => $division->id,
            'role_id' => $role->id,
            'account_status' => AccountStatus::Active,
            'password' => 'irrelevant',
            'must_change_password' => false,
        ]);
    }

    public function test_log_persists_actor_target_action_and_details(): void
    {
        $actor = $this->employeeWithRole('SUPER_ADMIN');
        $target = $this->employeeWithRole('EMPLOYEE');

        $entry = (new AuditLogService)->log(
            AuditLog::ACTION_ROLE_CHANGED,
            $actor,
            $target,
            ['old_role_id' => 1, 'new_role_id' => 2]
        );

        $this->assertDatabaseHas('audit_logs', [
            'id' => $entry->id,
            'action' => AuditLog::ACTION_ROLE_CHANGED,
            'actor_employee_id' => $actor->id,
            'target_employee_id' => $target->id,
        ]);
        $this->assertSame(['old_role_id' => 1, 'new_role_id' => 2], $entry->fresh()->details);
    }

    public function test_log_allows_null_actor_and_target(): void
    {
        $entry = (new AuditLogService)->log(AuditLog::ACTION_LOGIN_FAILED, null, null, ['identifier' => 'ghost@test.local']);

        $this->assertDatabaseHas('audit_logs', [
            'id' => $entry->id,
            'action' => AuditLog::ACTION_LOGIN_FAILED,
            'actor_employee_id' => null,
            'target_employee_id' => null,
        ]);
    }

    public function test_log_stores_null_details_when_none_given(): void
    {
        $entry = (new AuditLogService)->log(AuditLog::ACTION_LOGIN_SUCCESS, $this->employeeWithRole('EMPLOYEE'));

        $this->assertNull($entry->fresh()->details);
    }
}
