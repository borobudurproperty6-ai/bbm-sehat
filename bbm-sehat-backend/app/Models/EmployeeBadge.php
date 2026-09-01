<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class EmployeeBadge extends Model
{
    use HasFactory;

    public $timestamps = false;

    protected $fillable = ['employee_id', 'badge_type_id', 'period_key', 'awarded_at', 'reference'];

    protected function casts(): array
    {
        return [
            'awarded_at' => 'datetime',
            'reference' => 'array',
        ];
    }

    public function employee(): BelongsTo
    {
        return $this->belongsTo(Employee::class);
    }

    public function badgeType(): BelongsTo
    {
        return $this->belongsTo(BadgeType::class);
    }
}
