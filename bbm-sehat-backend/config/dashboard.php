<?php

return [

    /*
    |--------------------------------------------------------------------------
    | "Pengaturan Pengguna" allowed employee codes
    |--------------------------------------------------------------------------
    |
    | Deliberately narrower than the SUPER_ADMIN role itself: this page and
    | its API endpoints are restricted to these two specific people (Farhan,
    | Gofar), not every account that happens to hold the SUPER_ADMIN role
    | (e.g. the generic "Super Admin" seed account, BBM-0001, must NOT get
    | in via this list even though its role passes role:super_admin).
    |
    | Enforced by EnsureEmployeeIsWhitelistedForUserSettings, stacked
    | alongside (not instead of) the ordinary `role:super_admin` middleware
    | — see routes/web.php and routes/api.php. To grant a new Super Admin
    | access to this page, add their employee_code here; nothing else needs
    | to change.
    |
    */
    'user_settings_allowed_employee_codes' => [
        'BBM-005', // Farhan
        'BBM-006', // Gofar
    ],

];
