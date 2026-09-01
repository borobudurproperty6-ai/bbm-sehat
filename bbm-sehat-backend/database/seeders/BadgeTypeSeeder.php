<?php

namespace Database\Seeders;

use App\Models\BadgeType;
use Illuminate\Database\Seeder;

class BadgeTypeSeeder extends Seeder
{
    public function run(): void
    {
        $badges = [
            [
                'code' => 'DIVISION_CHAMPION_WEEKLY',
                'name' => 'Juara Divisi Minggu Ini',
                'description' => 'Peringkat 1-3 leaderboard mingguan divisi',
                'criteria' => ['rank_max' => 3, 'period' => 'weekly', 'scope' => 'division'],
            ],
            [
                'code' => 'COMPANY_TOP_MONTHLY',
                'name' => 'Karyawan Teraktif Bulan Ini',
                'description' => 'Peringkat 1-3 leaderboard bulanan perusahaan',
                'criteria' => ['rank_max' => 3, 'period' => 'monthly', 'scope' => 'company'],
            ],
        ];

        foreach ($badges as $badge) {
            BadgeType::updateOrCreate(['code' => $badge['code']], $badge);
        }
    }
}
