<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Maps to the `notifications` table. Named AppNotification (not
 * Notification) to avoid any confusion with Laravel's own notifications
 * system/facade — this is a plain domain table, not wired to the
 * Notifiable trait or notification channels.
 */
class AppNotification extends Model
{
    use HasFactory;

    protected $table = 'notifications';

    public $timestamps = false;

    protected $fillable = ['employee_id', 'type', 'title', 'body', 'is_read', 'metadata'];

    protected function casts(): array
    {
        return [
            'is_read' => 'boolean',
            'metadata' => 'array',
            'created_at' => 'datetime',
        ];
    }

    public function employee(): BelongsTo
    {
        return $this->belongsTo(Employee::class);
    }
}
