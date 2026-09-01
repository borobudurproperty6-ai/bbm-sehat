<?php

namespace Tests\Feature;

use App\Enums\AccountStatus;
use App\Models\Division;
use App\Models\Employee;
use App\Models\Role;
use Database\Seeders\DivisionSeeder;
use Database\Seeders\RoleSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class ProfilePhotoApiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(DivisionSeeder::class);
        $this->seed(RoleSeeder::class);
        Storage::fake('public');
    }

    private function employee(): Employee
    {
        $role = Role::where('code', 'EMPLOYEE')->firstOrFail();
        $division = Division::query()->firstOrFail();

        return Employee::create([
            'employee_code' => 'TEST-'.uniqid(),
            'full_name' => 'Test Employee',
            'email' => 'test-'.uniqid().'@test.local',
            'division_id' => $division->id,
            'role_id' => $role->id,
            'account_status' => AccountStatus::Active,
            'password' => 'irrelevant',
            'must_change_password' => false,
        ]);
    }

    public function test_authenticated_user_can_upload_profile_photo(): void
    {
        $employee = $this->employee();
        $photo = UploadedFile::fake()->image('avatar.jpg', 300, 300)->size(500);

        $response = $this->actingAs($employee, 'sanctum')
            ->postJson('/api/profile/photo', ['photo' => $photo])
            ->assertOk();

        $photoUrl = $response->json('data.photo_url');
        $this->assertNotNull($photoUrl);
        $this->assertStringContainsString('profile-photos/', $photoUrl);

        $employee->refresh();
        $this->assertNotNull($employee->photo_path);
        Storage::disk('public')->assertExists($employee->photo_path);
    }

    public function test_unauthenticated_request_gets_401(): void
    {
        $photo = UploadedFile::fake()->image('avatar.jpg');

        $this->postJson('/api/profile/photo', ['photo' => $photo])->assertUnauthorized();
    }

    public function test_rejects_non_image_file(): void
    {
        $employee = $this->employee();
        $file = UploadedFile::fake()->create('document.pdf', 100, 'application/pdf');

        $this->actingAs($employee, 'sanctum')
            ->postJson('/api/profile/photo', ['photo' => $file])
            ->assertStatus(422);
    }

    public function test_rejects_oversized_photo(): void
    {
        $employee = $this->employee();
        $photo = UploadedFile::fake()->image('avatar.jpg')->size(3000); // >2MB

        $this->actingAs($employee, 'sanctum')
            ->postJson('/api/profile/photo', ['photo' => $photo])
            ->assertStatus(422);
    }

    public function test_replacing_photo_deletes_the_old_file(): void
    {
        $employee = $this->employee();

        $first = UploadedFile::fake()->image('first.jpg');
        $this->actingAs($employee, 'sanctum')->postJson('/api/profile/photo', ['photo' => $first])->assertOk();
        $employee->refresh();
        $firstPath = $employee->photo_path;
        Storage::disk('public')->assertExists($firstPath);

        $second = UploadedFile::fake()->image('second.jpg');
        $this->actingAs($employee, 'sanctum')->postJson('/api/profile/photo', ['photo' => $second])->assertOk();
        $employee->refresh();

        $this->assertNotSame($firstPath, $employee->photo_path);
        Storage::disk('public')->assertMissing($firstPath);
        Storage::disk('public')->assertExists($employee->photo_path);
    }

    public function test_me_endpoint_reflects_photo_url_after_upload(): void
    {
        $employee = $this->employee();
        $photo = UploadedFile::fake()->image('avatar.jpg');

        $this->actingAs($employee, 'sanctum')
            ->postJson('/api/profile/photo', ['photo' => $photo])
            ->assertOk();

        $me = $this->actingAs($employee, 'sanctum')->getJson('/api/me')->assertOk();

        $this->assertStringContainsString('profile-photos/', $me->json('data.photo_url'));
    }
}
