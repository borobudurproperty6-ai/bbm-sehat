<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AppSetting extends Model
{
    use HasFactory;

    public $timestamps = false;

    protected $fillable = ['key', 'value', 'description', 'updated_by'];

    protected function casts(): array
    {
        return [
            'value' => 'array',
            'updated_at' => 'datetime',
        ];
    }

    public function updater(): BelongsTo
    {
        return $this->belongsTo(Employee::class, 'updated_by');
    }
}
