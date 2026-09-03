<?php

namespace Tests\Feature\Dashboard;

use App\Enums\AccountStatus;
use App\Models\Division;
use App\Models\Employee;
use App\Models\Role;
use App\Support\RbacMatrixBuilder;
use Database\Seeders\DivisionSeeder;
use Database\Seeders\RoleSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

/**
 * Covers both RbacMatrixBuilder (the class that reads role: middleware
 * straight off the live routes — see its docblock for what is and isn't
 * auto-derived) and the GET /api/admin/user-settings/rbac-matrix endpoint
 * it backs.
 */
class RbacMatrixTest extends TestCase
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

    // ── RbacMatrixBuilder — reflects the actual routes/api.php state ──────

    public function test_matrix_matches_the_actual_route_definitions(): void
    {
        $matrix = (new RbacMatrixBuilder())->build();
        $byLabel = collect($matrix)->keyBy('label');

        // Each expectation here was cross-checked against `php artisan
        // route:list -v` at the time this was written — if routes/api.php
        // changes, this test (and the live matrix) should change together.
        $this->assertSame(['DIVISION_ADMIN', 'MANAGEMENT', 'SUPER_ADMIN'], $byLabel['Manajemen Karyawan (Lihat)']['roles']);
        $this->assertSame(['DIVISION_ADMIN', 'SUPER_ADMIN'], $byLabel['Manajemen Karyawan (Kelola)']['roles']);
        $this->assertSame(['ADMIN_UMUM_SDM', 'SUPER_ADMIN'], $byLabel['Ubah Status Akun']['roles']);
        $this->assertSame(['SUPER_ADMIN'], $byLabel['Log Aktivitas (Audit)']['roles']);
        $this->assertSame(['ADMIN_UMUM_SDM', 'MANAGEMENT', 'SUPER_ADMIN'], $byLabel['Dashboard Monitoring']['roles']);
        $this->assertSame(['ADMIN_UMUM_SDM', 'MANAGEMENT', 'SUPER_ADMIN'], $byLabel['Kirim Pengingat Jalan']['roles']);
        $this->assertSame(['SUPER_ADMIN'], $byLabel['Pengaturan Pengguna (halaman ini)']['roles']);

        $this->assertTrue($byLabel['Pengaturan Pengguna (halaman ini)']['whitelist_only']);
        $this->assertFalse($byLabel['Manajemen Karyawan (Kelola)']['whitelist_only']);
    }

    /**
     * Regression test for a real bug caught while building this: "Kelola"
     * routes are nested under TWO stacked role: middleware (an outer
     * division_admin,management,super_admin group and an inner
     * division_admin,super_admin group) — Laravel requires passing both,
     * so the effective allowed set is their INTERSECTION.
     * MANAGEMENT passes the outer layer but not the inner one, so it must
     * NOT appear here even though a naive "read the first role: middleware
     * found" implementation would have included it.
     */
    public function test_kelola_module_excludes_management_despite_outer_group_allowing_it(): void
    {
        $matrix = (new RbacMatrixBuilder())->build();
        $kelola = collect($matrix)->firstWhere('label', 'Manajemen Karyawan (Kelola)');

        $this->assertNotContains('MANAGEMENT', $kelola['roles']);
    }

    public function test_every_module_has_a_non_empty_role_list(): void
    {
        $matrix = (new RbacMatrixBuilder())->build();

        foreach ($matrix as $module) {
            $this->assertNotEmpty($module['roles'], "Module \"{$module['label']}\" has no roles.");
        }
    }

    // ── GET /api/admin/user-settings/rbac-matrix — access control ─────────

    public function test_whitelisted_super_admin_can_view_the_matrix(): void
    {
        $admin = $this->employeeWithRole('SUPER_ADMIN', 'BBM-005');

        $response = $this->actingAs($admin, 'sanctum')
            ->getJson('/api/admin/user-settings/rbac-matrix')
            ->assertOk();

        $this->assertNotEmpty($response->json('data'));
    }

    public function test_super_admin_role_but_not_whitelisted_employee_code_gets_403(): void
    {
        $admin = $this->employeeWithRole('SUPER_ADMIN', 'BBM-0001');

        $this->actingAs($admin, 'sanctum')
            ->getJson('/api/admin/user-settings/rbac-matrix')
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
            ->getJson('/api/admin/user-settings/rbac-matrix')
            ->assertForbidden();
    }

    public function test_unauthenticated_request_gets_401(): void
    {
        $this->getJson('/api/admin/user-settings/rbac-matrix')->assertUnauthorized();
    }
}
