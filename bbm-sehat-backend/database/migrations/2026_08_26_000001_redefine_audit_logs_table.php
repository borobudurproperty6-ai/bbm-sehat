<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Replaces the generic entity_type/entity_id/changes shape from the original
 * audit_logs migration (never wired up, table always empty) with the
 * target_employee_id/details shape actually used by AuditLogService — a
 * plain drop+recreate is safe here since nothing has written to the table
 * yet, and it sidesteps sqlite's lack of column-drop/rename support that a
 * modify-in-place migration would need (tests run on sqlite :memory:).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::dropIfExists('audit_logs');

        Schema::create('audit_logs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('actor_employee_id')->nullable()->constrained('employees')->nullOnDelete();
            $table->string('action', 50);
            $table->foreignId('target_employee_id')->nullable()->constrained('employees')->nullOnDelete();
            $table->json('details')->nullable();
            $table->timestamp('created_at')->nullable()->useCurrent();

            $table->index('action');
            $table->index('target_employee_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('audit_logs');
    }
};
