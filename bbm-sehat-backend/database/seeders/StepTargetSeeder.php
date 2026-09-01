<?php

namespace Database\Seeders;

use App\Models\StepTarget;
use Illuminate\Database\Seeder;

class StepTargetSeeder extends Seeder
{
    public function run(): void
    {
        StepTarget::updateOrCreate(
            ['scope_type' => 'global', 'scope_id' => null],
            [
                'target_steps' => 8000,
                'effective_from' => now()->subYear()->toDateString(),
                'effective_to' => null,
            ]
        );
    }
}
