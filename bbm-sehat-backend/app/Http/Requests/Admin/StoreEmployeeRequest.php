<?php

namespace App\Http\Requests\Admin;

use App\Http\Requests\Concerns\HasIndonesianMessages;
use App\Models\Employee;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreEmployeeRequest extends FormRequest
{
    use HasIndonesianMessages;

    public function authorize(): bool
    {
        return (bool) $this->user()?->can('create', Employee::class);
    }

    public function rules(): array
    {
        $actor = $this->user();

        $divisionRules = ['required', 'integer', Rule::exists('divisions', 'id')];
        if ($actor && $actor->isDivisionAdmin()) {
            // Division Admins may only create employees in their own division.
            $divisionRules[] = Rule::in([$actor->division_id]);
        }

        return [
            'employee_code' => ['nullable', 'string', 'max:30', 'unique:employees,employee_code'],
            'full_name' => ['required', 'string', 'max:150'],
            'email' => ['required', 'string', 'email', 'max:150', 'unique:employees,email'],
            'phone' => ['nullable', 'string', 'max:30'],
            'division_id' => $divisionRules,
            'role_id' => ['nullable', 'integer', Rule::exists('roles', 'id')],
            'is_management' => ['nullable', 'boolean'],
            'joined_at' => ['nullable', 'date'],
        ];
    }
}
