<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // Backs PointService::awardOnce()'s duplicate check at the DB level
        // too — one (employee, rule, date) can only ever earn a rule's
        // points once, same guarantee daily_activity_logs already has for
        // its own upsert.
        Schema::table('point_transactions', function (Blueprint $table) {
            $table->unique(['employee_id', 'point_rule_id', 'reference_date'], 'uq_employee_rule_date');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('point_transactions', function (Blueprint $table) {
            $table->dropUnique('uq_employee_rule_date');
        });
    }
};
