<?php

namespace App\Services;

use App\Enums\AccountStatus;
use App\Models\Employee;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

/**
 * Ranks employees or divisions by points earned (SUM of point_transactions)
 * within a date range — computed live on every request, not from the
 * leaderboard_snapshots table (that's for later, if this ever needs
 * pre-aggregation for performance).
 */
class LeaderboardService
{
    public const SCOPES = ['own_division', 'all_employees', 'by_division'];
    public const PERIODS = ['weekly', 'monthly'];

    /**
     * @return Collection<int, array{rank:int, id:int, name:string, sub:string, total_points:int, is_me:bool}>
     */
    public function rankedList(Employee $viewer, string $scope, string $start, string $end): Collection
    {
        $rows = $scope === 'by_division'
            ? $this->divisionRows($start, $end)
            : $this->employeeRows($viewer, $scope, $start, $end);

        return $rows->values()->map(function ($row, int $index) use ($viewer, $scope) {
            $isMe = $scope === 'by_division'
                ? (int) $row->division_id === $viewer->division_id
                : (int) $row->employee_id === $viewer->id;

            return [
                'rank' => $index + 1,
                'id' => (int) ($scope === 'by_division' ? $row->division_id : $row->employee_id),
                'name' => $row->name,
                // Divisions have no individual photo of their own.
                'photo_url' => $scope === 'by_division'
                    ? null
                    : ($row->photo_path ? Storage::disk('public')->url($row->photo_path) : null),
                'sub' => $scope === 'by_division' ? "{$row->employee_count} karyawan" : $row->division_name,
                'total_points' => (int) $row->total_points,
                'is_me' => $isMe,
            ];
        });
    }

    private function employeeRows(Employee $viewer, string $scope, string $start, string $end): Collection
    {
        return DB::table('employees')
            ->where('employees.account_status', AccountStatus::Active->value)
            ->join('divisions', 'divisions.id', '=', 'employees.division_id')
            ->leftJoin('point_transactions', function ($join) use ($start, $end) {
                $join->on('point_transactions.employee_id', '=', 'employees.id')
                    ->whereBetween('point_transactions.reference_date', [$start, $end]);
            })
            ->when($scope === 'own_division', fn ($q) => $q->where('employees.division_id', $viewer->division_id))
            ->groupBy('employees.id', 'employees.full_name', 'employees.photo_path', 'divisions.name')
            ->selectRaw(
                'employees.id as employee_id, employees.full_name as name, employees.photo_path, '.
                'divisions.name as division_name, COALESCE(SUM(point_transactions.points_awarded), 0) as total_points'
            )
            ->orderByDesc('total_points')
            ->orderBy('employees.id')
            ->get();
    }

    private function divisionRows(string $start, string $end): Collection
    {
        return DB::table('divisions')
            ->where('divisions.is_active', true)
            ->leftJoin('employees', function ($join) {
                $join->on('employees.division_id', '=', 'divisions.id')->where('employees.account_status', AccountStatus::Active->value);
            })
            ->leftJoin('point_transactions', function ($join) use ($start, $end) {
                $join->on('point_transactions.employee_id', '=', 'employees.id')
                    ->whereBetween('point_transactions.reference_date', [$start, $end]);
            })
            ->groupBy('divisions.id', 'divisions.name')
            ->selectRaw(
                'divisions.id as division_id, divisions.name as name, '.
                'COUNT(DISTINCT employees.id) as employee_count, '.
                'COALESCE(SUM(point_transactions.points_awarded), 0) as total_points'
            )
            ->orderByDesc('total_points')
            ->orderBy('divisions.id')
            ->get();
    }

    /** @return array{0:string, 1:string} [start date, end date] */
    public function periodRange(string $period, ?Carbon $asOf = null): array
    {
        $asOf ??= now();

        if ($period === 'monthly') {
            return [$asOf->copy()->startOfMonth()->toDateString(), $asOf->copy()->toDateString()];
        }

        return [$asOf->copy()->startOfWeek(Carbon::MONDAY)->toDateString(), $asOf->copy()->toDateString()];
    }

    /**
     * The full prior period (last complete week or month), used only for
     * the "naik/turun N peringkat" comparison — comparing a partial current
     * period against a completed reference period is the standard,
     * expected shape for this kind of comparison.
     *
     * @return array{0:string, 1:string}
     */
    public function previousPeriodRange(string $period, ?Carbon $asOf = null): array
    {
        $asOf ??= now();

        if ($period === 'monthly') {
            $prevMonth = $asOf->copy()->subMonthNoOverflow()->startOfMonth();

            return [$prevMonth->toDateString(), $prevMonth->copy()->endOfMonth()->toDateString()];
        }

        $prevWeekStart = $asOf->copy()->startOfWeek(Carbon::MONDAY)->subWeek();

        return [$prevWeekStart->toDateString(), $prevWeekStart->copy()->addDays(6)->toDateString()];
    }
}
