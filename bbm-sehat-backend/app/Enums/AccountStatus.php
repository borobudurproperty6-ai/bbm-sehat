<?php

namespace App\Enums;

/**
 * Login/system-access status of an employee's account — distinct from
 * "activity status" (whether they've been physically active lately, see
 * MonitoringService::tidakAktif()), which is an unrelated concept computed
 * from daily_activity_logs/walk_sessions, not stored on this column.
 */
enum AccountStatus: string
{
    case Active = 'active';
    case Inactive = 'inactive';
    case Archived = 'archived';
}
