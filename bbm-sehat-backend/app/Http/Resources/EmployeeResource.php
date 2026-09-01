<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\Employee */
class EmployeeResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'employee_code' => $this->employee_code,
            'full_name' => $this->full_name,
            'email' => $this->email,
            'phone' => $this->phone,
            'photo_url' => $this->photoUrl(),
            'position_title' => $this->position_title,
            'division' => $this->whenLoaded('division', fn () => [
                'id' => $this->division->id,
                'code' => $this->division->code,
                'name' => $this->division->name,
            ]),
            'role' => $this->whenLoaded('role', fn () => [
                'id' => $this->role->id,
                'code' => $this->role->code,
                'name' => $this->role->name,
            ]),
            'is_management' => $this->is_management,
            'account_status' => $this->account_status->value,
            'must_change_password' => $this->must_change_password,
            'joined_at' => $this->joined_at?->toDateString(),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
