<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        $this->call([
            DivisionSeeder::class,
            RoleSeeder::class,
            PointRuleSeeder::class,
            BadgeTypeSeeder::class,
            EmployeeSeeder::class,
            StepTargetSeeder::class,
        ]);
    }
}
