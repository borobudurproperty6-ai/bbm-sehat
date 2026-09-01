<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

// Laravel's default scaffolding bundles a `users` table here too, but BBM
// Sehat authenticates against `employees` (see the create_employees_table
// migration) — employees are provisioned by an admin, not self-registered,
// so there is no separate `users` table. password_reset_tokens works by
// email lookup regardless of which table the email belongs to, and
// `sessions` just needs a foreign id column (used by the Sanctum SPA guard
// for the dashboard) — both are kept as-is from the default scaffolding.
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('password_reset_tokens', function (Blueprint $table) {
            $table->string('email')->primary();
            $table->string('token');
            $table->timestamp('created_at')->nullable();
        });

        Schema::create('sessions', function (Blueprint $table) {
            $table->string('id')->primary();
            $table->foreignId('user_id')->nullable()->index();
            $table->string('ip_address', 45)->nullable();
            $table->text('user_agent')->nullable();
            $table->longText('payload');
            $table->integer('last_activity')->index();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('password_reset_tokens');
        Schema::dropIfExists('sessions');
    }
};
