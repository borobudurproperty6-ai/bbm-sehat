<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\SyncActivityRequest;
use App\Models\DailyActivityLog;
use App\Services\PointService;
use App\Services\StepTargetResolver;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

class ActivityController extends Controller
{
    public function __construct(
        private readonly StepTargetResolver $targets,
        private readonly PointService $points,
    ) {}

    /**
     * Upserts one row per employee per day — syncing the same date twice
     * (e.g. re-opening the app, or tapping "Sinkron Sekarang" again) updates
     * the existing row via the employee_id+activity_date unique index,
     * never duplicates it.
     */
    public function sync(SyncActivityRequest $request): JsonResponse
    {
        $employee = $request->user();
        $date = Carbon::parse($request->string('activity_date')->toString())->toDateString();
        $steps = $request->integer('steps');

        $log = DailyActivityLog::updateOrCreate(
            ['employee_id' => $employee->id, 'activity_date' => $date],
            [
                'steps' => $steps,
                'distance_meters' => $request->input('distance_meters'),
                // The Flutter app's old random-number 'manual_test' sync
                // button is retired — every real caller now reads from
                // Health Connect.
                'source' => 'health_connect',
                'synced_at' => now(),
            ]
        );

        // Points are computed server-side from the saved log — the client
        // only ever sends steps, never a points value.
        $this->points->awardForDailySync($employee, $date, $steps, $this->targets->resolve($employee, $date));

        return response()->json([
            'data' => [
                'activity_date' => $log->activity_date->toDateString(),
                'steps' => $log->steps,
                'distance_meters' => $log->distance_meters === null ? null : (float) $log->distance_meters,
                'source' => $log->source,
            ],
        ]);
    }

    public function today(Request $request): JsonResponse
    {
        $employee = $request->user();
        $today = now()->toDateString();

        $log = DailyActivityLog::where('employee_id', $employee->id)
            ->where('activity_date', $today)
            ->first();

        return response()->json([
            'data' => [
                'activity_date' => $today,
                'steps' => $log->steps ?? 0,
                'distance_meters' => $log && $log->distance_meters !== null ? (float) $log->distance_meters : 0,
                'target_steps' => $this->targets->resolve($employee, $today),
            ],
        ]);
    }
}
