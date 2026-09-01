<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Usage: ->middleware('role:division_admin,super_admin')
 * Role codes are matched case-insensitively against employees.role.code.
 */
class EnsureEmployeeHasRole
{
    public function handle(Request $request, Closure $next, string ...$roles): Response
    {
        $employee = $request->user();

        if (! $employee) {
            abort(401, 'Unauthenticated.');
        }

        $roleCode = strtoupper((string) $employee->roleCode());
        $allowed = array_map('strtoupper', $roles);

        if (! in_array($roleCode, $allowed, true)) {
            abort(403, 'Anda tidak memiliki akses untuk aksi ini.');
        }

        return $next($request);
    }
}
