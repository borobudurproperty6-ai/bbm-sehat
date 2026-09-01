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
        // The old (employee_id, point_rule_id, reference_date) constraint
        // assumed a rule fires at most once per day — true for
        // DAILY_TARGET_MET/WEEKLY_STREAK_5, but wrong for
        // WALK_SESSION_LOGGED: two separate walks on the same day must each
        // earn their own points. Widening it to include reference_id fixes
        // that (each session has a distinct reference_id, so they no longer
        // collide) while PointService::awardOnce()'s own .exists() check
        // remains the primary duplicate guard for the date-only rules —
        // MySQL treats NULL != NULL in unique indexes, so their
        // always-NULL reference_id no longer gets a DB-level backstop, but
        // there's no realistic concurrent-request path that needs one here.
        Schema::table('point_transactions', function (Blueprint $table) {
            $table->dropUnique('uq_employee_rule_date');
            $table->unique(
                ['employee_id', 'point_rule_id', 'reference_date', 'reference_id'],
                'uq_employee_rule_date_reference'
            );
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('point_transactions', function (Blueprint $table) {
            $table->dropUnique('uq_employee_rule_date_reference');
            $table->unique(['employee_id', 'point_rule_id', 'reference_date'], 'uq_employee_rule_date');
        });
    }
};
