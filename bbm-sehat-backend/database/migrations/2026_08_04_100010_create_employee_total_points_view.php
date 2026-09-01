<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::statement('
            CREATE VIEW employee_total_points AS
            SELECT employee_id, SUM(points_awarded) AS total_points
            FROM point_transactions
            GROUP BY employee_id
        ');
    }

    public function down(): void
    {
        DB::statement('DROP VIEW IF EXISTS employee_total_points');
    }
};
