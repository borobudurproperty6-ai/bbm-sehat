<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Support\RbacMatrixBuilder;
use Illuminate\Http\JsonResponse;

class RbacMatrixController extends Controller
{
    public function index(RbacMatrixBuilder $builder): JsonResponse
    {
        return response()->json(['data' => $builder->build()]);
    }
}
