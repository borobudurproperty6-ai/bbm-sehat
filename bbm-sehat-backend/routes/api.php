<?php

use App\Http\Controllers\Api\Admin\AuditLogController;
use App\Http\Controllers\Api\Admin\AuthController as AdminAuthController;
use App\Http\Controllers\Api\Admin\CredentialSlipController;
use App\Http\Controllers\Api\Admin\DivisionController;
use App\Http\Controllers\Api\Admin\EmployeeController;
use App\Http\Controllers\Api\Admin\RbacMatrixController;
use App\Http\Controllers\Api\Admin\RoleController;
use App\Http\Controllers\Api\ActivityController;
use App\Http\Controllers\Api\ActivityHistoryController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\DeviceTokenController;
use App\Http\Controllers\Api\LeaderboardController;
use App\Http\Controllers\Api\MonitoringController;
use App\Http\Controllers\Api\PointsController;
use App\Http\Controllers\Api\ProfilePhotoController;
use App\Http\Controllers\Api\WalkReminderController;
use App\Http\Controllers\Api\WalkSessionController;
use Illuminate\Support\Facades\Route;

// ── Auth (shared by the Flutter app and the React dashboard) ──────────────
Route::post('/login', [AuthController::class, 'login'])->middleware('throttle:login');
Route::post('/forgot-password', [AuthController::class, 'forgotPassword'])->middleware('throttle:login');
Route::post('/reset-password', [AuthController::class, 'resetPassword'])->middleware('throttle:login');

Route::middleware('auth:sanctum')->group(function () {
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/me', [AuthController::class, 'me']);
    Route::post('/change-password', [AuthController::class, 'changePassword']);

    Route::post('/activity/sync', [ActivityController::class, 'sync']);
    Route::get('/activity/today', [ActivityController::class, 'today']);
    Route::get('/activity/history', [ActivityHistoryController::class, 'index']);

    Route::get('/points/summary', [PointsController::class, 'summary']);

    Route::post('/devices/register', [DeviceTokenController::class, 'register']);
    Route::post('/profile/photo', [ProfilePhotoController::class, 'upload']);

    Route::get('/leaderboard', [LeaderboardController::class, 'index']);
    Route::get('/leaderboard/my-position', [LeaderboardController::class, 'myPosition']);

    Route::post('/walk-sessions/start', [WalkSessionController::class, 'start']);
    Route::patch('/walk-sessions/{walkSession}/finish', [WalkSessionController::class, 'finish']);
    Route::delete('/walk-sessions/{walkSession}', [WalkSessionController::class, 'discard']);
    Route::get('/walk-sessions', [WalkSessionController::class, 'index']);
});

// ── Dashboard (React SPA) session login ────────────────────────────────────
Route::post('/admin/login', [AdminAuthController::class, 'login'])->middleware('throttle:login');

// ── Admin: employee & division management ─────────────────────────────────
Route::middleware(['auth:sanctum', 'role:division_admin,management,super_admin'])
    ->prefix('admin')
    ->group(function () {
        Route::get('/employees', [EmployeeController::class, 'index']);
        Route::get('/divisions', [DivisionController::class, 'index']);

        Route::middleware('role:division_admin,super_admin')->group(function () {
            Route::post('/employees', [EmployeeController::class, 'store']);
            Route::patch('/employees/{employee}', [EmployeeController::class, 'update']);
            Route::patch('/employees/{employee}/deactivate', [EmployeeController::class, 'deactivate']);
            Route::post('/employees/{employee}/reset-password', [EmployeeController::class, 'resetPassword']);
        });
    });

// ── Dashboard "Pengaturan Pengguna" (whitelisted SUPER_ADMIN only) ────────
//    Reuses the SAME controller methods as the /admin/employees group above
//    — no business logic duplicated — but under a stricter gate: role
//    SUPER_ADMIN AND employee_code in config('dashboard.user_settings_...')
//    (see EnsureEmployeeIsWhitelistedForUserSettings). Deliberately a
//    separate prefix/route set rather than tightening /admin/employees
//    itself, so Division Admin's existing access there is untouched. ──────
Route::middleware(['auth:sanctum', 'role:super_admin', 'user-settings-access'])
    ->prefix('admin/user-settings')
    ->group(function () {
        Route::get('/employees', [EmployeeController::class, 'index']);
        Route::post('/employees', [EmployeeController::class, 'store']);
        Route::patch('/employees/{employee}', [EmployeeController::class, 'update']);
        Route::post('/employees/{employee}/reset-password', [EmployeeController::class, 'resetPassword']);
        Route::patch('/employees/{employee}/account-status', [EmployeeController::class, 'updateAccountStatus']);
        Route::get('/divisions', [DivisionController::class, 'index']);
        Route::get('/roles', [RoleController::class, 'index']);
        Route::post('/employees/{employee}/credential-slip', [CredentialSlipController::class, 'generate']);
        Route::get('/rbac-matrix', [RbacMatrixController::class, 'index']);
        Route::get('/audit-logs', [AuditLogController::class, 'index']);
    });

// ── Admin: audit log (SUPER_ADMIN only) ────────────────────────────────────
Route::middleware(['auth:sanctum', 'role:super_admin'])
    ->prefix('admin')
    ->group(function () {
        Route::get('/audit-logs', [AuditLogController::class, 'index']);
    });

// ── Admin: account status (SUPER_ADMIN + ADMIN_UMUM_SDM only) — separate
//    from the employee/division management group above, which uses a
//    different role set (division_admin/management/super_admin). ──────────
Route::middleware(['auth:sanctum', 'role:super_admin,admin_umum_sdm'])
    ->prefix('admin')
    ->group(function () {
        Route::patch('/employees/{employee}/account-status', [EmployeeController::class, 'updateAccountStatus']);
    });

// ── Monitoring dashboard (Flutter, role-gated view) — company-wide
//    aggregates only, deliberately NOT division_admin: that role is scoped
//    to one division by design, and this data spans all of them. ─────────────
Route::middleware(['auth:sanctum', 'role:management,super_admin,admin_umum_sdm'])
    ->prefix('monitoring')
    ->group(function () {
        Route::get('/overview', [MonitoringController::class, 'overview']);
        Route::get('/per-divisi', [MonitoringController::class, 'perDivisi']);
        Route::get('/tidak-aktif', [MonitoringController::class, 'tidakAktif']);
        Route::get('/employees', [MonitoringController::class, 'employees']);
        Route::get('/employees/{employee}', [MonitoringController::class, 'employeeDetail']);
    });

// ── Manual walk reminder trigger — the "Kirim Reminder Jalan Kaki" admin
//    button. The real automated sends are scheduled separately (see
//    routes/console.php: SendWalkReminders, 15:00 & 19:00 WITA, dedup'd
//    per slot); this manual one is deliberately exempt from that dedup, so
//    an admin re-triggering it on purpose always actually sends. Not
//    nested under the /admin prefix group above: its role set (super_admin,
//    admin_umum_sdm, management) doesn't match either middleware layer
//    already declared there, and stacking a third `role:` middleware would
//    AND the role checks together rather than replace them. management is
//    included so Direktur/Komisaris — who see this button in the mobile
//    app's Monitoring tab — aren't blocked by the backend. ────────────────
Route::post('/admin/send-walk-reminder', [WalkReminderController::class, 'send'])
    ->middleware(['auth:sanctum', 'role:super_admin,admin_umum_sdm,management']);
