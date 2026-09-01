<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Role extends Model
{
    use HasFactory;

    public $timestamps = false;

    protected $fillable = ['code', 'name', 'permissions'];

    protected function casts(): array
    {
        return [
            'permissions' => 'array',
            'created_at' => 'datetime',
        ];
    }

    public function employees(): HasMany
    {
        return $this->hasMany(Employee::class);
    }
}
