<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * `is_active` was ambiguous — it's the account/login-access flag, but reads
 * exactly like the unrelated "activity status" concept (has this employee
 * been exercising lately, see MonitoringController's tidak-aktif endpoint).
 * Replaces it with a proper account_status enum (active/inactive/archived)
 * so the two concepts can never be confused again, and adds `archived` as a
 * real status for resigned employees — history kept, login blocked.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('employees', function (Blueprint $table) {
            $table->enum('account_status', ['active', 'inactive', 'archived'])->default('active');
        });

        DB::table('employees')->where('is_active', true)->update(['account_status' => 'active']);
        DB::table('employees')->where('is_active', false)->update(['account_status' => 'inactive']);

        Schema::table('employees', function (Blueprint $table) {
            $table->dropIndex(['is_active']);
            $table->dropColumn('is_active');
            $table->index('account_status');
        });
    }

    public function down(): void
    {
        Schema::table('employees', function (Blueprint $table) {
            $table->boolean('is_active')->default(true);
        });

        DB::table('employees')->where('account_status', 'active')->update(['is_active' => true]);
        DB::table('employees')->whereIn('account_status', ['inactive', 'archived'])->update(['is_active' => false]);

        Schema::table('employees', function (Blueprint $table) {
            $table->dropIndex(['account_status']);
            $table->dropColumn('account_status');
            $table->index('is_active');
        });
    }
};
