<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\AuditLog */
class AuditLogResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'action' => $this->action,
            'actor' => $this->whenLoaded('actor', fn () => $this->actor ? [
                'id' => $this->actor->id,
                'employee_code' => $this->actor->employee_code,
                'full_name' => $this->actor->full_name,
            ] : null),
            'target' => $this->whenLoaded('target', fn () => $this->target ? [
                'id' => $this->target->id,
                'employee_code' => $this->target->employee_code,
                'full_name' => $this->target->full_name,
            ] : null),
            'details' => $this->details,
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
