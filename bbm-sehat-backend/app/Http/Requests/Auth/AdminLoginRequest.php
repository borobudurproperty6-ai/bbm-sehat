<?php

namespace App\Http\Requests\Auth;

use App\Http\Requests\Concerns\HasIndonesianMessages;
use Illuminate\Foundation\Http\FormRequest;

/** Dashboard (React SPA) login — establishes a Sanctum session cookie. */
class AdminLoginRequest extends FormRequest
{
    use HasIndonesianMessages;

    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'email' => ['required', 'string', 'email'],
            'password' => ['required', 'string'],
        ];
    }
}
