<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class WalkSession extends Model
{
    use HasFactory;

    protected $fillable = [
        'employee_id', 'started_at', 'ended_at', 'duration_seconds',
        'distance_meters', 'route_polyline', 'start_lat', 'start_lng',
        'end_lat', 'end_lng', 'status', 'source',
    ];

    protected function casts(): array
    {
        return [
            'started_at' => 'datetime',
            'ended_at' => 'datetime',
            'distance_meters' => 'decimal:2',
            'start_lat' => 'decimal:7',
            'start_lng' => 'decimal:7',
            'end_lat' => 'decimal:7',
            'end_lng' => 'decimal:7',
        ];
    }

    public function employee(): BelongsTo
    {
        return $this->belongsTo(Employee::class);
    }
}
