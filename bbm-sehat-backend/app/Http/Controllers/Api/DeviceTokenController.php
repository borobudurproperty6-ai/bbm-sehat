<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\RegisterDeviceTokenRequest;
use App\Models\DeviceToken;
use Illuminate\Http\JsonResponse;

class DeviceTokenController extends Controller
{
    /**
     * Upserts by employee_id — re-registering (app reinstall, token
     * refresh, login on the same device) updates the existing row rather
     * than accumulating duplicates.
     *
     * A given device's FCM token is normally the same value on every
     * login, so Eloquent's dirty-checking often finds nothing to save and
     * silently skips both the write and the updated_at bump — touch()
     * forces it regardless, so updated_at reliably reflects "last time
     * this device confirmed it's still active", not just "last time the
     * token string happened to change".
     */
    public function register(RegisterDeviceTokenRequest $request): JsonResponse
    {
        $employee = $request->user();

        $device = DeviceToken::updateOrCreate(
            ['employee_id' => $employee->id],
            ['fcm_token' => $request->string('fcm_token')->toString()],
        );
        $device->touch();

        return response()->json([
            'data' => [
                'employee_id' => $device->employee_id,
                'updated_at' => $device->updated_at,
            ],
        ]);
    }
}
