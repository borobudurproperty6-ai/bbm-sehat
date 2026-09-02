<?php

use App\Http\Controllers\Admin\DashboardController;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

// ── Dashboard (React SPA) page routes — session-guarded (guard 'web'),
//    same session AdminAuthController establishes. Each protected page gets
//    its own role-gated route so access is denied at the middleware layer
//    before any page HTML is ever returned, not just hidden client-side. ──
Route::get('/dashboard/login', function () {
    return view('admin.login');
})->name('dashboard.login');

// Mandatory first-login password change — deliberately gated on
// auth:web only, no role: restriction, since must_change_password
// can be true for any dashboard role that made it past
// AuthController::login.
Route::middleware(['auth:web'])->group(function () {
    Route::get('/dashboard/ganti-password-wajib', [DashboardController::class, 'gantiPasswordWajib'])
        ->name('dashboard.ganti-password-wajib');
});

// "Pengaturan Pengguna" additionally requires the actor's employee_code to
// be in the whitelist (config('dashboard.user_settings_allowed_employee_codes'))
// — role:super_admin alone is not enough. See EnsureEmployeeIsWhitelistedForUserSettings.
Route::middleware(['auth:web', 'role:super_admin', 'user-settings-access'])->group(function () {
    Route::get('/dashboard/pengaturan-pengguna', [DashboardController::class, 'pengaturanPengguna'])
        ->name('dashboard.pengaturan-pengguna');
});

// Monitoring dashboard — same role gate as the /api/monitoring/* endpoints
// these pages read from (see routes/api.php), no whitelist on top: every
// management/super_admin/admin_umum_sdm employee who can reach the
// dashboard gets these, unlike the SUPER_ADMIN-only "Pengaturan Pengguna".
Route::middleware(['auth:web', 'role:management,super_admin,admin_umum_sdm'])->group(function () {
    Route::get('/dashboard/monitoring/ringkasan', [DashboardController::class, 'monitoringRingkasan'])
        ->name('dashboard.monitoring.ringkasan');
    Route::get('/dashboard/monitoring/per-divisi', [DashboardController::class, 'monitoringPerDivisi'])
        ->name('dashboard.monitoring.per-divisi');
    Route::get('/dashboard/monitoring/tidak-aktif', [DashboardController::class, 'monitoringTidakAktif'])
        ->name('dashboard.monitoring.tidak-aktif');
    Route::get('/dashboard/monitoring/progres-karyawan', [DashboardController::class, 'monitoringProgresKaryawan'])
        ->name('dashboard.monitoring.progres-karyawan');
});
