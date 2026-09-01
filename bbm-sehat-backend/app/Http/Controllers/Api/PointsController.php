<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\EmployeeTotalPoint;
use App\Models\PointTransaction;
use App\Services\PointService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PointsController extends Controller
{
    public function __construct(private readonly PointService $points) {}

    public function summary(Request $request): JsonResponse
    {
        $employee = $request->user();
        $today = now()->toDateString();

        $totalPoints = (int) (EmployeeTotalPoint::find($employee->id)?->total_points ?? 0);

        $pointsToday = (int) PointTransaction::where('employee_id', $employee->id)
            ->where('reference_date', $today)
            ->sum('points_awarded');

        return response()->json([
            'data' => [
                'total_points' => $totalPoints,
                'points_today' => $pointsToday,
                'current_streak_days' => $this->points->currentStreakDays($employee),
            ],
        ]);
    }
}
