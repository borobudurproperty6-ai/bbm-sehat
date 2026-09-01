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
        Schema::create('device_tokens', function (Blueprint $table) {
            $table->id();
            // This app's auth model is Employee (see config/auth.php's
            // "employees" provider) — there is no users table, so the FK
            // points at employees instead.
            $table->foreignId('employee_id')->constrained('employees')->cascadeOnDelete();
            $table->text('fcm_token');
            $table->timestamps();

            // One stored token per employee — registering again just
            // updates it (see DeviceTokenController::register).
            $table->unique('employee_id');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('device_tokens');
    }
};
