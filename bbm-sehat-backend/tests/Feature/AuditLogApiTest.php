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
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class AuditLogApiTest extends TestCase
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

    public static function nonSuperAdminRoles(): array
    {
        return [['EMPLOYEE'], ['DIVISION_ADMIN'], ['MANAGEMENT'], ['ADMIN_UMUM_SDM']];
    }

    public function test_super_admin_can_list_audit_logs(): void
    {
        $admin = $this->employeeWithRole('SUPER_ADMIN');
        $target = $this->employeeWithRole('EMPLOYEE');

        AuditLog::create([
            'actor_employee_id' => $admin->id,
            'action' => AuditLog::ACTION_PASSWORD_RESET,
            'target_employee_id' => $target->id,
        ]);

        $response = $this->actingAs($admin, 'sanctum')
            ->getJson('/api/admin/audit-logs')
            ->assertOk();

        $response->assertJsonPath('data.0.action', AuditLog::ACTION_PASSWORD_RESET);
        $response->assertJsonPath('data.0.actor.id', $admin->id);
        $response->assertJsonPath('data.0.target.id', $target->id);
        $this->assertArrayHasKey('current_page', $response->json('meta'));
    }

    #[DataProvider('nonSuperAdminRoles')]
    public function test_non_super_admin_role_gets_403(string $roleCode): void
    {
        $employee = $this->employeeWithRole($roleCode);

        $this->actingAs($employee, 'sanctum')
            ->getJson('/api/admin/audit-logs')
            ->assertForbidden();
    }

    public function test_unauthenticated_request_gets_401(): void
    {
        $this->getJson('/api/admin/audit-logs')->assertUnauthorized();
    }

    public function test_filters_by_action(): void
    {
        $admin = $this->employeeWithRole('SUPER_ADMIN');
        $target = $this->employeeWithRole('EMPLOYEE');

        AuditLog::create([
            'actor_employee_id' => $admin->id,
            'action' => AuditLog::ACTION_PASSWORD_RESET,
            'target_employee_id' => $target->id,
        ]);
        AuditLog::create([
            'actor_employee_id' => $admin->id,
            'action' => AuditLog::ACTION_ROLE_CHANGED,
            'target_employee_id' => $target->id,
        ]);

        $response = $this->actingAs($admin, 'sanctum')
            ->getJson('/api/admin/audit-logs?action='.AuditLog::ACTION_ROLE_CHANGED)
            ->assertOk();

        $actions = collect($response->json('data'))->pluck('action');
        $this->assertTrue($actions->every(fn ($action) => $action === AuditLog::ACTION_ROLE_CHANGED));
        $this->assertCount(1, $actions);
    }

    public function test_filters_by_target_employee_id(): void
    {
        $admin = $this->employeeWithRole('SUPER_ADMIN');
        $targetA = $this->employeeWithRole('EMPLOYEE');
        $targetB = $this->employeeWithRole('EMPLOYEE');

        AuditLog::create([
            'actor_employee_id' => $admin->id,
            'action' => AuditLog::ACTION_PASSWORD_RESET,
            'target_employee_id' => $targetA->id,
        ]);
        AuditLog::create([
            'actor_employee_id' => $admin->id,
            'action' => AuditLog::ACTION_PASSWORD_RESET,
            'target_employee_id' => $targetB->id,
        ]);

        $response = $this->actingAs($admin, 'sanctum')
            ->getJson('/api/admin/audit-logs?target_employee_id='.$targetA->id)
            ->assertOk();

        $targetIds = collect($response->json('data'))->pluck('target.id');
        $this->assertSame([$targetA->id], $targetIds->all());
    }

    public function test_filters_by_date_range_inclusive_on_both_ends(): void
    {
        $admin = $this->employeeWithRole('SUPER_ADMIN');
        $target = $this->employeeWithRole('EMPLOYEE');

        $before = AuditLog::create([
            'actor_employee_id' => $admin->id,
            'action' => AuditLog::ACTION_PASSWORD_RESET,
            'target_employee_id' => $target->id,
        ]);
        $before->forceFill(['created_at' => '2026-08-01 10:00:00'])->save();

        $inRange = AuditLog::create([
            'actor_employee_id' => $admin->id,
            'action' => AuditLog::ACTION_PASSWORD_RESET,
            'target_employee_id' => $target->id,
        ]);
        $inRange->forceFill(['created_at' => '2026-08-15 10:00:00'])->save();

        $after = AuditLog::create([
            'actor_employee_id' => $admin->id,
            'action' => AuditLog::ACTION_PASSWORD_RESET,
            'target_employee_id' => $target->id,
        ]);
        $after->forceFill(['created_at' => '2026-08-31 10:00:00'])->save();

        $response = $this->actingAs($admin, 'sanctum')
            ->getJson('/api/admin/audit-logs?date_from=2026-08-10&date_to=2026-08-20')
            ->assertOk();

        $ids = collect($response->json('data'))->pluck('id');
        $this->assertSame([$inRange->id], $ids->all());
    }

    public function test_date_range_boundary_dates_are_included(): void
    {
        $admin = $this->employeeWithRole('SUPER_ADMIN');
        $target = $this->employeeWithRole('EMPLOYEE');

        $onStartBoundary = AuditLog::create([
            'actor_employee_id' => $admin->id,
            'action' => AuditLog::ACTION_PASSWORD_RESET,
            'target_employee_id' => $target->id,
        ]);
        $onStartBoundary->forceFill(['created_at' => '2026-08-10 23:59:59'])->save();

        $onEndBoundary = AuditLog::create([
            'actor_employee_id' => $admin->id,
            'action' => AuditLog::ACTION_PASSWORD_RESET,
            'target_employee_id' => $target->id,
        ]);
        $onEndBoundary->forceFill(['created_at' => '2026-08-20 00:00:01'])->save();

        $response = $this->actingAs($admin, 'sanctum')
            ->getJson('/api/admin/audit-logs?date_from=2026-08-10&date_to=2026-08-20')
            ->assertOk();

        $ids = collect($response->json('data'))->pluck('id')->sort()->values();
        $this->assertSame([$onStartBoundary->id, $onEndBoundary->id], $ids->all());
    }

    // ── Integration: existing sensitive actions now write an audit row ────

    public function test_admin_password_reset_writes_audit_log(): void
    {
        $admin = $this->employeeWithRole('SUPER_ADMIN');
        $target = $this->employeeWithRole('EMPLOYEE');

        $this->actingAs($admin, 'sanctum')
            ->postJson("/api/admin/employees/{$target->id}/reset-password")
            ->assertOk();

        $this->assertDatabaseHas('audit_logs', [
            'action' => AuditLog::ACTION_PASSWORD_RESET,
            'actor_employee_id' => $admin->id,
            'target_employee_id' => $target->id,
        ]);
    }

    public function test_role_change_writes_audit_log(): void
    {
        $admin = $this->employeeWithRole('SUPER_ADMIN');
        $target = $this->employeeWithRole('EMPLOYEE');
        $newRole = Role::where('code', 'DIVISION_ADMIN')->firstOrFail();

        $this->actingAs($admin, 'sanctum')
            ->patchJson("/api/admin/employees/{$target->id}", ['role_id' => $newRole->id])
            ->assertOk();

        $this->assertDatabaseHas('audit_logs', [
            'action' => AuditLog::ACTION_ROLE_CHANGED,
            'actor_employee_id' => $admin->id,
            'target_employee_id' => $target->id,
        ]);
    }

    public function test_role_update_with_unchanged_role_does_not_write_audit_log(): void
    {
        $admin = $this->employeeWithRole('SUPER_ADMIN');
        $target = $this->employeeWithRole('EMPLOYEE');

        $this->actingAs($admin, 'sanctum')
            ->patchJson("/api/admin/employees/{$target->id}", ['role_id' => $target->role_id])
            ->assertOk();

        $this->assertDatabaseMissing('audit_logs', ['action' => AuditLog::ACTION_ROLE_CHANGED]);
    }

    public function test_successful_mobile_login_writes_audit_log(): void
    {
        $employee = Employee::create([
            'employee_code' => 'TEST-LOGIN-'.uniqid(),
            'full_name' => 'Test Login',
            'email' => 'login-'.uniqid().'@test.local',
            'division_id' => Division::query()->firstOrFail()->id,
            'role_id' => Role::where('code', 'EMPLOYEE')->firstOrFail()->id,
            'account_status' => AccountStatus::Active,
            'password' => 'correct-password',
            'must_change_password' => false,
        ]);

        $this->postJson('/api/login', [
            'employee_code' => $employee->employee_code,
            'password' => 'correct-password',
        ])->assertOk();

        $this->assertDatabaseHas('audit_logs', [
            'action' => AuditLog::ACTION_LOGIN_SUCCESS,
            'actor_employee_id' => $employee->id,
            'target_employee_id' => $employee->id,
        ]);
    }

    public function test_failed_mobile_login_writes_audit_log(): void
    {
        $employee = Employee::create([
            'employee_code' => 'TEST-LOGINFAIL-'.uniqid(),
            'full_name' => 'Test Login Fail',
            'email' => 'loginfail-'.uniqid().'@test.local',
            'division_id' => Division::query()->firstOrFail()->id,
            'role_id' => Role::where('code', 'EMPLOYEE')->firstOrFail()->id,
            'account_status' => AccountStatus::Active,
            'password' => 'correct-password',
            'must_change_password' => false,
        ]);

        $this->postJson('/api/login', [
            'employee_code' => $employee->employee_code,
            'password' => 'wrong-password',
        ])->assertStatus(401);

        $this->assertDatabaseHas('audit_logs', [
            'action' => AuditLog::ACTION_LOGIN_FAILED,
            'actor_employee_id' => null,
            'target_employee_id' => $employee->id,
        ]);
    }

    public function test_successful_dashboard_login_writes_audit_log(): void
    {
        $employee = $this->employeeWithRole('SUPER_ADMIN');
        $employee->forceFill(['password' => 'correct-password'])->save();

        // The web-guard session login only runs through Sanctum's session
        // middleware for requests Sanctum recognizes as coming from the
        // configured frontend (matched via the Referer header) — a plain
        // postJson() otherwise hits "Session store not set on request."
        $this->postJson('/api/admin/login', [
            'email' => $employee->email,
            'password' => 'correct-password',
        ], ['Referer' => 'http://localhost'])->assertOk();

        $this->assertDatabaseHas('audit_logs', [
            'action' => AuditLog::ACTION_LOGIN_SUCCESS,
            'actor_employee_id' => $employee->id,
        ]);
    }
}
