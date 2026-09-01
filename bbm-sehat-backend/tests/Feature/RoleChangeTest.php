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
use Tests\TestCase;

/**
 * Role changes are the most sensitive access-control action in the system —
 * only SUPER_ADMIN may ever change an employee's role_id, regardless of who
 * else can reach PATCH /admin/employees/{employee} for other fields.
 */
class RoleChangeTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(DivisionSeeder::class);
        $this->seed(RoleSeeder::class);
    }

    private function employeeWithRole(string $roleCode, ?int $divisionId = null): Employee
    {
        $role = Role::where('code', $roleCode)->firstOrFail();
        $divisionId ??= Division::query()->firstOrFail()->id;

        return Employee::create([
            'employee_code' => 'TEST-'.$roleCode.'-'.uniqid(),
            'full_name' => "Test $roleCode",
            'email' => strtolower($roleCode).'-'.uniqid().'@test.local',
            'division_id' => $divisionId,
            'role_id' => $role->id,
            'account_status' => AccountStatus::Active,
            'password' => 'irrelevant',
            'must_change_password' => false,
        ]);
    }

    public function test_division_admin_cannot_change_role_and_request_is_rejected(): void
    {
        $division = Division::query()->firstOrFail();
        $actor = $this->employeeWithRole('DIVISION_ADMIN', $division->id);
        $target = $this->employeeWithRole('EMPLOYEE', $division->id);
        $newRole = Role::where('code', 'DIVISION_ADMIN')->firstOrFail();

        $response = $this->actingAs($actor, 'sanctum')
            ->patchJson("/api/admin/employees/{$target->id}", ['role_id' => $newRole->id])
            ->assertStatus(403);

        $this->assertNotEmpty($response->json('message'));
        $this->assertSame('EMPLOYEE', $target->fresh()->role->code);
        $this->assertDatabaseMissing('audit_logs', ['action' => AuditLog::ACTION_ROLE_CHANGED]);
    }

    public function test_division_admin_can_still_edit_non_role_fields(): void
    {
        $division = Division::query()->firstOrFail();
        $actor = $this->employeeWithRole('DIVISION_ADMIN', $division->id);
        $target = $this->employeeWithRole('EMPLOYEE', $division->id);

        $this->actingAs($actor, 'sanctum')
            ->patchJson("/api/admin/employees/{$target->id}", ['full_name' => 'Nama Baru'])
            ->assertOk()
            ->assertJsonPath('data.full_name', 'Nama Baru');

        $this->assertDatabaseMissing('audit_logs', ['action' => AuditLog::ACTION_ROLE_CHANGED]);
    }

    public function test_admin_umum_sdm_gets_403_from_the_employee_update_endpoint_entirely(): void
    {
        $actor = $this->employeeWithRole('ADMIN_UMUM_SDM');
        $target = $this->employeeWithRole('EMPLOYEE');
        $newRole = Role::where('code', 'DIVISION_ADMIN')->firstOrFail();

        $this->actingAs($actor, 'sanctum')
            ->patchJson("/api/admin/employees/{$target->id}", ['role_id' => $newRole->id])
            ->assertStatus(403);

        $this->assertSame('EMPLOYEE', $target->fresh()->role->code);
    }

    public function test_employee_role_gets_403_from_route_middleware(): void
    {
        $actor = $this->employeeWithRole('EMPLOYEE');
        $target = $this->employeeWithRole('EMPLOYEE');
        $newRole = Role::where('code', 'SUPER_ADMIN')->firstOrFail();

        $this->actingAs($actor, 'sanctum')
            ->patchJson("/api/admin/employees/{$target->id}", ['role_id' => $newRole->id])
            ->assertStatus(403);
    }

    public function test_super_admin_can_change_role_and_it_is_audited(): void
    {
        $admin = $this->employeeWithRole('SUPER_ADMIN');
        $target = $this->employeeWithRole('EMPLOYEE');
        $newRole = Role::where('code', 'DIVISION_ADMIN')->firstOrFail();

        $response = $this->actingAs($admin, 'sanctum')
            ->patchJson("/api/admin/employees/{$target->id}", ['role_id' => $newRole->id])
            ->assertOk();

        $response->assertJsonPath('data.role.code', 'DIVISION_ADMIN');
        $this->assertSame('DIVISION_ADMIN', $target->fresh()->role->code);

        $this->assertDatabaseHas('audit_logs', [
            'action' => AuditLog::ACTION_ROLE_CHANGED,
            'actor_employee_id' => $admin->id,
            'target_employee_id' => $target->id,
        ]);

        $log = AuditLog::where('action', AuditLog::ACTION_ROLE_CHANGED)->firstOrFail();
        $this->assertSame('EMPLOYEE', $log->details['old_role_code']);
        $this->assertSame('DIVISION_ADMIN', $log->details['new_role_code']);
    }

    public function test_super_admin_setting_the_same_role_does_not_write_a_duplicate_audit_log(): void
    {
        $admin = $this->employeeWithRole('SUPER_ADMIN');
        $target = $this->employeeWithRole('EMPLOYEE');

        $this->actingAs($admin, 'sanctum')
            ->patchJson("/api/admin/employees/{$target->id}", ['role_id' => $target->role_id])
            ->assertOk();

        $this->assertDatabaseMissing('audit_logs', ['action' => AuditLog::ACTION_ROLE_CHANGED]);
    }

    /**
     * A Super Admin changing their OWN role — including to another elevated
     * role, not just a downgrade — must be rejected. Comparing role
     * "levels" to detect only downgrades isn't well-defined, so any self
     * role-change is refused: the risk is losing access with nobody left
     * to undo it.
     */
    public function test_super_admin_cannot_change_their_own_role(): void
    {
        $admin = $this->employeeWithRole('SUPER_ADMIN');
        $newRole = Role::where('code', 'DIVISION_ADMIN')->firstOrFail();

        $response = $this->actingAs($admin, 'sanctum')
            ->patchJson("/api/admin/employees/{$admin->id}", ['role_id' => $newRole->id])
            ->assertStatus(422);

        $this->assertNotEmpty($response->json('message'));
        $this->assertSame('SUPER_ADMIN', $admin->fresh()->role->code);
        $this->assertDatabaseMissing('audit_logs', ['action' => AuditLog::ACTION_ROLE_CHANGED]);
    }

    public function test_super_admin_can_combine_role_change_with_other_fields_in_one_request(): void
    {
        $admin = $this->employeeWithRole('SUPER_ADMIN');
        $target = $this->employeeWithRole('EMPLOYEE');
        $newRole = Role::where('code', 'DIVISION_ADMIN')->firstOrFail();

        $this->actingAs($admin, 'sanctum')
            ->patchJson("/api/admin/employees/{$target->id}", [
                'full_name' => 'Promosi Baru',
                'role_id' => $newRole->id,
            ])
            ->assertOk()
            ->assertJsonPath('data.full_name', 'Promosi Baru')
            ->assertJsonPath('data.role.code', 'DIVISION_ADMIN');
    }
}
