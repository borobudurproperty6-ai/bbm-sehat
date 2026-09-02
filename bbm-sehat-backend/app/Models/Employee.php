<?php

namespace App\Models;

use App\Enums\AccountStatus;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\HasApiTokens;

/**
 * The authenticatable identity for BBM Sehat. Employees are provisioned by
 * an admin (see Admin\EmployeeController) — there is no public registration.
 *
 * Notifiable is needed for notify()/mail notifications (password reset uses
 * it). Its own notifications() relation (querying Laravel's built-in
 * notifications table shape) is deliberately shadowed by the notifications()
 * method below, which points at BBM Sehat's own `notifications` domain
 * table instead — a class method always wins over a same-named trait
 * method, so this is safe.
 */
class Employee extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable;

    protected $fillable = [
        'employee_code',
        'full_name',
        'email',
        'phone',
        'photo_path',
        'division_id',
        'role_id',
        'is_management',
        'account_status',
        'joined_at',
        'metadata',
        'position_title',
        'password',
        'must_change_password',
    ];

    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected function casts(): array
    {
        return [
            'is_management' => 'boolean',
            'account_status' => AccountStatus::class,
            'must_change_password' => 'boolean',
            'joined_at' => 'date',
            'metadata' => 'array',
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
        ];
    }

    public function division(): BelongsTo
    {
        return $this->belongsTo(Division::class);
    }

    public function role(): BelongsTo
    {
        return $this->belongsTo(Role::class);
    }

    public function devices(): HasMany
    {
        return $this->hasMany(EmployeeDevice::class);
    }

    public function activityLogs(): HasMany
    {
        return $this->hasMany(DailyActivityLog::class);
    }

    public function walkSessions(): HasMany
    {
        return $this->hasMany(WalkSession::class);
    }

    public function pointTransactions(): HasMany
    {
        return $this->hasMany(PointTransaction::class);
    }

    public function badges(): HasMany
    {
        return $this->hasMany(EmployeeBadge::class);
    }

    public function totalPoints(): HasOne
    {
        return $this->hasOne(EmployeeTotalPoint::class);
    }

    public function notifications(): HasMany
    {
        return $this->hasMany(AppNotification::class);
    }

    public function roleCode(): ?string
    {
        return $this->role?->code;
    }

    /**
     * Single place that turns the stored relative path into an actual URL
     * — used by EmployeeResource and every monitoring/leaderboard endpoint
     * that surfaces an employee's photo, so they can't drift out of sync
     * with each other.
     */
    public function photoUrl(): ?string
    {
        return $this->photo_path ? Storage::disk('public')->url($this->photo_path) : null;
    }

    public function canLogIn(): bool
    {
        return $this->account_status === AccountStatus::Active;
    }

    public function isSuperAdmin(): bool
    {
        return $this->roleCode() === 'SUPER_ADMIN';
    }

    public function isManagementRole(): bool
    {
        return $this->roleCode() === 'MANAGEMENT';
    }

    public function isDivisionAdmin(): bool
    {
        return $this->roleCode() === 'DIVISION_ADMIN';
    }

    /**
     * "Pengaturan Pengguna" gate — deliberately narrower than the
     * SUPER_ADMIN role itself, see config('dashboard.*') for why. Shared by
     * EnsureEmployeeIsWhitelistedForUserSettings (route gate) and
     * AdminAuthController::login (post-login redirect target), so the two
     * can never drift apart.
     */
    public function isWhitelistedForUserSettings(): bool
    {
        $allowed = array_map('strtoupper', config('dashboard.user_settings_allowed_employee_codes', []));

        return in_array(strtoupper((string) $this->employee_code), $allowed, true);
    }

    /**
     * Where to land right after login — every role that reaches the
     * dashboard has already passed AuthController::login's role check, but
     * that doesn't mean every one of them has a page: "Pengaturan Pengguna"
     * is only ever open to the user_settings whitelist (see
     * isWhitelistedForUserSettings()), narrower than the SUPER_ADMIN role
     * itself, so a non-whitelisted SUPER_ADMIN falls through to Monitoring
     * like MANAGEMENT/ADMIN_UMUM_SDM do. DIVISION_ADMIN also falls through
     * to Monitoring even though that page's own route middleware
     * (role:management,super_admin,admin_umum_sdm) doesn't include it
     * either — there is currently no dashboard page for Division Admin at
     * all (a separate, already-tracked gap, not something this can paper
     * over); Monitoring is just the closest existing page rather than a
     * route name that doesn't exist.
     *
     * Shared by AuthController::login (post-login redirect target) and
     * DashboardController::gantiPasswordWajib (where to send the employee
     * once they've cleared the mandatory password change), so the two can
     * never drift apart.
     */
    public function dashboardHomeRoute(): string
    {
        if ($this->isSuperAdmin() && $this->isWhitelistedForUserSettings()) {
            return 'dashboard.pengaturan-pengguna';
        }

        return 'dashboard.monitoring.ringkasan';
    }
}
