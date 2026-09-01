<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('notifications', function (Blueprint $table) {
            $table->id();
            $table->foreignId('employee_id')->constrained('employees')->cascadeOnDelete();
            $table->string('type', 50);
            $table->string('title', 200);
            $table->text('body')->nullable();
            $table->boolean('is_read')->default(false);
            $table->json('metadata')->nullable();
            $table->timestamp('created_at')->nullable()->useCurrent();

            $table->index(['employee_id', 'is_read']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('notifications');
    }
};
