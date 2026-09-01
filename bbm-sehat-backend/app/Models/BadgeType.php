<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class BadgeType extends Model
{
    use HasFactory;

    public $timestamps = false;

    protected $fillable = [
        'code', 'name', 'description', 'icon_url', 'criteria', 'is_active',
    ];

    protected function casts(): array
    {
        return [
            'criteria' => 'array',
            'is_active' => 'boolean',
            'created_at' => 'datetime',
        ];
    }

    public function employeeBadges(): HasMany
    {
        return $this->hasMany(EmployeeBadge::class);
    }
}
