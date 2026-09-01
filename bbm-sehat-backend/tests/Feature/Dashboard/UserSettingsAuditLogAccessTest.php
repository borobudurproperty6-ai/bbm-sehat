<?php

namespace Tests\Feature\Dashboard;

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

/**
 * GET /api/admin/user-settings/audit-logs — the "Log Aktivitas" tab's data
 * source. Reuses AuditLogController::index() (same as the pre-existing
 * /api/admin/audit-logs), but under the whitelisted-SUPER_ADMIN gate this
 * whole Pengaturan Pengguna feature uses, per the same pattern as every
 * other endpoint here (UserSettingsApiAccessTest, CredentialSlipTest,
 * RbacMatrixTest).
 */
class UserSettingsAuditLogAccessTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(DivisionSeeder::class);
        $this->seed(RoleSeeder::class);
    }

    private function employeeWithRole(string $roleCode, ?string $employeeCode = null): Employee
    {
        $role = Role::where('code', $roleCode)->firstOrFail();
        $division = Division::query()->firstOrFail();

        return Employee::create([
            'employee_code' => $employeeCode ?? 'TEST-'.$roleCode.'-'.uniqid(),
            'full_name' => "Test $roleCode",
            'email' => strtolower($roleCode).'-'.uniqid().'@test.local',
            'division_id' => $division->id,
            'role_id' => $role->id,
            'account_status' => AccountStatus::Active,
            'password' => 'irrelevant',
            'must_change_password' => false,
        ]);
    }

    public function test_whitelisted_super_admin_can_list_audit_logs(): void
    {
        $admin = $this->employeeWithRole('SUPER_ADMIN', 'BBM-006');
        $target = $this->employeeWithRole('EMPLOYEE');

        AuditLog::create([
            'actor_employee_id' => $admin->id,
            'action' => AuditLog::ACTION_PASSWORD_RESET,
            'target_employee_id' => $target->id,
        ]);

        $response = $this->actingAs($admin, 'sanctum')
            ->getJson('/api/admin/user-settings/audit-logs')
            ->assertOk();

        $this->assertNotEmpty($response->json('data'));
    }

    public function test_super_admin_role_but_not_whitelisted_employee_code_gets_403(): void
    {
        $admin = $this->employeeWithRole('SUPER_ADMIN', 'BBM-0001');

        $this->actingAs($admin, 'sanctum')
            ->getJson('/api/admin/user-settings/audit-logs')
            ->assertForbidden();
    }

    public static function nonSuperAdminRoles(): array
    {
        return [['EMPLOYEE'], ['DIVISION_ADMIN'], ['MANAGEMENT'], ['ADMIN_UMUM_SDM']];
    }

    #[DataProvider('nonSuperAdminRoles')]
    public function test_non_super_admin_role_gets_403(string $roleCode): void
    {
        $employee = $this->employeeWithRole($roleCode);

        $this->actingAs($employee, 'sanctum')
            ->getJson('/api/admin/user-settings/audit-logs')
            ->assertForbidden();
    }

    public function test_unauthenticated_request_gets_401(): void
    {
        $this->getJson('/api/admin/user-settings/audit-logs')->assertUnauthorized();
    }
}
