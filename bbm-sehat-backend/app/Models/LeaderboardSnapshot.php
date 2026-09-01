<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class LeaderboardSnapshot extends Model
{
    use HasFactory;

    public $timestamps = false;

    protected $fillable = [
        'period_type', 'period_key', 'scope_type', 'scope_id', 'employee_id',
        'total_points', 'total_steps', 'total_distance_meters', 'rank',
    ];

    protected function casts(): array
    {
        return [
            'total_distance_meters' => 'decimal:2',
            'generated_at' => 'datetime',
        ];
    }

    public function employee(): BelongsTo
    {
        return $this->belongsTo(Employee::class);
    }
}
