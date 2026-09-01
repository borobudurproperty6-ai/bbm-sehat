<?php

namespace App\Policies;

use App\Models\Employee;

/**
 * Division Admin: can view/manage employees within their own division only.
 * Management: read-only across the whole company (dashboards, reports).
 * Super Admin: full access everywhere.
 */
class EmployeePolicy
{
    public function viewAny(Employee $actor): bool
    {
        return in_array($actor->roleCode(), ['DIVISION_ADMIN', 'MANAGEMENT', 'SUPER_ADMIN'], true);
    }

    public function view(Employee $actor, Employee $target): bool
    {
        if ($actor->isSuperAdmin() || $actor->isManagementRole()) {
            return true;
        }

        return $actor->isDivisionAdmin() && $actor->division_id === $target->division_id;
    }

    public function create(Employee $actor): bool
    {
        return $actor->isSuperAdmin() || $actor->isDivisionAdmin();
    }

    public function update(Employee $actor, Employee $target): bool
    {
        if ($actor->isSuperAdmin()) {
            return true;
        }

        return $actor->isDivisionAdmin() && $actor->division_id === $target->division_id;
    }

    public function deactivate(Employee $actor, Employee $target): bool
    {
        return $this->update($actor, $target);
    }

    public function resetPassword(Employee $actor, Employee $target): bool
    {
        return $this->update($actor, $target);
    }
}
