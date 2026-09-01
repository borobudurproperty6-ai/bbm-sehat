<?php

namespace Database\Seeders;

use App\Enums\AccountStatus;
use App\Models\Division;
use App\Models\Employee;
use App\Models\Role;
use Illuminate\Database\Seeder;

/**
 * Bootstraps the very first account. Employees are otherwise provisioned by
 * an admin through the API, but that API itself needs an admin to call it —
 * this seeds the one super admin needed to break that chicken-and-egg
 * problem. must_change_password stays true, so this password only ever
 * works for the very first login.
 */
class EmployeeSeeder extends Seeder
{
    public function run(): void
    {
        $itDivision = Division::where('code', 'IT')->first();
        $superAdminRole = Role::where('code', 'SUPER_ADMIN')->first();

        Employee::updateOrCreate(
            ['email' => 'superadmin@bbm-sehat.local'],
            [
                'employee_code' => 'BBM-0001',
                'full_name' => 'Super Admin',
                'division_id' => $itDivision?->id,
                'role_id' => $superAdminRole?->id,
                'is_management' => false,
                'account_status' => AccountStatus::Active,
                'password' => 'ChangeMe123!',
                'must_change_password' => true,
            ]
        );
    }
}
