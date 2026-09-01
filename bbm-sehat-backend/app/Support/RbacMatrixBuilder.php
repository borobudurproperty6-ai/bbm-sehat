<?php

namespace App\Support;

use Illuminate\Support\Facades\Route;
use RuntimeException;

/**
 * Builds the "Hak Akses per Role" matrix shown on the Pengaturan Pengguna
 * dashboard FROM the live route middleware — not a hand-maintained table of
 * ✓/✗ values. If someone edits a `role:...` middleware in routes/api.php,
 * this reflects it on the next request with no other code to update.
 *
 * What's still a maintained mapping (this class's one piece of technical
 * debt — see the class docblock on the "Hak Akses per Role" tab component
 * for the disclosure) is which routes are grouped under which human-
 * readable module label below. A newly added role-gated route that isn't
 * added to MODULES simply won't appear as a row — a visible omission, not
 * a silently wrong one. To keep that failure mode honest in the other
 * direction too: if a module's routes ever stop agreeing on the same role
 * list (e.g. only one of several was edited), or a mapped route stops
 * existing, or a mapped route loses its role: middleware entirely, build()
 * throws rather than rendering a matrix that could be wrong.
 */
class RbacMatrixBuilder
{
    private const MODULES = [
        'Manajemen Karyawan (Lihat)' => [
            ['GET', 'api/admin/employees'],
        ],
        'Manajemen Karyawan (Kelola)' => [
            ['POST', 'api/admin/employees'],
            ['PATCH', 'api/admin/employees/{employee}'],
            ['PATCH', 'api/admin/employees/{employee}/deactivate'],
            ['POST', 'api/admin/employees/{employee}/reset-password'],
        ],
        'Ubah Status Akun' => [
            ['PATCH', 'api/admin/employees/{employee}/account-status'],
        ],
        'Log Aktivitas (Audit)' => [
            ['GET', 'api/admin/audit-logs'],
        ],
        'Dashboard Monitoring' => [
            ['GET', 'api/monitoring/overview'],
            ['GET', 'api/monitoring/per-divisi'],
            ['GET', 'api/monitoring/tidak-aktif'],
            ['GET', 'api/monitoring/employees'],
            ['GET', 'api/monitoring/employees/{employee}'],
        ],
        'Kirim Pengingat Jalan' => [
            ['POST', 'api/admin/send-walk-reminder'],
        ],
        'Pengaturan Pengguna (halaman ini)' => [
            ['GET', 'dashboard/pengaturan-pengguna'],
        ],
    ];

    /**
     * @return array<int, array{label: string, roles: array<int, string>, whitelist_only: bool}>
     */
    public function build(): array
    {
        $routesByMethod = Route::getRoutes()->getRoutesByMethod();

        $modules = [];

        foreach (self::MODULES as $label => $routeKeys) {
            $rolesSeen = [];
            $whitelistOnly = false;

            foreach ($routeKeys as [$method, $uri]) {
                $route = $routesByMethod[$method][$uri] ?? null;

                if (! $route) {
                    throw new RuntimeException(
                        "RBAC matrix mapping is stale: no route [$method $uri] for module \"$label\"."
                    );
                }

                $middleware = $route->middleware();

                $roleMiddlewares = collect($middleware)->filter(fn ($m) => str_starts_with($m, 'role:'));

                if ($roleMiddlewares->isEmpty()) {
                    throw new RuntimeException(
                        "RBAC matrix mapping is stale: [$method $uri] (module \"$label\") no longer has a role: middleware."
                    );
                }

                // Nested groups can stack MULTIPLE role: middleware on one
                // route (e.g. an outer division_admin,management,super_admin
                // group with an inner division_admin,super_admin group) —
                // Laravel runs all of them, so a request must pass every
                // one. The roles actually allowed are the INTERSECTION
                // across all layers, not just whichever appears first.
                $roles = $roleMiddlewares
                    ->map(fn ($m) => collect(explode(',', substr($m, 5)))->map(fn ($r) => strtoupper($r))->all())
                    ->reduce(
                        fn (?array $carry, array $layer) => $carry === null ? $layer : array_values(array_intersect($carry, $layer)),
                        null
                    );

                sort($roles);
                $rolesSeen[] = $roles;

                if (in_array('user-settings-access', $middleware, true)) {
                    $whitelistOnly = true;
                }
            }

            $distinct = collect($rolesSeen)->unique(fn ($roles) => implode(',', $roles));

            if ($distinct->count() > 1) {
                throw new RuntimeException(
                    "RBAC matrix mapping is stale: routes under module \"$label\" no longer share the same role: list."
                );
            }

            $modules[] = [
                'label' => $label,
                'roles' => $rolesSeen[0],
                'whitelist_only' => $whitelistOnly,
            ];
        }

        return $modules;
    }
}
