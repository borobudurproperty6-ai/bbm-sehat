<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\ChangePasswordRequest;
use App\Http\Requests\Auth\ForgotPasswordRequest;
use App\Http\Requests\Auth\LoginRequest;
use App\Http\Requests\Auth\ResetPasswordRequest;
use App\Enums\AccountStatus;
use App\Http\Resources\EmployeeResource;
use App\Models\AuditLog;
use App\Models\Employee;
use App\Services\AuditLogService;
use Illuminate\Auth\Events\PasswordReset;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Password;
use Illuminate\Support\Str;
use Laravel\Sanctum\TransientToken;

class AuthController extends Controller
{
    /**
     * Mobile (Flutter) login. User ID (employees.employee_code) + password
     * -> bearer token. Case-insensitive on the User ID since it's now the
     * only login credential and typing it in lowercase is an easy typo.
     */
    public function login(LoginRequest $request, AuditLogService $auditLog): JsonResponse
    {
        $identifier = $request->string('employee_code')->trim()->toString();

        $employee = Employee::query()
            ->whereRaw('UPPER(employee_code) = ?', [strtoupper($identifier)])
            ->first();

        if (! $employee || ! Hash::check($request->string('password'), $employee->password)) {
            $auditLog->log(AuditLog::ACTION_LOGIN_FAILED, null, $employee, [
                'identifier' => $identifier,
                'guard' => 'mobile',
            ]);

            return response()->json([
                'message' => 'ID Karyawan atau kata sandi salah.',
            ], 401);
        }

        if (! $employee->canLogIn()) {
            $auditLog->log(AuditLog::ACTION_LOGIN_FAILED, null, $employee, [
                'identifier' => $identifier,
                'guard' => 'mobile',
                'reason' => 'account_'.$employee->account_status->value,
            ]);

            return response()->json([
                'message' => $employee->account_status === AccountStatus::Archived
                    ? 'Akun ini sudah diarsipkan (karyawan resign). Hubungi admin SDM/IT.'
                    : 'Akun ini sudah tidak aktif. Hubungi admin SDM/IT.',
            ], 403);
        }

        $token = $employee->createToken(
            $request->string('device_name')->toString() ?: 'mobile-device'
        )->plainTextToken;

        $auditLog->log(AuditLog::ACTION_LOGIN_SUCCESS, $employee, $employee, ['guard' => 'mobile']);

        return response()->json([
            'token' => $token,
            'must_change_password' => $employee->must_change_password,
            'employee' => new EmployeeResource($employee->load(['division', 'role'])),
        ]);
    }

    /**
     * Works for both the mobile bearer-token session and the dashboard
     * cookie session — Sanctum represents the latter as a TransientToken,
     * which isn't a real row to delete, so it needs the web-guard logout
     * path instead.
     */
    public function logout(Request $request): JsonResponse
    {
        $token = $request->user()?->currentAccessToken();

        if ($token instanceof TransientToken) {
            Auth::guard('web')->logout();
            $request->session()->invalidate();
            $request->session()->regenerateToken();
        } else {
            $token?->delete();
        }

        return response()->json(['message' => 'Berhasil keluar.']);
    }

    public function me(Request $request): EmployeeResource
    {
        return new EmployeeResource($request->user()->load(['division', 'role']));
    }

    public function forgotPassword(ForgotPasswordRequest $request): JsonResponse
    {
        Password::broker('employees')->sendResetLink(
            $request->only('email')
        );

        // Always respond the same way regardless of whether the email
        // exists, so this endpoint can't be used to enumerate accounts.
        return response()->json([
            'message' => 'Jika email terdaftar, tautan/kode reset telah dikirim.',
        ]);
    }

    public function resetPassword(ResetPasswordRequest $request): JsonResponse
    {
        $status = Password::broker('employees')->reset(
            $request->only('email', 'password', 'password_confirmation', 'token'),
            function (Employee $employee, string $password) {
                $employee->forceFill([
                    'password' => $password,
                    'must_change_password' => false,
                    'remember_token' => Str::random(60),
                ])->save();

                event(new PasswordReset($employee));
            }
        );

        if ($status !== Password::PASSWORD_RESET) {
            return response()->json([
                'message' => 'Kode reset tidak valid atau sudah kedaluwarsa.',
            ], 422);
        }

        return response()->json(['message' => 'Password berhasil diubah. Silakan masuk kembali.']);
    }

    /**
     * Used both for a normal password change and for the mandatory
     * first-login change (must_change_password=true) — current_password is
     * always required so a stolen session/token alone isn't enough.
     */
    public function changePassword(ChangePasswordRequest $request): JsonResponse
    {
        $employee = $request->user();

        if (! Hash::check($request->string('current_password'), $employee->password)) {
            return response()->json([
                'message' => 'Password saat ini salah.',
            ], 422);
        }

        $employee->forceFill([
            'password' => $request->string('password')->toString(),
            'must_change_password' => false,
        ])->save();

        return response()->json(['message' => 'Password berhasil diubah.']);
    }
}
