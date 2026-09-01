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
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

/**
 * account_status (active/inactive/archived) replaced the old ambiguous
 * is_active boolean — this suite covers the login gate per status, the new
 * SUPER_ADMIN/ADMIN_UMUM_SDM-only status-change endpoint, its audit trail,
 * and that the older deactivate() action still works and is now audited too.
 */
class AccountStatusTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(DivisionSeeder::class);
        $this->seed(RoleSeeder::class);
    }

    private function employeeWithRole(string $roleCode, AccountStatus $status = AccountStatus::Active): Employee
    {
        $role = Role::where('code', $roleCode)->firstOrFail();
        $division = Division::query()->firstOrFail();

        return Employee::create([
            'employee_code' => 'TEST-'.$roleCode.'-'.uniqid(),
            'full_name' => "Test $roleCode",
            'email' => strtolower($roleCode).'-'.uniqid().'@test.local',
            'division_id' => $division->id,
            'role_id' => $role->id,
            'account_status' => $status,
            'password' => 'correct-password',
            'must_change_password' => false,
        ]);
    }

    // ── Login gate per account_status ──────────────────────────────────────

    public function test_active_account_can_log_in(): void
    {
        $employee = $this->employeeWithRole('EMPLOYEE', AccountStatus::Active);

        $this->postJson('/api/login', [
            'employee_code' => $employee->employee_code,
            'password' => 'correct-password',
        ])->assertOk();
    }

    #[DataProvider('blockedStatuses')]
    public function test_non_active_account_cannot_log_in_and_gets_a_clear_message(AccountStatus $status): void
    {
        $employee = $this->employeeWithRole('EMPLOYEE', $status);

        $response = $this->postJson('/api/login', [
            'employee_code' => $employee->employee_code,
            'password' => 'correct-password',
        ])->assertStatus(403);

        // Must not be the generic "wrong credentials" message — the
        // password was correct, only the account status blocked login.
        $this->assertNotSame('ID Karyawan atau kata sandi salah.', $response->json('message'));
        $this->assertNotEmpty($response->json('message'));
    }

    public static function blockedStatuses(): array
    {
        return [
            'inactive' => [AccountStatus::Inactive],
            'archived' => [AccountStatus::Archived],
        ];
    }

    public function test_archived_and_inactive_get_distinct_messages(): void
    {
        $inactive = $this->employeeWithRole('EMPLOYEE', AccountStatus::Inactive);
        $archived = $this->employeeWithRole('EMPLOYEE', AccountStatus::Archived);

        $inactiveMessage = $this->postJson('/api/login', [
            'employee_code' => $inactive->employee_code,
            'password' => 'correct-password',
        ])->assertStatus(403)->json('message');

        $archivedMessage = $this->postJson('/api/login', [
            'employee_code' => $archived->employee_code,
            'password' => 'correct-password',
        ])->assertStatus(403)->json('message');

        $this->assertNotSame($inactiveMessage, $archivedMessage);
    }

    // ── PATCH /admin/employees/{employee}/account-status ──────────────────

    public function test_super_admin_can_change_account_status(): void
    {
        $admin = $this->employeeWithRole('SUPER_ADMIN');
        $target = $this->employeeWithRole('EMPLOYEE');

        $response = $this->actingAs($admin, 'sanctum')
            ->patchJson("/api/admin/employees/{$target->id}/account-status", ['account_status' => 'archived'])
            ->assertOk();

        $response->assertJsonPath('data.account_status', 'archived');
        $this->assertSame(AccountStatus::Archived, $target->fresh()->account_status);
    }

    public function test_admin_umum_sdm_can_change_account_status(): void
    {
        $admin = $this->employeeWithRole('ADMIN_UMUM_SDM');
        $target = $this->employeeWithRole('EMPLOYEE');

        $this->actingAs($admin, 'sanctum')
            ->patchJson("/api/admin/employees/{$target->id}/account-status", ['account_status' => 'inactive'])
            ->assertOk();

        $this->assertSame(AccountStatus::Inactive, $target->fresh()->account_status);
    }

    #[DataProvider('rolesWithoutAccountStatusAccess')]
    public function test_other_roles_cannot_change_account_status(string $roleCode): void
    {
        $actor = $this->employeeWithRole($roleCode);
        $target = $this->employeeWithRole('EMPLOYEE');

        $this->actingAs($actor, 'sanctum')
            ->patchJson("/api/admin/employees/{$target->id}/account-status", ['account_status' => 'archived'])
            ->assertForbidden();

        $this->assertSame(AccountStatus::Active, $target->fresh()->account_status);
    }

    public static function rolesWithoutAccountStatusAccess(): array
    {
        return [['EMPLOYEE'], ['DIVISION_ADMIN'], ['MANAGEMENT']];
    }

    public function test_rejects_invalid_account_status_value(): void
    {
        $admin = $this->employeeWithRole('SUPER_ADMIN');
        $target = $this->employeeWithRole('EMPLOYEE');

        $this->actingAs($admin, 'sanctum')
            ->patchJson("/api/admin/employees/{$target->id}/account-status", ['account_status' => 'banned'])
            ->assertStatus(422);
    }

    public function test_account_status_change_writes_audit_log(): void
    {
        $admin = $this->employeeWithRole('SUPER_ADMIN');
        $target = $this->employeeWithRole('EMPLOYEE');

        $this->actingAs($admin, 'sanctum')
            ->patchJson("/api/admin/employees/{$target->id}/account-status", ['account_status' => 'archived'])
            ->assertOk();

        $this->assertDatabaseHas('audit_logs', [
            'action' => AuditLog::ACTION_ACCOUNT_STATUS_CHANGED,
            'actor_employee_id' => $admin->id,
            'target_employee_id' => $target->id,
        ]);

        $log = AuditLog::where('action', AuditLog::ACTION_ACCOUNT_STATUS_CHANGED)->firstOrFail();
        $this->assertSame(['old_status' => 'active', 'new_status' => 'archived'], $log->details);
    }

    public function test_setting_the_same_status_does_not_write_a_duplicate_audit_log(): void
    {
        $admin = $this->employeeWithRole('SUPER_ADMIN');
        $target = $this->employeeWithRole('EMPLOYEE');

        $this->actingAs($admin, 'sanctum')
            ->patchJson("/api/admin/employees/{$target->id}/account-status", ['account_status' => 'active'])
            ->assertOk();

        $this->assertDatabaseMissing('audit_logs', ['action' => AuditLog::ACTION_ACCOUNT_STATUS_CHANGED]);
    }

    // ── Existing deactivate() endpoint still works, now on account_status ─

    public function test_deactivate_endpoint_sets_account_status_inactive_and_logs_it(): void
    {
        $admin = $this->employeeWithRole('SUPER_ADMIN');
        $target = $this->employeeWithRole('EMPLOYEE');

        $this->actingAs($admin, 'sanctum')
            ->patchJson("/api/admin/employees/{$target->id}/deactivate")
            ->assertOk();

        $this->assertSame(AccountStatus::Inactive, $target->fresh()->account_status);
        $this->assertDatabaseHas('audit_logs', [
            'action' => AuditLog::ACTION_ACCOUNT_STATUS_CHANGED,
            'actor_employee_id' => $admin->id,
            'target_employee_id' => $target->id,
        ]);
    }

    // ── Self-lockout guard — an admin can't take themselves out of active ─

    #[DataProvider('nonActiveStatuses')]
    public function test_super_admin_cannot_set_their_own_account_status_to_non_active(string $status): void
    {
        $admin = $this->employeeWithRole('SUPER_ADMIN');

        $response = $this->actingAs($admin, 'sanctum')
            ->patchJson("/api/admin/employees/{$admin->id}/account-status", ['account_status' => $status])
            ->assertStatus(422);

        $this->assertNotEmpty($response->json('message'));
        $this->assertSame(AccountStatus::Active, $admin->fresh()->account_status);
        $this->assertDatabaseMissing('audit_logs', ['action' => AuditLog::ACTION_ACCOUNT_STATUS_CHANGED]);
    }

    public static function nonActiveStatuses(): array
    {
        return ['inactive' => ['inactive'], 'archived' => ['archived']];
    }

    public function test_super_admin_setting_their_own_status_to_active_is_still_allowed(): void
    {
        // Not a self-lockout — re-affirming 'active' (a no-op here) must not
        // be swept up by the self-block, which only guards against leaving
        // 'active'.
        $admin = $this->employeeWithRole('SUPER_ADMIN');

        $this->actingAs($admin, 'sanctum')
            ->patchJson("/api/admin/employees/{$admin->id}/account-status", ['account_status' => 'active'])
            ->assertOk();
    }

    public function test_deactivate_endpoint_blocks_self_deactivation(): void
    {
        $admin = $this->employeeWithRole('SUPER_ADMIN');

        $this->actingAs($admin, 'sanctum')
            ->patchJson("/api/admin/employees/{$admin->id}/deactivate")
            ->assertStatus(422);

        $this->assertSame(AccountStatus::Active, $admin->fresh()->account_status);
    }

    // ── /api/monitoring/tidak-aktif must not be touched by this rename ────

    public function test_monitoring_tidak_aktif_endpoint_still_works_unchanged(): void
    {
        $admin = $this->employeeWithRole('SUPER_ADMIN');
        $this->employeeWithRole('EMPLOYEE'); // no activity logged -> should show up

        $this->actingAs($admin, 'sanctum')
            ->getJson('/api/monitoring/tidak-aktif')
            ->assertOk();
    }
}
