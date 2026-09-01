<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class PointRule extends Model
{
    use HasFactory;

    public $timestamps = false;

    protected $fillable = [
        'code', 'name', 'description', 'points', 'rule_type',
        'config', 'is_active', 'valid_from', 'valid_to',
    ];

    protected function casts(): array
    {
        return [
            'config' => 'array',
            'is_active' => 'boolean',
            'valid_from' => 'date',
            'valid_to' => 'date',
            'created_at' => 'datetime',
        ];
    }

    public function transactions(): HasMany
    {
        return $this->hasMany(PointTransaction::class);
    }
}
