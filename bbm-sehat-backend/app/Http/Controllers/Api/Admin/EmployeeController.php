<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Enums\AccountStatus;
use App\Http\Requests\Admin\StoreEmployeeRequest;
use App\Http\Requests\Admin\UpdateAccountStatusRequest;
use App\Http\Requests\Admin\UpdateEmployeeRequest;
use App\Http\Resources\EmployeeResource;
use App\Models\AuditLog;
use App\Models\Employee;
use App\Models\Role;
use App\Notifications\EmployeeAccountProvisioned;
use App\Services\AuditLogService;
use App\Support\TemporaryPasswordGenerator;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\Log;

class EmployeeController extends Controller
{
    /**
     * Division Admins only ever see their own division; Management and
     * Super Admin see everyone. Enforced here (list scope) rather than
     * relying on the index policy alone, since there's no single "target"
     * employee to check view() against for a list endpoint.
     */
    public function index(Request $request): AnonymousResourceCollection
    {
        $this->authorize('viewAny', Employee::class);

        $actor = $request->user();

        $query = Employee::query()->with(['division', 'role']);

        if ($actor->isDivisionAdmin()) {
            $query->where('division_id', $actor->division_id);
        } elseif ($request->filled('division_id') && ($actor->isManagementRole() || $actor->isSuperAdmin())) {
            $query->where('division_id', $request->integer('division_id'));
        }

        return EmployeeResource::collection($query->orderBy('full_name')->paginate(25));
    }

    public function store(StoreEmployeeRequest $request, AuditLogService $auditLog): JsonResponse
    {
        $temporaryPassword = TemporaryPasswordGenerator::generate();

        $roleId = $request->integer('role_id') ?: Role::where('code', 'EMPLOYEE')->value('id');

        $employee = Employee::create([
            'employee_code' => $request->input('employee_code') ?: $this->generateEmployeeCode(),
            'full_name' => $request->string('full_name'),
            'email' => $request->string('email'),
            'phone' => $request->input('phone'),
            'division_id' => $request->integer('division_id'),
            'role_id' => $roleId,
            'is_management' => $request->boolean('is_management'),
            'account_status' => AccountStatus::Active,
            'joined_at' => $request->input('joined_at'),
            'password' => $temporaryPassword,
            'must_change_password' => true,
        ]);

        $auditLog->log(AuditLog::ACTION_USER_CREATED, $request->user(), $employee, [
            'employee_code' => $employee->employee_code,
            'role_id' => $roleId,
        ]);

        $this->sendProvisioningNotification($employee, $temporaryPassword);

        return (new EmployeeResource($employee->load(['division', 'role'])))
            ->additional(['temporary_password' => $temporaryPassword])
            ->response()
            ->setStatusCode(201);
    }

    public function update(UpdateEmployeeRequest $request, Employee $employee, AuditLogService $auditLog): EmployeeResource
    {
        // Only Super Admin may reassign roles — a Division Admin promoting
        // someone to SUPER_ADMIN would be a privilege escalation bug. This
        // rejects the whole request rather than silently dropping the
        // field, so a caller can't mistake a 200 response for the role
        // change having actually applied.
        if ($request->filled('role_id') && ! $request->user()->isSuperAdmin()) {
            abort(403, 'Hanya Super Admin yang dapat mengubah role karyawan.');
        }

        // Nobody may change their own role — a Super Admin doing this to
        // themselves is exactly the self-lockout scenario this guards
        // against (there'd be no one left to undo it). Blocks ANY change
        // to their own role_id, not just a downgrade: comparing role
        // "levels" isn't well-defined, so refusing all self role-changes is
        // the only rule that's unambiguous.
        if ($request->filled('role_id') && $employee->id === $request->user()->id) {
            abort(422, 'Anda tidak dapat mengubah role akun Anda sendiri.');
        }

        $oldRole = $employee->role;

        $employee->update($request->safe()->except(['role_id']));

        if ($request->filled('role_id')) {
            $newRoleId = $request->integer('role_id');

            if ($employee->role_id !== $newRoleId) {
                $employee->update(['role_id' => $newRoleId]);

                $auditLog->log(AuditLog::ACTION_ROLE_CHANGED, $request->user(), $employee, [
                    'old_role_id' => $oldRole?->id,
                    'old_role_code' => $oldRole?->code,
                    'new_role_id' => $newRoleId,
                    'new_role_code' => Role::find($newRoleId)?->code,
                ]);
            }
        }

        return new EmployeeResource($employee->load(['division', 'role']));
    }

    public function deactivate(Request $request, Employee $employee, AuditLogService $auditLog): EmployeeResource
    {
        $this->authorize('deactivate', $employee);

        if ($employee->id === $request->user()->id) {
            abort(422, 'Anda tidak dapat menonaktifkan akun Anda sendiri.');
        }

        $oldStatus = $employee->account_status;

        $employee->update(['account_status' => AccountStatus::Inactive]);

        if ($oldStatus !== AccountStatus::Inactive) {
            $auditLog->log(AuditLog::ACTION_ACCOUNT_STATUS_CHANGED, $request->user(), $employee, [
                'old_status' => $oldStatus->value,
                'new_status' => AccountStatus::Inactive->value,
            ]);
        }

        return new EmployeeResource($employee->load(['division', 'role']));
    }

    /**
     * General account-status change (active/inactive/archived) — separate
     * from deactivate() above (which only ever sets 'inactive' and is kept
     * for backward compatibility with its existing division_admin/super_admin
     * role gate). This one is SUPER_ADMIN/ADMIN_UMUM_SDM only (see
     * routes/api.php) and is the only way to set 'archived', for employees
     * who've resigned — their history stays, but they can no longer log in.
     */
    public function updateAccountStatus(UpdateAccountStatusRequest $request, Employee $employee, AuditLogService $auditLog): EmployeeResource
    {
        $oldStatus = $employee->account_status;
        $newStatus = AccountStatus::from($request->string('account_status')->toString());

        // Self-lockout guard — an admin taking themselves out of
        // 'active' would leave nobody able to undo it via this same page.
        if ($employee->id === $request->user()->id && $newStatus !== AccountStatus::Active) {
            abort(422, 'Anda tidak dapat menonaktifkan/mengarsipkan akun Anda sendiri.');
        }

        if ($oldStatus !== $newStatus) {
            $employee->update(['account_status' => $newStatus]);

            $auditLog->log(AuditLog::ACTION_ACCOUNT_STATUS_CHANGED, $request->user(), $employee, [
                'old_status' => $oldStatus->value,
                'new_status' => $newStatus->value,
            ]);
        }

        return new EmployeeResource($employee->load(['division', 'role']));
    }

    /**
     * Manual fallback for employees who don't check email regularly (field
     * staff, store staff) — admin resets the password and relays the new
     * temporary password directly (phone/WhatsApp) instead of email.
     */
    public function resetPassword(Request $request, Employee $employee, AuditLogService $auditLog): JsonResponse
    {
        $this->authorize('resetPassword', $employee);

        // Self-lockout guard — same rule as update()'s role-change block and
        // updateAccountStatus() above: resetting your OWN password silently
        // replaces it with a one-time temporary password shown only in this
        // response, so if it's missed or misread, that admin is locked out
        // with no one having caused it but themselves.
        if ($employee->id === $request->user()->id) {
            abort(422, 'Anda tidak dapat mereset password akun Anda sendiri di sini — gunakan Ubah Password.');
        }

        $temporaryPassword = TemporaryPasswordGenerator::generate();

        $employee->forceFill([
            'password' => $temporaryPassword,
            'must_change_password' => true,
        ])->save();

        $auditLog->log(AuditLog::ACTION_PASSWORD_RESET, $request->user(), $employee);

        $this->sendProvisioningNotification($employee, $temporaryPassword);

        return response()->json([
            'message' => 'Password berhasil direset.',
            'temporary_password' => $temporaryPassword,
        ]);
    }

    private function sendProvisioningNotification(Employee $employee, string $temporaryPassword): void
    {
        try {
            $employee->notify(new EmployeeAccountProvisioned($temporaryPassword));
        } catch (\Throwable $e) {
            // Don't fail account creation just because mail delivery failed
            // (e.g. no mail server configured yet) — the admin still gets
            // the temporary password back in the API response.
            Log::warning('Gagal mengirim notifikasi akun karyawan: '.$e->getMessage());
        }
    }

    private function generateEmployeeCode(): string
    {
        $next = (Employee::max('id') ?? 0) + 1;

        return 'BBM-'.str_pad((string) $next, 4, '0', STR_PAD_LEFT);
    }
}
