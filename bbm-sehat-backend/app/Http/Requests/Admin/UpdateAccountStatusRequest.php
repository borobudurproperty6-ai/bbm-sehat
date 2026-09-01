<?php

namespace App\Http\Requests\Admin;

use App\Enums\AccountStatus;
use App\Http\Requests\Concerns\HasIndonesianMessages;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/** Authorization is handled by the route's role:super_admin,admin_umum_sdm middleware. */
class UpdateAccountStatusRequest extends FormRequest
{
    use HasIndonesianMessages;

    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        // Rule::in over the enum's own values rather than new Enum(...):
        // behaviorally identical (same accepted/rejected values), but
        // Enum's message() always asks the translator for 'validation.enum'
        // directly — it ignores this FormRequest's messages() entirely, so
        // it can't be localized without touching config('app.locale')
        // (shared with the Flutter app, out of scope here). Rule::in goes
        // through the normal messages() lookup HasIndonesianMessages covers.
        return [
            'account_status' => ['required', Rule::in(array_column(AccountStatus::cases(), 'value'))],
        ];
    }
}
