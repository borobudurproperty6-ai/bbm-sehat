<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\FinishWalkSessionRequest;
use App\Http\Requests\StartWalkSessionRequest;
use App\Models\PointTransaction;
use App\Models\WalkSession;
use App\Services\PointService;
use App\Services\WalkSessionService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class WalkSessionController extends Controller
{
    public function __construct(
        private readonly WalkSessionService $walkSessions,
        private readonly PointService $points,
    ) {}

    public function start(StartWalkSessionRequest $request): JsonResponse
    {
        $session = WalkSession::create([
            'employee_id' => $request->user()->id,
            'started_at' => now(),
            'start_lat' => $request->float('start_lat'),
            'start_lng' => $request->float('start_lng'),
            'status' => 'in_progress',
            'source' => 'gps',
        ]);

        return response()->json([
            'data' => [
                'id' => $session->id,
                'started_at' => $session->started_at->toIso8601String(),
                'status' => $session->status,
            ],
        ], 201);
    }

    public function finish(FinishWalkSessionRequest $request, WalkSession $walkSession): JsonResponse
    {
        abort_if($walkSession->employee_id !== $request->user()->id, 404);

        $points = $request->input('points');
        $distance = $this->walkSessions->totalDistanceMeters($points);
        $polyline = $this->walkSessions->encodePolyline($points);

        // Row-locked + transactional: a concurrent finish() for the same
        // session (double-tap, retried request) blocks on the lock instead
        // of racing past the status check below and hitting
        // PointService::awardWalkSession()'s unique-constraint insert as an
        // unhandled QueryException.
        return DB::transaction(function () use ($request, $walkSession, $distance, $polyline) {
            $locked = WalkSession::whereKey($walkSession->id)->lockForUpdate()->firstOrFail();
            abort_if($locked->status !== 'in_progress', 422, 'This session has already been finished.');

            $locked->update([
                'ended_at' => now(),
                'duration_seconds' => $request->integer('duration_seconds'),
                'distance_meters' => $distance,
                'route_polyline' => $polyline,
                'end_lat' => $request->float('end_lat'),
                'end_lng' => $request->float('end_lng'),
                'status' => 'completed',
            ]);

            // point_rules.WALK_SESSION_LOGGED requires min_distance_meters 500 —
            // short/aborted walks don't earn points.
            $pointsAwarded = $distance >= 500 ? $this->points->awardWalkSession($locked) : 0;

            return $this->sessionResponse($locked, $pointsAwarded);
        });
    }

    /**
     * The Flutter app's session-summary screen has a "Hapus" button that
     * predates this backend (walk_sessions.status already had a
     * 'discarded' value in the original schema) — finish() now saves +
     * awards points immediately, so honoring "Hapus" means undoing both,
     * not just a local UI reset.
     */
    public function discard(Request $request, WalkSession $walkSession): JsonResponse
    {
        abort_if($walkSession->employee_id !== $request->user()->id, 404);
        abort_if($walkSession->status !== 'completed', 422, 'Only a completed session can be discarded.');

        PointTransaction::where('reference_type', 'walk_session')
            ->where('reference_id', $walkSession->id)
            ->delete();

        $walkSession->update(['status' => 'discarded']);

        return response()->json(['data' => ['id' => $walkSession->id, 'status' => $walkSession->status]]);
    }

    public function index(Request $request): JsonResponse
    {
        $sessions = WalkSession::where('employee_id', $request->user()->id)
            ->where('status', 'completed')
            ->orderByDesc('started_at')
            ->get();

        // One query for every session's points, instead of N — keyed by
        // reference_id so the Riwayat "Sesi Jalan Kaki" card can show what
        // each session actually earned.
        $pointsBySessionId = PointTransaction::where('reference_type', 'walk_session')
            ->whereIn('reference_id', $sessions->pluck('id'))
            ->pluck('points_awarded', 'reference_id');

        return response()->json([
            'data' => $sessions->map(fn (WalkSession $s) => [
                'id' => $s->id,
                'started_at' => $s->started_at->toIso8601String(),
                'ended_at' => $s->ended_at?->toIso8601String(),
                'duration_seconds' => $s->duration_seconds,
                'distance_meters' => (float) $s->distance_meters,
                'route_polyline' => $s->route_polyline,
                'points_awarded' => $pointsBySessionId[$s->id] ?? 0,
            ]),
        ]);
    }

    private function sessionResponse(WalkSession $session, ?int $pointsAwarded = null): JsonResponse
    {
        return response()->json([
            'data' => [
                'id' => $session->id,
                'started_at' => $session->started_at->toIso8601String(),
                'ended_at' => $session->ended_at?->toIso8601String(),
                'duration_seconds' => $session->duration_seconds,
                'distance_meters' => (float) $session->distance_meters,
                'route_polyline' => $session->route_polyline,
                'status' => $session->status,
                'points_awarded' => $pointsAwarded,
            ],
        ]);
    }
}
