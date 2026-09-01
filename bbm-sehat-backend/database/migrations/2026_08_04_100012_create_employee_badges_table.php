<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('employee_badges', function (Blueprint $table) {
            $table->id();
            $table->foreignId('employee_id')->constrained('employees')->cascadeOnDelete();
            $table->foreignId('badge_type_id')->constrained('badge_types');
            $table->string('period_key', 20)->nullable();
            $table->timestamp('awarded_at')->nullable()->useCurrent();
            $table->json('reference')->nullable();

            $table->index('employee_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('employee_badges');
    }
};
