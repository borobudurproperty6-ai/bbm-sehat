<?php

namespace Tests\Feature;

use App\Enums\AccountStatus;
use App\Models\DeviceToken;
use App\Models\Division;
use App\Models\Employee;
use App\Models\Role;
use App\Services\FirebaseNotificationService;
use Database\Seeders\DivisionSeeder;
use Database\Seeders\RoleSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use PHPUnit\Framework\Attributes\DataProvider;
use RuntimeException;
use Tests\TestCase;

/**
 * FirebaseNotificationService is mocked in every test here — none of these
 * should ever make a real call to Firebase. That service's own send logic
 * isn't what's under test; the role gate, the below-target/has-device
 * filtering, and the per-employee failure isolation are.
 */
class WalkReminderApiTest extends TestCase
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
        return [['SUPER_ADMIN'], ['ADMIN_UMUM_SDM']];
    }

    // Deliberately different from /api/monitoring/*'s allowed set — this
    // endpoint's scope was explicitly limited to SUPER_ADMIN and
    // ADMIN_UMUM_SDM only, so MANAGEMENT is a denied role here.
    public static function deniedRoles(): array
    {
        return [['EMPLOYEE'], ['DIVISION_ADMIN'], ['MANAGEMENT']];
    }

    #[DataProvider('allowedRoles')]
    public function test_allowed_role_can_trigger_reminder(string $roleCode): void
    {
        $this->mock(FirebaseNotificationService::class, function ($mock) {
            $mock->shouldReceive('sendToDevice')->andReturnNull();
        });

        $admin = $this->employeeWithRole($roleCode);

        $this->actingAs($admin, 'sanctum')
            ->postJson('/api/admin/send-walk-reminder')
            ->assertOk()
            ->assertJsonStructure(['data' => ['sent_count', 'skipped_no_device_count', 'failed_count', 'failed']]);
    }

    #[DataProvider('deniedRoles')]
    public function test_denied_role_gets_403(string $roleCode): void
    {
        $actor = $this->employeeWithRole($roleCode);

        $this->actingAs($actor, 'sanctum')
            ->postJson('/api/admin/send-walk-reminder')
            ->assertForbidden();
    }

    public function test_unauthenticated_request_gets_401(): void
    {
        $this->postJson('/api/admin/send-walk-reminder')->assertUnauthorized();
    }

    public function test_sends_only_to_employees_below_target_with_a_device_token(): void
    {
        $admin = $this->employeeWithRole('SUPER_ADMIN'); // no device token, below target — skipped

        $below = $this->employeeWithRole('EMPLOYEE'); // no activity log today == 0 steps, below target
        DeviceToken::create(['employee_id' => $below->id, 'fcm_token' => 'token-below']);

        $reached = $this->employeeWithRole('EMPLOYEE'); // already past the (default) 8000 target
        DeviceToken::create(['employee_id' => $reached->id, 'fcm_token' => 'token-reached']);
        DB::table('daily_activity_logs')->insert([
            'employee_id' => $reached->id,
            'activity_date' => now()->toDateString(),
            'steps' => 9000,
            'source' => 'health_connect',
            'created_at' => now(),
        ]);

        $this->employeeWithRole('EMPLOYEE'); // below target but never registered a device

        $sent = [];
        $this->mock(FirebaseNotificationService::class, function ($mock) use (&$sent) {
            $mock->shouldReceive('sendToDevice')
                ->andReturnUsing(function ($token) use (&$sent) {
                    $sent[] = $token;
                });
        });

        $response = $this->actingAs($admin, 'sanctum')
            ->postJson('/api/admin/send-walk-reminder')
            ->assertOk();

        $this->assertContains('token-below', $sent);
        $this->assertNotContains('token-reached', $sent);
        $this->assertSame(1, $response->json('data.sent_count'));
        // Two employees below target with no device: the no-device EMPLOYEE
        // above, and the SUPER_ADMIN actor itself (also has no token).
        $this->assertSame(2, $response->json('data.skipped_no_device_count'));
    }

    public function test_one_failed_send_does_not_stop_the_rest(): void
    {
        $admin = $this->employeeWithRole('SUPER_ADMIN');

        $first = $this->employeeWithRole('EMPLOYEE');
        DeviceToken::create(['employee_id' => $first->id, 'fcm_token' => 'bad-token']);

        $second = $this->employeeWithRole('EMPLOYEE');
        DeviceToken::create(['employee_id' => $second->id, 'fcm_token' => 'good-token']);

        $this->mock(FirebaseNotificationService::class, function ($mock) {
            $mock->shouldReceive('sendToDevice')
                ->withArgs(fn ($token) => $token === 'bad-token')
                ->andThrow(new RuntimeException('invalid registration token'));
            $mock->shouldReceive('sendToDevice')
                ->withArgs(fn ($token) => $token === 'good-token')
                ->andReturnNull();
        });

        $response = $this->actingAs($admin, 'sanctum')
            ->postJson('/api/admin/send-walk-reminder')
            ->assertOk();

        $this->assertSame(1, $response->json('data.sent_count'));
        $this->assertSame(1, $response->json('data.failed_count'));
        $this->assertSame($first->id, $response->json('data.failed.0.employee_id'));
    }
}
