<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class DeviceSyncLog extends Model
{
    use HasFactory;

    public $timestamps = false;

    protected $fillable = [
        'employee_id', 'platform', 'sync_status',
        'records_synced', 'error_message',
    ];

    protected function casts(): array
    {
        return ['synced_at' => 'datetime'];
    }

    public function employee(): BelongsTo
    {
        return $this->belongsTo(Employee::class);
    }
}
