<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('daily_activity_logs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('employee_id')->constrained('employees')->cascadeOnDelete();
            $table->date('activity_date');
            $table->integer('steps')->default(0);
            $table->decimal('distance_meters', 10, 2)->nullable();
            $table->string('source', 30);
            $table->json('raw_data')->nullable();
            $table->timestamp('synced_at')->nullable()->useCurrent();
            $table->timestamp('created_at')->nullable()->useCurrent();

            $table->unique(['employee_id', 'activity_date'], 'uq_employee_date');
            $table->index('activity_date');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('daily_activity_logs');
    }
};
