<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PointTransaction extends Model
{
    use HasFactory;

    public $timestamps = false;

    protected $fillable = [
        'employee_id', 'point_rule_id', 'points_awarded',
        'reference_date', 'reference_type', 'reference_id', 'notes',
    ];

    protected function casts(): array
    {
        return [
            'reference_date' => 'date',
            'created_at' => 'datetime',
        ];
    }

    public function employee(): BelongsTo
    {
        return $this->belongsTo(Employee::class);
    }

    public function pointRule(): BelongsTo
    {
        return $this->belongsTo(PointRule::class);
    }
}
