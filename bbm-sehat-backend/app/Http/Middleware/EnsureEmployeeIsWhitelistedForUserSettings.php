<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Scoped ONLY to the "Pengaturan Pengguna" page and its API endpoints —
 * deliberately separate from the `role` middleware (EnsureEmployeeHasRole),
 * which keeps meaning "has this role" everywhere else in the system. Stack
 * this AFTER role:super_admin in the route middleware list so both
 * conditions apply (role AND whitelisted employee_code); it does not
 * replace the role check.
 *
 * Whitelist lives in config('dashboard.user_settings_allowed_employee_codes')
 * — edit that one array to add/remove access, nothing else changes. The
 * check itself is Employee::isWhitelistedForUserSettings(), shared with
 * AdminAuthController::login()'s post-login redirect so the two can't drift.
 */
class EnsureEmployeeIsWhitelistedForUserSettings
{
    public function handle(Request $request, Closure $next): Response
    {
        $employee = $request->user();

        if (! $employee) {
            abort(401, 'Unauthenticated.');
        }

        if (! $employee->isWhitelistedForUserSettings()) {
            abort(403, 'Anda tidak memiliki akses untuk aksi ini.');
        }

        return $next($request);
    }
}
