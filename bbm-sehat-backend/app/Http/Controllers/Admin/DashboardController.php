<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use Illuminate\Contracts\View\View;
use Illuminate\Http\Request;

/**
 * Renders the React-mounted dashboard pages. Route-level middleware (see
 * routes/web.php) is what actually enforces access — these methods only run
 * once that has already passed, so there is no authorization check here.
 */
class DashboardController extends Controller
{
    public function pengaturanPengguna(Request $request): View
    {
        return view('admin.pengaturan-pengguna', ['employee' => $this->currentEmployee($request)]);
    }

    public function monitoringRingkasan(Request $request): View
    {
        return view('admin.monitoring-ringkasan', ['employee' => $this->currentEmployee($request)]);
    }

    public function monitoringPerDivisi(Request $request): View
    {
        return view('admin.monitoring-per-divisi', ['employee' => $this->currentEmployee($request)]);
    }

    public function monitoringTidakAktif(Request $request): View
    {
        return view('admin.monitoring-tidak-aktif', ['employee' => $this->currentEmployee($request)]);
    }

    public function monitoringProgresKaryawan(Request $request): View
    {
        return view('admin.monitoring-progres-karyawan', ['employee' => $this->currentEmployee($request)]);
    }

    /** @return array{id:int, full_name:string, role_code:?string, role_name:?string} */
    private function currentEmployee(Request $request): array
    {
        $employee = $request->user()->load('role');

        return [
            'id' => $employee->id,
            'full_name' => $employee->full_name,
            'role_code' => $employee->roleCode(),
            'role_name' => $employee->role?->name,
        ];
    }
}
