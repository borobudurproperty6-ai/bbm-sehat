<?php

namespace App\Services;

use App\Models\Employee;
use App\Models\StepTarget;

/**
 * Shared by ActivityController (sync/today) and the streak test-seeder
 * command, so the employee -> division -> global priority cascade only
 * lives in one place.
 */
class StepTargetResolver
{
    public function resolve(Employee $employee, ?string $asOfDate = null): int
    {
        $date = $asOfDate ?? now()->toDateString();

        $find = function (string $scopeType, ?int $scopeId) use ($date): ?int {
            return StepTarget::query()
                ->where('scope_type', $scopeType)
                ->where(fn ($q) => $scopeId === null ? $q->whereNull('scope_id') : $q->where('scope_id', $scopeId))
                ->where('effective_from', '<=', $date)
                ->where(fn ($q) => $q->whereNull('effective_to')->orWhere('effective_to', '>=', $date))
                ->orderByDesc('effective_from')
                ->value('target_steps');
        };

        return $find('employee', $employee->id)
            ?? $find('division', $employee->division_id)
            ?? $find('global', null)
            ?? 8000;
    }
}
