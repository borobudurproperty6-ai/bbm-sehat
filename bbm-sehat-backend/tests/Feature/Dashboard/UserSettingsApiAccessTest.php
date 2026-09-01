<?php

namespace Tests\Feature\Dashboard;

use App\Enums\AccountStatus;
use App\Models\Division;
use App\Models\Employee;
use App\Models\Role;
use Database\Seeders\DivisionSeeder;
use Database\Seeders\RoleSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

/**
 * The /api/admin/user-settings/* route group (routes/api.php) backs the
 * "Pengaturan Pengguna" page's data — it must enforce the exact same
 * role-AND-whitelist gate as the page itself
 * (PengaturanPenggunaPageAccessTest), independent of whether the request
 * came from that page's UI or a direct API call (e.g. Postman).
 */
class UserSettingsApiAccessTest extends TestCase
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

    public static function nonSuperAdminRoles(): array
    {
        return [['EMPLOYEE'], ['DIVISION_ADMIN'], ['MANAGEMENT'], ['ADMIN_UMUM_SDM']];
    }

    public function test_whitelisted_super_admin_can_list_employees(): void
    {
        $admin = $this->employeeWithRole('SUPER_ADMIN', 'BBM-005');

        $this->actingAs($admin, 'sanctum')
            ->getJson('/api/admin/user-settings/employees')
            ->assertOk();
    }

    public function test_whitelisted_super_admin_can_list_divisions_and_roles(): void
    {
        $admin = $this->employeeWithRole('SUPER_ADMIN', 'BBM-006');

        $this->actingAs($admin, 'sanctum')
            ->getJson('/api/admin/user-settings/divisions')
            ->assertOk();

        $this->actingAs($admin, 'sanctum')
            ->getJson('/api/admin/user-settings/roles')
            ->assertOk()
            ->assertJsonFragment(['code' => 'SUPER_ADMIN']);
    }

    public function test_super_admin_role_but_not_whitelisted_employee_code_gets_403(): void
    {
        $admin = $this->employeeWithRole('SUPER_ADMIN', 'BBM-0001');

        $this->actingAs($admin, 'sanctum')
            ->getJson('/api/admin/user-settings/employees')
            ->assertForbidden();
    }

    #[DataProvider('nonSuperAdminRoles')]
    public function test_non_super_admin_role_gets_403(string $roleCode): void
    {
        $employee = $this->employeeWithRole($roleCode);

        $this->actingAs($employee, 'sanctum')
            ->getJson('/api/admin/user-settings/employees')
            ->assertForbidden();
    }

    public function test_unauthenticated_request_gets_401(): void
    {
        $this->getJson('/api/admin/user-settings/employees')->assertUnauthorized();
    }

    public function test_whitelisted_super_admin_can_create_employee_via_this_route_group(): void
    {
        $admin = $this->employeeWithRole('SUPER_ADMIN', 'BBM-005');
        $division = Division::query()->firstOrFail();

        $this->actingAs($admin, 'sanctum')
            ->postJson('/api/admin/user-settings/employees', [
                'full_name' => 'Karyawan Baru',
                'email' => 'karyawan.usergroup@test.local',
                'division_id' => $division->id,
            ])
            ->assertCreated();
    }

    public function test_non_whitelisted_super_admin_cannot_create_employee_via_this_route_group(): void
    {
        $admin = $this->employeeWithRole('SUPER_ADMIN', 'BBM-0001');
        $division = Division::query()->firstOrFail();

        $this->actingAs($admin, 'sanctum')
            ->postJson('/api/admin/user-settings/employees', [
                'full_name' => 'Karyawan Baru',
                'email' => 'karyawan.blocked@test.local',
                'division_id' => $division->id,
            ])
            ->assertForbidden();

        $this->assertDatabaseMissing('employees', ['email' => 'karyawan.blocked@test.local']);
    }
}
