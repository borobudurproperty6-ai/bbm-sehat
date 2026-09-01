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
 * POST /api/admin/login (dashboard SPA session login) gates by role before
 * establishing a session — ADMIN_UMUM_SDM was added to this allow-list
 * alongside the Monitoring pages so that role can actually reach them (it
 * previously couldn't log into the dashboard at all, independent of the
 * /api/monitoring/* role: middleware already allowing it). EMPLOYEE stays
 * rejected here — it's not a monitoring viewer and was never in this list.
 */
class AdminLoginRoleAccessTest extends TestCase
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
            'password' => 'correct-password',
            'must_change_password' => false,
        ]);
    }

    public static function allowedRoles(): array
    {
        return [['DIVISION_ADMIN'], ['MANAGEMENT'], ['SUPER_ADMIN'], ['ADMIN_UMUM_SDM']];
    }

    /**
     * AuthController::login() calls $request->session()->regenerate(),
     * which only exists on requests Sanctum's statefulApi() middleware
     * recognizes as coming from a stateful (SPA) domain — determined by
     * Origin/Referer, not by any header postJson() sets by default. A
     * Referer matching config('sanctum.stateful') is required here for the
     * same reason the real dashboard SPA's browser-set Origin makes this
     * work in production.
     */
    private function postAdminLogin(array $payload): \Illuminate\Testing\TestResponse
    {
        return $this->withHeader('Referer', 'http://localhost')->postJson('/api/admin/login', $payload);
    }

    #[DataProvider('allowedRoles')]
    public function test_allowed_role_can_log_into_the_dashboard(string $roleCode): void
    {
        $employee = $this->employeeWithRole($roleCode);

        $this->postAdminLogin([
            'email' => $employee->email,
            'password' => 'correct-password',
        ])->assertOk();
    }

    public function test_employee_role_is_rejected(): void
    {
        $employee = $this->employeeWithRole('EMPLOYEE');

        $this->postAdminLogin([
            'email' => $employee->email,
            'password' => 'correct-password',
        ])->assertForbidden();
    }
}
