<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('point_transactions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('employee_id')->constrained('employees')->cascadeOnDelete();
            $table->foreignId('point_rule_id')->constrained('point_rules');
            $table->integer('points_awarded');
            $table->date('reference_date');
            $table->string('reference_type', 30)->nullable();
            $table->unsignedBigInteger('reference_id')->nullable();
            $table->text('notes')->nullable();
            $table->timestamp('created_at')->nullable()->useCurrent();

            $table->index('employee_id');
            $table->index('reference_date');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('point_transactions');
    }
};
