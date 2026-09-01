<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class EmployeeDevice extends Model
{
    use HasFactory;

    public $timestamps = false;

    protected $fillable = [
        'employee_id', 'platform', 'health_source',
        'permission_granted', 'last_synced_at', 'device_info',
    ];

    protected function casts(): array
    {
        return [
            'permission_granted' => 'boolean',
            'last_synced_at' => 'datetime',
            'device_info' => 'array',
            'created_at' => 'datetime',
        ];
    }

    public function employee(): BelongsTo
    {
        return $this->belongsTo(Employee::class);
    }
}
