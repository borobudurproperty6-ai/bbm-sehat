<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AuditLog extends Model
{
    use HasFactory;

    public const ACTION_LOGIN_SUCCESS = 'LOGIN_SUCCESS';

    public const ACTION_LOGIN_FAILED = 'LOGIN_FAILED';

    public const ACTION_PASSWORD_RESET = 'PASSWORD_RESET';

    public const ACTION_ROLE_CHANGED = 'ROLE_CHANGED';

    public const ACTION_ACCOUNT_STATUS_CHANGED = 'ACCOUNT_STATUS_CHANGED';

    public const ACTION_USER_CREATED = 'USER_CREATED';

    public $timestamps = false;

    // created_at is fillable so AuditLogService can set it explicitly to
    // now() (app-timezone UTC) — the column's own DEFAULT CURRENT_TIMESTAMP
    // would otherwise fire instead, which resolves against MySQL's SYSTEM
    // session time_zone (the host machine's local tz), not
    // config('app.timezone'). On this project's dev host that's UTC+8, so
    // rows written via the column default land ~8 hours ahead of every
    // other timestamp in the app (employees.updated_at, session data,
    // etc.) — misleading for anything read chronologically, like
    // reconstructing a login incident from this table.
    protected $fillable = ['actor_employee_id', 'action', 'target_employee_id', 'details', 'created_at'];

    protected function casts(): array
    {
        return [
            'details' => 'array',
            'created_at' => 'datetime',
        ];
    }

    public function actor(): BelongsTo
    {
        return $this->belongsTo(Employee::class, 'actor_employee_id');
    }

    public function target(): BelongsTo
    {
        return $this->belongsTo(Employee::class, 'target_employee_id');
    }
}
