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
        Schema::table('employees', function (Blueprint $table) {
            // Relative path within the "public" disk (e.g.
            // "profile-photos/8_1723999999.jpg") — never a full URL, so it
            // stays correct regardless of APP_URL/host. Resolved to an
            // actual URL by EmployeeResource.
            $table->string('photo_path')->nullable()->after('phone');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('employees', function (Blueprint $table) {
            $table->dropColumn('photo_path');
        });
    }
};
