<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('employee_devices', function (Blueprint $table) {
            $table->id();
            $table->foreignId('employee_id')->constrained('employees')->cascadeOnDelete();
            $table->enum('platform', ['android', 'ios']);
            $table->string('health_source', 30);
            $table->boolean('permission_granted')->default(false);
            $table->timestamp('last_synced_at')->nullable();
            $table->json('device_info')->nullable();
            $table->timestamp('created_at')->nullable()->useCurrent();

            $table->index('employee_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('employee_devices');
    }
};
