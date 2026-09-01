<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Division;
use Illuminate\Http\JsonResponse;

class DivisionController extends Controller
{
    public function index(): JsonResponse
    {
        return response()->json([
            'data' => Division::query()->orderBy('name')->get(['id', 'code', 'name', 'description', 'is_active']),
        ]);
    }
}
