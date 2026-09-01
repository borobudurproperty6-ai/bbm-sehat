<?php

namespace App\Services;

use App\Models\AuditLog;
use App\Models\Employee;

/**
 * Single choke point for writing audit_logs rows, so every sensitive-action
 * controller records through the same method instead of building
 * AuditLog::create() calls by hand in each one.
 */
class AuditLogService
{
    public function log(string $action, ?Employee $actor, ?Employee $target = null, array $details = []): AuditLog
    {
        return AuditLog::create([
            'actor_employee_id' => $actor?->id,
            'action' => $action,
            'target_employee_id' => $target?->id,
            'details' => $details ?: null,
            // Explicit, app-timezone (UTC) value — see AuditLog::$fillable's
            // comment on why this can't be left to the column's own default.
            'created_at' => now(),
        ]);
    }
}
