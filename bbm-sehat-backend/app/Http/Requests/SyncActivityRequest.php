<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class SyncActivityRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'activity_date' => ['required', 'date', 'before_or_equal:today'],
            // 50,000 steps/day is already an extreme outlier for a real
            // person (~35km on foot) — a sensor glitch or Health Connect
            // aggregation bug is far more likely than a genuine reading
            // above this, so the backend rejects it outright rather than
            // trusting whatever the client (any client, not just this
            // Flutter app) reports.
            'steps' => ['required', 'integer', 'min:0', 'max:50000'],
            'distance_meters' => ['nullable', 'numeric', 'min:0'],
        ];
    }
}
