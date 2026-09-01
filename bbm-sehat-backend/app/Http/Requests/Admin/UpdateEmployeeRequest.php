<?php

namespace App\Http\Requests\Admin;

use App\Http\Requests\Concerns\HasIndonesianMessages;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateEmployeeRequest extends FormRequest
{
    use HasIndonesianMessages;

    public function authorize(): bool
    {
        return (bool) $this->user()?->can('update', $this->route('employee'));
    }

    public function rules(): array
    {
        $employeeId = $this->route('employee')?->id;
        $actor = $this->user();

        $divisionRules = ['sometimes', 'integer', Rule::exists('divisions', 'id')];
        if ($actor && $actor->isDivisionAdmin()) {
            $divisionRules[] = Rule::in([$actor->division_id]);
        }

        return [
            'employee_code' => ['sometimes', 'nullable', 'string', 'max:30', Rule::unique('employees', 'employee_code')->ignore($employeeId)],
            'full_name' => ['sometimes', 'string', 'max:150'],
            'email' => ['sometimes', 'string', 'email', 'max:150', Rule::unique('employees', 'email')->ignore($employeeId)],
            'phone' => ['sometimes', 'nullable', 'string', 'max:30'],
            'division_id' => $divisionRules,
            'role_id' => ['sometimes', 'nullable', 'integer', Rule::exists('roles', 'id')],
            'is_management' => ['sometimes', 'boolean'],
            'joined_at' => ['sometimes', 'nullable', 'date'],
        ];
    }
}
