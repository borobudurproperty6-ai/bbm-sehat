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
 * The "Pengaturan Pengguna" dashboard page (routes/web.php) must reject
 * everyone except the two whitelisted SUPER_ADMIN employee_codes
 * (config('dashboard.user_settings_allowed_employee_codes')) at the
 * route-middleware layer — before the page's Blade view (and therefore its
 * data) is ever returned. Holding the SUPER_ADMIN role is necessary but not
 * sufficient — see test_super_admin_role_but_not_whitelisted_gets_403().
 * Mirrors the role-matrix testing style already used in AuditLogApiTest for
 * the SUPER_ADMIN-only API endpoint.
 */
class PengaturanPenggunaPageAccessTest extends TestCase
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

    public function test_whitelisted_super_admin_can_open_the_page(): void
    {
        $admin = $this->employeeWithRole('SUPER_ADMIN', 'BBM-005');

        $this->actingAs($admin, 'web')
            ->get('/dashboard/pengaturan-pengguna')
            ->assertOk()
            ->assertSee('Pengaturan Pengguna')
            ->assertSee('admin-root', false);
    }

    /**
     * Holding the SUPER_ADMIN role is not enough on its own — the generic
     * "Super Admin" seed account (BBM-0001) has this exact role but is
     * deliberately NOT in config('dashboard.user_settings_allowed_employee_codes'),
     * so it must be rejected exactly like any other non-whitelisted role.
     */
    public function test_super_admin_role_but_not_whitelisted_employee_code_gets_403(): void
    {
        $admin = $this->employeeWithRole('SUPER_ADMIN', 'BBM-0001');

        $response = $this->actingAs($admin, 'web')
            ->get('/dashboard/pengaturan-pengguna')
            ->assertForbidden();

        $response->assertDontSee('admin-root', false);
        $response->assertDontSee($admin->full_name);
    }

    #[DataProvider('nonSuperAdminRoles')]
    public function test_non_super_admin_role_is_rejected_before_any_page_data_is_sent(string $roleCode): void
    {
        $employee = $this->employeeWithRole($roleCode);

        $response = $this->actingAs($employee, 'web')
            ->get('/dashboard/pengaturan-pengguna')
            ->assertForbidden();

        // Not just a non-200 status — the page's own markup/data must never
        // have been rendered into the response body at all.
        $response->assertDontSee('admin-root', false);
        $response->assertDontSee($employee->full_name);
    }

    public function test_guest_is_rejected_before_any_page_data_is_sent(): void
    {
        $response = $this->get('/dashboard/pengaturan-pengguna');

        // A redirect to the login page, not the settings page itself — the
        // 302 response carries no body, so no page markup/data is sent.
        $response->assertRedirect(route('dashboard.login'));
    }
}
