<?php

namespace Tests\Feature;

use App\Enums\AccountStatus;
use App\Models\Division;
use App\Models\Employee;
use App\Models\Role;
use App\Support\PasswordWords;
use App\Support\TemporaryPasswordGenerator;
use Database\Seeders\DivisionSeeder;
use Database\Seeders\RoleSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Notification;
use Tests\TestCase;

/**
 * Temporary passwords (used only for the "Tambah Pengguna" / "Reset
 * Password" hand-off, always paired with must_change_password=true) moved
 * from Str::password(12) random characters to a "Word+4digits" format
 * (e.g. "Sehat4271") that's easy to read off a printed slip or relay by
 * phone. This covers the generator directly and the two endpoints that use
 * it end-to-end.
 */
class TemporaryPasswordFormatTest extends TestCase
{
    use RefreshDatabase;

    private const FORMAT_PATTERN = '/^[A-Z][a-z]+[2-9]{4}$/';

    protected function setUp(): void
    {
        parent::setUp();
        Notification::fake();
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

    public function test_generator_produces_a_word_followed_by_four_digits(): void
    {
        for ($i = 0; $i < 50; $i++) {
            $password = TemporaryPasswordGenerator::generate();

            $this->assertMatchesRegularExpression(self::FORMAT_PATTERN, $password);
        }
    }

    public function test_generator_never_uses_ambiguous_digits_0_or_1(): void
    {
        for ($i = 0; $i < 50; $i++) {
            $digits = substr(TemporaryPasswordGenerator::generate(), -4);

            $this->assertStringNotContainsString('0', $digits);
            $this->assertStringNotContainsString('1', $digits);
        }
    }

    public function test_generator_only_uses_words_from_the_word_list(): void
    {
        for ($i = 0; $i < 50; $i++) {
            $password = TemporaryPasswordGenerator::generate();
            $word = substr($password, 0, -4);

            $this->assertContains($word, PasswordWords::LIST);
        }
    }

    public function test_employee_creation_returns_a_temporary_password_in_the_new_format(): void
    {
        $admin = $this->employeeWithRole('SUPER_ADMIN');
        $division = Division::query()->firstOrFail();

        $response = $this->actingAs($admin, 'sanctum')
            ->postJson('/api/admin/employees', [
                'full_name' => 'Format Test',
                'email' => 'formattest@test.local',
                'division_id' => $division->id,
            ])
            ->assertCreated();

        $this->assertMatchesRegularExpression(self::FORMAT_PATTERN, $response->json('temporary_password'));
    }

    public function test_password_reset_returns_a_temporary_password_in_the_new_format(): void
    {
        $admin = $this->employeeWithRole('SUPER_ADMIN');
        $target = $this->employeeWithRole('EMPLOYEE');

        $response = $this->actingAs($admin, 'sanctum')
            ->postJson("/api/admin/employees/{$target->id}/reset-password")
            ->assertOk();

        $this->assertMatchesRegularExpression(self::FORMAT_PATTERN, $response->json('temporary_password'));
    }

    /**
     * Self-lockout guard, same rule as update()'s role-change block and
     * updateAccountStatus()'s self-block (AccountStatusTest) — resetting
     * your OWN password silently replaces it with a one-time temporary
     * password shown only in this response, so a missed/misread response
     * locks that admin out with no one else able to undo it from here.
     */
    public function test_password_reset_endpoint_blocks_self_reset(): void
    {
        $admin = $this->employeeWithRole('SUPER_ADMIN');
        $originalHash = $admin->password;

        $response = $this->actingAs($admin, 'sanctum')
            ->postJson("/api/admin/employees/{$admin->id}/reset-password")
            ->assertStatus(422);

        $this->assertNotEmpty($response->json('message'));
        $this->assertSame($originalHash, $admin->fresh()->password);
        $this->assertDatabaseMissing('audit_logs', ['action' => 'PASSWORD_RESET', 'target_employee_id' => $admin->id]);
    }

    /**
     * The new format has a much smaller keyspace than the old
     * Str::password(12) — hashing/verification must still work correctly
     * regardless, since must_change_password=true means this exact string
     * is what the employee logs in with once.
     */
    public function test_generated_password_can_actually_be_used_to_log_in(): void
    {
        $admin = $this->employeeWithRole('SUPER_ADMIN');
        $division = Division::query()->firstOrFail();

        $response = $this->actingAs($admin, 'sanctum')
            ->postJson('/api/admin/employees', [
                'full_name' => 'Login Test',
                'email' => 'logintest@test.local',
                'division_id' => $division->id,
            ])
            ->assertCreated();

        $employeeCode = $response->json('data.employee_code');
        $temporaryPassword = $response->json('temporary_password');

        $this->postJson('/api/login', [
            'employee_code' => $employeeCode,
            'password' => $temporaryPassword,
        ])->assertOk()->assertJsonPath('must_change_password', true);
    }
}
