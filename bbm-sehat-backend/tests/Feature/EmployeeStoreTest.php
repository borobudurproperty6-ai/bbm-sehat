<?php

namespace Tests\Feature;

use App\Enums\AccountStatus;
use App\Models\AuditLog;
use App\Models\Division;
use App\Models\Employee;
use App\Models\Role;
use Database\Seeders\DivisionSeeder;
use Database\Seeders\RoleSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Notification;
use Tests\TestCase;

/**
 * Creating an employee (POST /admin/employees) previously wrote nothing to
 * audit_logs at all, despite AuditLog::ACTION_USER_CREATED existing for
 * exactly this — this suite covers that gap being closed.
 */
class EmployeeStoreTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Notification::fake();
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

    public function test_creating_an_employee_writes_an_audit_log(): void
    {
        $admin = $this->employeeWithRole('SUPER_ADMIN');
        $division = Division::query()->firstOrFail();

        $response = $this->actingAs($admin, 'sanctum')
            ->postJson('/api/admin/employees', [
                'full_name' => 'Karyawan Baru',
                'email' => 'karyawan.baru@test.local',
                'division_id' => $division->id,
            ])
            ->assertCreated();

        $newEmployeeId = $response->json('data.id');

        $this->assertDatabaseHas('audit_logs', [
            'action' => AuditLog::ACTION_USER_CREATED,
            'actor_employee_id' => $admin->id,
            'target_employee_id' => $newEmployeeId,
        ]);
    }

    public function test_response_still_returns_the_temporary_password_the_admin_must_relay(): void
    {
        $admin = $this->employeeWithRole('SUPER_ADMIN');
        $division = Division::query()->firstOrFail();

        $response = $this->actingAs($admin, 'sanctum')
            ->postJson('/api/admin/employees', [
                'full_name' => 'Karyawan Baru',
                'email' => 'karyawan.baru2@test.local',
                'division_id' => $division->id,
            ])
            ->assertCreated();

        $this->assertNotEmpty($response->json('temporary_password'));
    }
}
