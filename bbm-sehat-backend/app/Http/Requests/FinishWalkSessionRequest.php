<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class FinishWalkSessionRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'end_lat' => ['required', 'numeric', 'between:-90,90'],
            'end_lng' => ['required', 'numeric', 'between:-180,180'],
            'duration_seconds' => ['required', 'integer', 'min:0'],
            'points' => ['required', 'array', 'min:2'],
            'points.*.lat' => ['required', 'numeric', 'between:-90,90'],
            'points.*.lng' => ['required', 'numeric', 'between:-180,180'],
            // Needed to reject GPS jump/speed noise server-side (see
            // WalkSessionService::isGpsNoise) — without a real fix time per
            // point there's no way to tell "teleported" from "ran fast".
            'points.*.timestamp' => ['required', 'date'],
        ];
    }
}
