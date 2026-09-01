<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Read-only model backed by the `employee_total_points` SQL view
 * (SUM of point_transactions per employee — always live, never stale).
 */
class EmployeeTotalPoint extends Model
{
    protected $table = 'employee_total_points';

    protected $primaryKey = 'employee_id';

    public $incrementing = false;

    public $timestamps = false;

    protected $guarded = ['*'];

    public function employee(): BelongsTo
    {
        return $this->belongsTo(Employee::class);
    }

    public function save(array $options = [])
    {
        throw new \LogicException('employee_total_points is a read-only view.');
    }
}
