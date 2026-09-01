<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Employee;
use App\Services\MonitoringService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Company-wide monitoring dashboard, for management/admin roles only — see
 * routes/api.php's 'role:' middleware on this controller's routes.
 */
class MonitoringController extends Controller
{
    public function __construct(private readonly MonitoringService $monitoring) {}

    public function overview(): JsonResponse
    {
        return response()->json(['data' => $this->monitoring->overview()]);
    }

    public function perDivisi(): JsonResponse
    {
        [$start, $end] = $this->monitoring->currentWeekRange();

        return response()->json([
            'data' => [
                'period' => ['start' => $start, 'end' => $end],
                'divisions' => $this->monitoring->perDivisi($start, $end)->values(),
            ],
        ]);
    }

    public function tidakAktif(Request $request): JsonResponse
    {
        $days = (int) $request->query('days', 7);
        abort_if($days < 1 || $days > 365, 422, 'days must be between 1 and 365.');

        return response()->json([
            'data' => [
                'days' => $days,
                'employees' => $this->monitoring->tidakAktif($days)->values(),
            ],
        ]);
    }

    public function employees(Request $request): JsonResponse
    {
        $sortBy = $request->query('sort_by', 'poin');
        abort_unless(
            in_array($sortBy, ['poin', 'langkah_minggu_ini', 'nama', 'divisi'], true),
            422,
            'sort_by tidak valid.',
        );

        $paginated = $this->monitoring->employees([
            'search' => $request->query('search'),
            'sort_by' => $sortBy,
            'division_id' => $request->query('divisi'),
            'per_page' => $request->query('per_page', 20),
            'page' => $request->query('page', 1),
        ]);

        return response()->json([
            'data' => collect($paginated->items())->map(fn (Employee $e) => [
                'id' => $e->id,
                'full_name' => $e->full_name,
                'employee_code' => $e->employee_code,
                'photo_url' => $e->photoUrl(),
                'division_name' => $e->division_name,
                'total_points' => (int) $e->total_points,
                'steps_this_week' => (int) $e->steps_this_week,
                'current_streak_days' => $e->current_streak_days,
                'is_active_recently' => $e->is_active_recently,
            ])->values(),
            'meta' => [
                'current_page' => $paginated->currentPage(),
                'per_page' => $paginated->perPage(),
                'total' => $paginated->total(),
                'last_page' => $paginated->lastPage(),
            ],
        ]);
    }

    public function employeeDetail(Employee $employee): JsonResponse
    {
        return response()->json(['data' => $this->monitoring->employeeDetail($employee)]);
    }
}
