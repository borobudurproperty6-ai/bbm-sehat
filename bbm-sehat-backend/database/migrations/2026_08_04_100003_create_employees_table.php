<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('employees', function (Blueprint $table) {
            $table->id();
            $table->string('employee_code', 30)->unique()->nullable();
            $table->string('full_name', 150);
            $table->string('email', 150)->unique()->nullable();
            $table->string('phone', 30)->nullable();
            $table->foreignId('division_id')->nullable()->constrained('divisions')->nullOnDelete();
            $table->foreignId('role_id')->nullable()->constrained('roles')->nullOnDelete();
            $table->boolean('is_management')->default(false);
            $table->boolean('is_active')->default(true);
            $table->date('joined_at')->nullable();
            $table->json('metadata')->nullable();

            // Auth columns — not in the original SQL reference schema, added
            // here because employees (not a separate `users` table) are the
            // authenticatable identity. Admin-provisioned accounts start
            // with must_change_password=true until the employee sets their
            // own password on first login.
            $table->string('password');
            $table->boolean('must_change_password')->default(true);
            $table->timestamp('email_verified_at')->nullable();
            $table->rememberToken();

            $table->timestamps();

            $table->index('division_id');
            $table->index('is_active');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('employees');
    }
};
