<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('employees', function (Blueprint $table) {
            // Structural job title (Manager/Supervisor/Staff/Direktur/...) —
            // display label only, does not affect access control (that's
            // still role_id).
            $table->string('position_title', 50)->nullable()->after('metadata');
        });
    }

    public function down(): void
    {
        Schema::table('employees', function (Blueprint $table) {
            $table->dropColumn('position_title');
        });
    }
};
