<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('walk_sessions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('employee_id')->constrained('employees')->cascadeOnDelete();
            $table->dateTime('started_at');
            $table->dateTime('ended_at')->nullable();
            $table->integer('duration_seconds')->nullable();
            $table->decimal('distance_meters', 10, 2)->nullable();
            $table->text('route_polyline')->nullable();
            $table->decimal('start_lat', 10, 7)->nullable();
            $table->decimal('start_lng', 10, 7)->nullable();
            $table->decimal('end_lat', 10, 7)->nullable();
            $table->decimal('end_lng', 10, 7)->nullable();
            $table->enum('status', ['in_progress', 'completed', 'discarded'])->default('in_progress');
            $table->string('source', 20)->default('gps');
            $table->timestamps();

            $table->index(['employee_id', 'started_at']);
            $table->index('status');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('walk_sessions');
    }
};
