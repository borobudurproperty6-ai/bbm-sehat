<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('device_sync_logs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('employee_id')->constrained('employees')->cascadeOnDelete();
            $table->string('platform', 20);
            $table->enum('sync_status', ['success', 'failed', 'partial']);
            $table->integer('records_synced')->default(0);
            $table->text('error_message')->nullable();
            $table->timestamp('synced_at')->nullable()->useCurrent();

            $table->index('employee_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('device_sync_logs');
    }
};
