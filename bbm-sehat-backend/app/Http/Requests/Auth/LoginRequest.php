<?php

namespace App\Http\Requests\Auth;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Mobile (Flutter) login — issues a Sanctum bearer token. Identifier is the
 * employee's User ID (employees.employee_code, e.g. "BBM-001") — email is
 * not accepted here, since every employee's email is currently a
 * placeholder (@bbm-sehat.local), not a real address they'd remember.
 */
class LoginRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'employee_code' => ['required', 'string', 'max:30'],
            'password' => ['required', 'string'],
            'device_name' => ['nullable', 'string', 'max:100'],
        ];
    }
}
