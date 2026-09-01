<?php

namespace Database\Seeders;

use App\Models\PointRule;
use Illuminate\Database\Seeder;

class PointRuleSeeder extends Seeder
{
    public function run(): void
    {
        $rules = [
            [
                'code' => 'DAILY_TARGET_MET',
                'name' => 'Mencapai target langkah harian',
                'points' => 10,
                'rule_type' => 'daily_target',
                'config' => [],
            ],
            [
                'code' => 'WEEKLY_STREAK_5',
                'name' => 'Beruntun 5 hari kerja capai target',
                'points' => 20,
                'rule_type' => 'streak',
                'config' => ['streak_days' => 5],
            ],
            [
                'code' => 'WALK_SESSION_LOGGED',
                'name' => 'Menyelesaikan sesi jalan kaki dengan rute',
                'points' => 5,
                'rule_type' => 'walk_distance',
                'config' => ['min_distance_meters' => 500],
            ],
        ];

        foreach ($rules as $rule) {
            PointRule::updateOrCreate(['code' => $rule['code']], $rule);
        }
    }
}
