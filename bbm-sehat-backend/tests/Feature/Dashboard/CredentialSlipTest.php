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
 * POST /api/admin/user-settings/employees/{employee}/credential-slip
 * (CredentialSlipController) — generates the same PDF slip
 * TemporaryPasswordModal's "Cetak Slip" button downloads. It sits in the
 * SAME whitelisted-SUPER_ADMIN route group as every other "Pengaturan
 * Pengguna" endpoint, so this mirrors UserSettingsApiAccessTest's access
 * matrix rather than inventing a new one.
 */
class CredentialSlipTest extends TestCase
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

    /** Decompresses a PDF's content stream(s) so plain text assertions can run against it. */
    private function extractPdfText(string $binary): string
    {
        preg_match_all('/stream\r?\n(.*?)\r?\nendstream/s', $binary, $matches);

        $text = '';
        foreach ($matches[1] as $stream) {
            $decoded = @zlib_decode($stream);
            if ($decoded !== false) {
                $text .= $decoded;
            }
        }

        return $text;
    }

    public function test_whitelisted_super_admin_can_generate_the_slip(): void
    {
        $admin = $this->employeeWithRole('SUPER_ADMIN', 'BBM-005');
        $target = $this->employeeWithRole('EMPLOYEE');

        $response = $this->actingAs($admin, 'sanctum')
            ->postJson("/api/admin/user-settings/employees/{$target->id}/credential-slip", [
                'password' => 'Sehat4271',
            ])
            ->assertOk();

        $response->assertHeader('content-type', 'application/pdf');
        $this->assertStringContainsString('attachment', $response->headers->get('content-disposition'));
    }

    public function test_slip_contains_the_correct_employee_details_and_password(): void
    {
        $admin = $this->employeeWithRole('SUPER_ADMIN', 'BBM-006');
        $target = $this->employeeWithRole('EMPLOYEE', 'BBM-0123');
        $target->update(['full_name' => 'Karyawan Uji Slip']);

        $response = $this->actingAs($admin, 'sanctum')
            ->postJson("/api/admin/user-settings/employees/{$target->id}/credential-slip", [
                'password' => 'Bento8834',
            ])
            ->assertOk();

        $text = $this->extractPdfText($response->getContent());

        $this->assertStringContainsString('PT BBM', $text);
        $this->assertStringContainsString('Karyawan Uji Slip', $text);
        $this->assertStringContainsString('BBM-0123', $text);
        $this->assertStringContainsString('Bento8834', $text);
        $this->assertStringContainsString('password baru', $text);
    }

    public function test_missing_password_is_rejected(): void
    {
        $admin = $this->employeeWithRole('SUPER_ADMIN', 'BBM-005');
        $target = $this->employeeWithRole('EMPLOYEE');

        $this->actingAs($admin, 'sanctum')
            ->postJson("/api/admin/user-settings/employees/{$target->id}/credential-slip", [])
            ->assertStatus(422);
    }

    public function test_super_admin_role_but_not_whitelisted_employee_code_gets_403(): void
    {
        $admin = $this->employeeWithRole('SUPER_ADMIN', 'BBM-0001');
        $target = $this->employeeWithRole('EMPLOYEE');

        $this->actingAs($admin, 'sanctum')
            ->postJson("/api/admin/user-settings/employees/{$target->id}/credential-slip", [
                'password' => 'Sehat4271',
            ])
            ->assertForbidden();
    }

    public static function nonSuperAdminRoles(): array
    {
        return [['EMPLOYEE'], ['DIVISION_ADMIN'], ['MANAGEMENT'], ['ADMIN_UMUM_SDM']];
    }

    #[DataProvider('nonSuperAdminRoles')]
    public function test_non_super_admin_role_gets_403(string $roleCode): void
    {
        $actor = $this->employeeWithRole($roleCode);
        $target = $this->employeeWithRole('EMPLOYEE');

        $this->actingAs($actor, 'sanctum')
            ->postJson("/api/admin/user-settings/employees/{$target->id}/credential-slip", [
                'password' => 'Sehat4271',
            ])
            ->assertForbidden();
    }

    public function test_unauthenticated_request_gets_401(): void
    {
        $target = $this->employeeWithRole('EMPLOYEE');

        $this->postJson("/api/admin/user-settings/employees/{$target->id}/credential-slip", [
            'password' => 'Sehat4271',
        ])->assertUnauthorized();
    }
}
