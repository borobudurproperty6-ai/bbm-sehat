<?php

namespace Database\Seeders;

use App\Models\Role;
use Illuminate\Database\Seeder;

class RoleSeeder extends Seeder
{
    public function run(): void
    {
        $roles = [
            ['code' => 'EMPLOYEE', 'name' => 'Karyawan'],
            ['code' => 'DIVISION_ADMIN', 'name' => 'Admin Divisi'],
            ['code' => 'MANAGEMENT', 'name' => 'Manajemen (Direktur/Komisaris)'],
            ['code' => 'SUPER_ADMIN', 'name' => 'Super Admin IT'],
            ['code' => 'ADMIN_UMUM_SDM', 'name' => 'Admin Umum & SDM'],
        ];

        foreach ($roles as $role) {
            Role::updateOrCreate(['code' => $role['code']], $role);
        }
    }
}
