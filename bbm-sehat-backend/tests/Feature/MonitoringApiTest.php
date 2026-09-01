<?php

namespace Tests\Feature;

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
 * The three /api/monitoring/* endpoints are company-wide aggregates meant
 * for management/admin roles only — this suite's real point is proving the
 * role gate actually holds (management, super_admin, admin_umum_sdm in;
 * everyone else, including division_admin, out), not the aggregate math
 * itself (that's exercised via curl against real data per the task).
 */
class MonitoringApiTest extends TestCase
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
            'is_management' => false,
            'account_status' => AccountStatus::Active,
            'password' => 'irrelevant-for-this-test',
            'must_change_password' => false,
        ]);
    }

    public static function allowedRoles(): array
    {
        return [['MANAGEMENT'], ['SUPER_ADMIN'], ['ADMIN_UMUM_SDM']];
    }

    public static function deniedRoles(): array
    {
        return [['EMPLOYEE'], ['DIVISION_ADMIN']];
    }

    public static function monitoringEndpoints(): array
    {
        return [
            ['/api/monitoring/overview'],
            ['/api/monitoring/per-divisi'],
            ['/api/monitoring/tidak-aktif'],
            ['/api/monitoring/employees'],
        ];
    }

    #[DataProvider('allowedRoles')]
    public function test_allowed_role_can_access_every_monitoring_endpoint(string $roleCode): void
    {
        $employee = $this->employeeWithRole($roleCode);

        foreach (self::monitoringEndpoints() as [$uri]) {
            $this->actingAs($employee, 'sanctum')
                ->getJson($uri)
                ->assertOk();
        }
    }

    #[DataProvider('deniedRoles')]
    public function test_denied_role_gets_403_from_every_monitoring_endpoint(string $roleCode): void
    {
        $employee = $this->employeeWithRole($roleCode);

        foreach (self::monitoringEndpoints() as [$uri]) {
            $this->actingAs($employee, 'sanctum')
                ->getJson($uri)
                ->assertForbidden();
        }
    }

    public function test_unauthenticated_request_gets_401_not_403(): void
    {
        $this->getJson('/api/monitoring/overview')->assertUnauthorized();
    }

    public function test_tidak_aktif_rejects_out_of_range_days(): void
    {
        $employee = $this->employeeWithRole('SUPER_ADMIN');

        $this->actingAs($employee, 'sanctum')
            ->getJson('/api/monitoring/tidak-aktif?days=0')
            ->assertStatus(422);

        $this->actingAs($employee, 'sanctum')
            ->getJson('/api/monitoring/tidak-aktif?days=366')
            ->assertStatus(422);
    }

    public function test_employees_list_supports_search_sort_and_filter(): void
    {
        $admin = $this->employeeWithRole('SUPER_ADMIN');
        $division = Division::query()->firstOrFail();
        $role = Role::where('code', 'EMPLOYEE')->firstOrFail();

        Employee::create([
            'employee_code' => 'TEST-ZZZ-'.uniqid(),
            'full_name' => 'Zzz Findable Name',
            'email' => 'zzz-'.uniqid().'@test.local',
            'division_id' => $division->id,
            'role_id' => $role->id,
            'account_status' => AccountStatus::Active,
            'password' => 'irrelevant',
            'must_change_password' => false,
        ]);

        $response = $this->actingAs($admin, 'sanctum')
            ->getJson('/api/monitoring/employees?search=Zzz+Findable&sort_by=nama&per_page=5')
            ->assertOk();

        $names = collect($response->json('data'))->pluck('full_name');
        $this->assertTrue($names->contains('Zzz Findable Name'));
        $this->assertArrayHasKey('current_page', $response->json('meta'));
    }

    public function test_employees_list_rejects_invalid_sort_by(): void
    {
        $admin = $this->employeeWithRole('SUPER_ADMIN');

        $this->actingAs($admin, 'sanctum')
            ->getJson('/api/monitoring/employees?sort_by=not_a_real_option')
            ->assertStatus(422);
    }

    #[DataProvider('allowedRoles')]
    public function test_allowed_role_can_access_employee_detail(string $roleCode): void
    {
        $admin = $this->employeeWithRole($roleCode);
        $target = $this->employeeWithRole('EMPLOYEE');

        $response = $this->actingAs($admin, 'sanctum')
            ->getJson("/api/monitoring/employees/{$target->id}")
            ->assertOk();

        $response->assertJsonPath('data.employee.id', $target->id);
        $response->assertJsonPath('data.badges', []);
        $this->assertArrayHasKey('weekly_history', $response->json('data'));
        $this->assertArrayHasKey('walk_sessions', $response->json('data'));
        $this->assertArrayHasKey('point_breakdown', $response->json('data'));
    }

    #[DataProvider('deniedRoles')]
    public function test_denied_role_gets_403_from_employee_detail(string $roleCode): void
    {
        $actor = $this->employeeWithRole($roleCode);
        $target = $this->employeeWithRole('EMPLOYEE');

        $this->actingAs($actor, 'sanctum')
            ->getJson("/api/monitoring/employees/{$target->id}")
            ->assertForbidden();
    }
}
