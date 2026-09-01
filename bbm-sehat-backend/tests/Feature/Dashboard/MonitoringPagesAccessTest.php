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
 * The four "Monitoring" dashboard pages (routes/web.php) must be gated
 * exactly like the /api/monitoring/* endpoints they read from — management,
 * super_admin, admin_umum_sdm in; everyone else, including division_admin
 * and employee, rejected at the route-middleware layer before the page's
 * Blade view is ever returned. Unlike "Pengaturan Pengguna" there is no
 * additional employee_code whitelist here. Mirrors
 * PengaturanPenggunaPageAccessTest's testing style.
 */
class MonitoringPagesAccessTest extends TestCase
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

    public static function pages(): array
    {
        return [
            ['Ringkasan', '/dashboard/monitoring/ringkasan'],
            ['Per Divisi', '/dashboard/monitoring/per-divisi'],
            ['Karyawan Tidak Aktif', '/dashboard/monitoring/tidak-aktif'],
            ['Progres Karyawan', '/dashboard/monitoring/progres-karyawan'],
        ];
    }

    public static function allowedRoles(): array
    {
        return [['MANAGEMENT'], ['SUPER_ADMIN'], ['ADMIN_UMUM_SDM']];
    }

    public static function deniedRoles(): array
    {
        return [['EMPLOYEE'], ['DIVISION_ADMIN']];
    }

    public static function pagesWithAllowedRoles(): array
    {
        $cases = [];
        foreach (self::pages() as [$label, $path]) {
            foreach (self::allowedRoles() as [$role]) {
                $cases["$label / $role"] = [$path, $role];
            }
        }

        return $cases;
    }

    public static function pagesWithDeniedRoles(): array
    {
        $cases = [];
        foreach (self::pages() as [$label, $path]) {
            foreach (self::deniedRoles() as [$role]) {
                $cases["$label / $role"] = [$path, $role];
            }
        }

        return $cases;
    }

    #[DataProvider('pagesWithAllowedRoles')]
    public function test_allowed_role_can_open_the_page(string $path, string $roleCode): void
    {
        $employee = $this->employeeWithRole($roleCode);

        $this->actingAs($employee, 'web')
            ->get($path)
            ->assertOk()
            ->assertSee('admin-root', false);
    }

    #[DataProvider('pagesWithDeniedRoles')]
    public function test_denied_role_is_rejected_before_any_page_data_is_sent(string $path, string $roleCode): void
    {
        $employee = $this->employeeWithRole($roleCode);

        $response = $this->actingAs($employee, 'web')
            ->get($path)
            ->assertForbidden();

        $response->assertDontSee('admin-root', false);
        $response->assertDontSee($employee->full_name);
    }

    #[DataProvider('pages')]
    public function test_guest_is_rejected_before_any_page_data_is_sent(string $label, string $path): void
    {
        $response = $this->get($path);

        $response->assertRedirect(route('dashboard.login'));
    }
}
