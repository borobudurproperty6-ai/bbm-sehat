<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('step_targets', function (Blueprint $table) {
            $table->id();
            $table->enum('scope_type', ['global', 'division', 'employee']);
            $table->unsignedBigInteger('scope_id')->nullable();
            $table->integer('target_steps');
            $table->date('effective_from');
            $table->date('effective_to')->nullable();
            $table->foreignId('created_by')->nullable()->constrained('employees')->nullOnDelete();
            $table->timestamp('created_at')->nullable()->useCurrent();

            $table->index(['scope_type', 'scope_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('step_targets');
    }
};
