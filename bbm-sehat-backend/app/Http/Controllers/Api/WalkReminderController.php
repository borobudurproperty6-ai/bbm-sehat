<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\WalkReminderService;
use Illuminate\Http\JsonResponse;

class WalkReminderController extends Controller
{
    public function __construct(private readonly WalkReminderService $reminders) {}

    public function send(): JsonResponse
    {
        return response()->json(['data' => $this->reminders->sendToEmployeesBelowTarget()]);
    }
}
