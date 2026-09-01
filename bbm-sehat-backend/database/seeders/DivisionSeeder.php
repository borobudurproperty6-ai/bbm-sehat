<?php

namespace Database\Seeders;

use App\Models\Division;
use Illuminate\Database\Seeder;

class DivisionSeeder extends Seeder
{
    public function run(): void
    {
        $divisions = [
            ['code' => 'DIREKTUR', 'name' => 'Direktur'],
            ['code' => 'KOMISARIS', 'name' => 'Komisaris'],
            ['code' => 'SDM', 'name' => 'Admin / SDM'],
            ['code' => 'IT', 'name' => 'IT'],
            ['code' => 'MARKETING', 'name' => 'Marketing'],
            ['code' => 'PERIZINAN', 'name' => 'Perizinan'],
            ['code' => 'KONSTRUKSI', 'name' => 'Konstruksi (staf kantor)'],
            ['code' => 'UD_AMANAH', 'name' => 'UD Amanah (Batu Alam)'],
            ['code' => 'KEMBANG', 'name' => 'Toko Kembang'],
            ['code' => 'BAKSO_BENTO', 'name' => 'Bakso Bento Malang'],
        ];

        foreach ($divisions as $division) {
            Division::updateOrCreate(['code' => $division['code']], $division);
        }
    }
}
