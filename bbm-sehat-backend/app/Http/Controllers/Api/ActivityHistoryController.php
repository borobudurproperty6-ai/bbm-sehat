<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\ActivityHistoryService;
use App\Services\StepTargetResolver;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ActivityHistoryController extends Controller
{
    public function __construct(
        private readonly ActivityHistoryService $history,
        private readonly StepTargetResolver $targets,
    ) {}

    public function index(Request $request): JsonResponse
    {
        $employee = $request->user();
        $period = $request->query('period', 'weekly');
        abort_unless(in_array($period, ['weekly', 'monthly'], true), 422, 'Invalid period.');

        $result = $period === 'monthly'
            ? $this->history->monthly($employee)
            : $this->history->weekly($employee, $this->targets);

        return response()->json([
            'data' => [
                'period' => $period,
                'average_daily_steps' => $result['average_daily_steps'],
                'target_steps' => $this->targets->resolve($employee),
                'entries' => $result['entries'],
            ],
        ]);
    }
}
