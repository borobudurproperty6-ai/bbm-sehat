<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('leaderboard_snapshots', function (Blueprint $table) {
            $table->id();
            $table->enum('period_type', ['daily', 'weekly', 'monthly']);
            $table->string('period_key', 20);
            $table->enum('scope_type', ['individual', 'division', 'company']);
            $table->unsignedBigInteger('scope_id')->nullable();
            $table->foreignId('employee_id')->nullable()->constrained('employees');
            $table->integer('total_points')->default(0);
            $table->integer('total_steps')->default(0);
            $table->decimal('total_distance_meters', 10, 2)->default(0);
            $table->integer('rank')->nullable();
            $table->timestamp('generated_at')->nullable()->useCurrent();

            $table->index(['period_type', 'period_key', 'scope_type']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('leaderboard_snapshots');
    }
};
