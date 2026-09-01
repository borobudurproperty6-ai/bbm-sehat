<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Enums\AccountStatus;
use App\Http\Requests\Auth\AdminLoginRequest;
use App\Http\Resources\EmployeeResource;
use App\Models\AuditLog;
use App\Models\Employee;
use App\Services\AuditLogService;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Auth;

/**
 * Dashboard (React SPA) login. The SPA must first GET /sanctum/csrf-cookie
 * (registered automatically by Sanctum), then POST here with that CSRF
 * token — this establishes a session cookie, not a bearer token. Only
 * Division Admin / Management / Super Admin / Admin Umum & SDM roles may
 * use the dashboard — Admin Umum & SDM was added alongside the Monitoring
 * pages, which this role needs to reach (see routes/web.php's
 * dashboard.monitoring.* group).
 */
class AuthController extends Controller
{
    public function login(AdminLoginRequest $request, AuditLogService $auditLog): JsonResponse
    {
        $credentials = $request->only('email', 'password');

        if (! Auth::guard('web')->attempt($credentials)) {
            $auditLog->log(AuditLog::ACTION_LOGIN_FAILED, null, Employee::where('email', $credentials['email'])->first(), [
                'identifier' => $credentials['email'],
                'guard' => 'dashboard',
            ]);

            return response()->json([
                'message' => 'Email atau kata sandi salah.',
            ], 401);
        }

        $employee = Auth::guard('web')->user();

        if (! in_array($employee->roleCode(), ['DIVISION_ADMIN', 'MANAGEMENT', 'SUPER_ADMIN', 'ADMIN_UMUM_SDM'], true)) {
            Auth::guard('web')->logout();

            $auditLog->log(AuditLog::ACTION_LOGIN_FAILED, null, $employee, [
                'identifier' => $credentials['email'],
                'guard' => 'dashboard',
                'reason' => 'role_not_allowed',
            ]);

            return response()->json([
                'message' => 'Akun ini tidak memiliki akses ke dashboard.',
            ], 403);
        }

        if (! $employee->canLogIn()) {
            Auth::guard('web')->logout();

            $auditLog->log(AuditLog::ACTION_LOGIN_FAILED, null, $employee, [
                'identifier' => $credentials['email'],
                'guard' => 'dashboard',
                'reason' => 'account_'.$employee->account_status->value,
            ]);

            return response()->json([
                'message' => $employee->account_status === AccountStatus::Archived
                    ? 'Akun ini sudah diarsipkan (karyawan resign).'
                    : 'Akun ini sudah tidak aktif.',
            ], 403);
        }

        $request->session()->regenerate();

        $auditLog->log(AuditLog::ACTION_LOGIN_SUCCESS, $employee, $employee, ['guard' => 'dashboard']);

        return response()->json([
            'must_change_password' => $employee->must_change_password,
            'employee' => new EmployeeResource($employee->load(['division', 'role'])),
            'redirect_to' => route($this->homeRouteFor($employee)),
        ]);
    }

    /**
     * Where to land right after login — every role that reaches here has
     * passed the role_not_allowed check above, but that does NOT mean every
     * one of them has a page: "Pengaturan Pengguna" is only ever open to the
     * user_settings whitelist (see Employee::isWhitelistedForUserSettings),
     * narrower than the SUPER_ADMIN role itself, so a non-whitelisted
     * SUPER_ADMIN falls through to Monitoring like MANAGEMENT/ADMIN_UMUM_SDM
     * do. DIVISION_ADMIN also falls through to Monitoring even though that
     * page's own route middleware (role:management,super_admin,admin_umum_sdm)
     * doesn't include it either — there is currently no dashboard page for
     * Division Admin at all (a separate, already-tracked gap, not something
     * this redirect can paper over); Monitoring is just the closest existing
     * page rather than a route name that doesn't exist.
     */
    private function homeRouteFor(Employee $employee): string
    {
        if ($employee->isSuperAdmin() && $employee->isWhitelistedForUserSettings()) {
            return 'dashboard.pengaturan-pengguna';
        }

        return 'dashboard.monitoring.ringkasan';
    }
}
