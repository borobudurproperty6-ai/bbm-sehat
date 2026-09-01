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
 * Mobile login (POST /api/login) now accepts only the employee's User ID
 * (employees.employee_code) as the identifier — email is no longer a valid
 * login credential, since every employee's email is currently a placeholder
 * (@bbm-sehat.local), not a real address. Email stays in the database as
 * optional contact info; forgot-password/reset-password (unrelated to this
 * migration) still use it.
 */
class LoginIdentifierTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(DivisionSeeder::class);
        $this->seed(RoleSeeder::class);
    }

    private function employee(): Employee
    {
        $role = Role::where('code', 'EMPLOYEE')->firstOrFail();
        $division = Division::query()->firstOrFail();

        return Employee::create([
            'employee_code' => 'BBM-'.random_int(1000, 9999),
            'full_name' => 'Test Employee',
            'email' => 't'.random_int(1000, 9999).'@bbm.local',
            'division_id' => $division->id,
            'role_id' => $role->id,
            'account_status' => AccountStatus::Active,
            'password' => 'correct-password',
            'must_change_password' => false,
        ]);
    }

    public function test_login_with_employee_code_succeeds(): void
    {
        $employee = $this->employee();

        $response = $this->postJson('/api/login', [
            'employee_code' => $employee->employee_code,
            'password' => 'correct-password',
        ])->assertOk();

        $this->assertNotEmpty($response->json('token'));
    }

    public function test_login_with_employee_code_is_case_insensitive(): void
    {
        $employee = $this->employee();

        $this->postJson('/api/login', [
            'employee_code' => strtolower($employee->employee_code),
            'password' => 'correct-password',
        ])->assertOk();
    }

    public function test_login_with_email_is_rejected_even_with_correct_password(): void
    {
        $employee = $this->employee();

        $response = $this->postJson('/api/login', [
            'employee_code' => $employee->email,
            'password' => 'correct-password',
        ])->assertStatus(401);

        $this->assertSame('ID Karyawan atau kata sandi salah.', $response->json('message'));
    }

    public function test_missing_employee_code_field_fails_validation(): void
    {
        $this->postJson('/api/login', ['password' => 'whatever'])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['employee_code']);
    }

    public function test_old_employee_code_or_email_field_name_is_no_longer_recognized(): void
    {
        $employee = $this->employee();

        // Sending the old field name means 'employee_code' is simply absent
        // from the request -> validation failure, not a successful login.
        $this->postJson('/api/login', [
            'employee_code_or_email' => $employee->employee_code,
            'password' => 'correct-password',
        ])->assertStatus(422);
    }

    public function test_successful_login_is_audited_with_employee_code_as_identifier(): void
    {
        $employee = $this->employee();

        $this->postJson('/api/login', [
            'employee_code' => $employee->employee_code,
            'password' => 'correct-password',
        ])->assertOk();

        $log = AuditLog::where('action', AuditLog::ACTION_LOGIN_SUCCESS)->firstOrFail();
        $this->assertSame($employee->id, $log->actor_employee_id);
        $this->assertSame($employee->id, $log->target_employee_id);
    }

    public function test_failed_login_is_audited_with_employee_code_as_identifier(): void
    {
        $employee = $this->employee();

        $this->postJson('/api/login', [
            'employee_code' => $employee->employee_code,
            'password' => 'wrong-password',
        ])->assertStatus(401);

        $log = AuditLog::where('action', AuditLog::ACTION_LOGIN_FAILED)->firstOrFail();
        $this->assertSame($employee->employee_code, $log->details['identifier']);
        $this->assertSame($employee->id, $log->target_employee_id);
    }
}
