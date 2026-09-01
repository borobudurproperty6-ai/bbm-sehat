<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\AuditLogResource;
use App\Models\AuditLog;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class AuditLogController extends Controller
{
    /**
     * SUPER_ADMIN-only (see routes/api.php). Newest first, optionally
     * filtered by action, the employee affected, and/or a date range
     * (date_from/date_to, inclusive on both ends — compared on the date
     * portion of created_at only, so a picker doesn't need to account for
     * time-of-day).
     */
    public function index(Request $request): AnonymousResourceCollection
    {
        $query = AuditLog::query()->with(['actor', 'target'])->latest('created_at');

        if ($request->filled('action')) {
            $query->where('action', $request->string('action')->upper());
        }

        if ($request->filled('target_employee_id')) {
            $query->where('target_employee_id', $request->integer('target_employee_id'));
        }

        if ($request->filled('date_from')) {
            $query->whereDate('created_at', '>=', $request->date('date_from'));
        }

        if ($request->filled('date_to')) {
            $query->whereDate('created_at', '<=', $request->date('date_to'));
        }

        return AuditLogResource::collection($query->paginate(25));
    }
}
