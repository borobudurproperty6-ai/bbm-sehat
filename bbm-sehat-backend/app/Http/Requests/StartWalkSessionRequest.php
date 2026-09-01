<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class StartWalkSessionRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'start_lat' => ['required', 'numeric', 'between:-90,90'],
            'start_lng' => ['required', 'numeric', 'between:-180,180'],
        ];
    }
}
