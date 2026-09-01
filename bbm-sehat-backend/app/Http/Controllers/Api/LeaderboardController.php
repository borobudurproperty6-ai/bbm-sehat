<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\LeaderboardService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class LeaderboardController extends Controller
{
    private const TOP_N = 20;

    public function __construct(private readonly LeaderboardService $leaderboard) {}

    public function index(Request $request): JsonResponse
    {
        $employee = $request->user();
        $scope = $this->validScope($request);
        $period = $this->validPeriod($request);

        [$start, $end] = $this->leaderboard->periodRange($period);
        $ranked = $this->leaderboard->rankedList($employee, $scope, $start, $end);

        $entries = $ranked->take(self::TOP_N)->all();
        $meIncluded = collect($entries)->contains(fn ($e) => $e['is_me']);
        if (!$meIncluded) {
            $mine = $ranked->firstWhere('is_me', true);
            if ($mine !== null) {
                $entries[] = $mine;
            }
        }

        return response()->json([
            'data' => [
                'scope' => $scope,
                'period' => $period,
                'entries' => array_values($entries),
            ],
        ]);
    }

    public function myPosition(Request $request): JsonResponse
    {
        $employee = $request->user();
        $scope = $this->validScope($request);
        $period = $this->validPeriod($request);

        [$start, $end] = $this->leaderboard->periodRange($period);
        $mine = $this->leaderboard->rankedList($employee, $scope, $start, $end)->firstWhere('is_me', true);

        [$prevStart, $prevEnd] = $this->leaderboard->previousPeriodRange($period);
        $previousRanked = $this->leaderboard->rankedList($employee, $scope, $prevStart, $prevEnd);
        $previousMine = $previousRanked->firstWhere('is_me', true);

        // No previous-period data at all (e.g. the app's very first week)
        // means there's nothing meaningful to compare against.
        $hadPreviousData = $previousRanked->sum('total_points') > 0;
        $rankChange = $hadPreviousData ? $previousMine['rank'] - $mine['rank'] : null;

        return response()->json([
            'data' => [
                'scope' => $scope,
                'period' => $period,
                'rank' => $mine['rank'],
                'total_points' => $mine['total_points'],
                'sub' => $mine['sub'],
                'rank_change' => $rankChange,
            ],
        ]);
    }

    private function validScope(Request $request): string
    {
        $scope = $request->query('scope', 'own_division');
        abort_unless(in_array($scope, LeaderboardService::SCOPES, true), 422, 'Invalid scope.');

        return $scope;
    }

    private function validPeriod(Request $request): string
    {
        $period = $request->query('period', 'weekly');
        abort_unless(in_array($period, LeaderboardService::PERIODS, true), 422, 'Invalid period.');

        return $period;
    }
}
