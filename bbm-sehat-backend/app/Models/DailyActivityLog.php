<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class DailyActivityLog extends Model
{
    use HasFactory;

    public $timestamps = false;

    protected $fillable = [
        'employee_id', 'activity_date', 'steps', 'distance_meters',
        'source', 'raw_data', 'synced_at',
    ];

    protected function casts(): array
    {
        return [
            'activity_date' => 'date',
            'distance_meters' => 'decimal:2',
            'raw_data' => 'array',
            'synced_at' => 'datetime',
            'created_at' => 'datetime',
        ];
    }

    public function employee(): BelongsTo
    {
        return $this->belongsTo(Employee::class);
    }
}
