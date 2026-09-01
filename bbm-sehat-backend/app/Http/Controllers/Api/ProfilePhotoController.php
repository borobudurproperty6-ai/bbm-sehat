<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\UploadProfilePhotoRequest;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Throwable;

class ProfilePhotoController extends Controller
{
    /**
     * Stores the new photo and updates the employee's row first, THEN
     * deletes the old file — so a failure partway through never leaves the
     * employee without any photo on disk while the DB still points at one.
     */
    public function upload(UploadProfilePhotoRequest $request): JsonResponse
    {
        $employee = $request->user();
        $oldPath = $employee->photo_path;

        $file = $request->file('photo');
        // employee_id + timestamp alone can collide if the same employee
        // uploads twice within the same second (e.g. immediately re-picks
        // after disliking the first result) — the random suffix guarantees
        // uniqueness regardless.
        $filename = $employee->id.'_'.now()->timestamp.'_'.Str::random(6).'.'.$file->getClientOriginalExtension();
        $path = $file->storeAs('profile-photos', $filename, 'public');

        $employee->forceFill(['photo_path' => $path])->save();

        // By this point the upload has already fully succeeded (new file
        // on disk, DB pointing at it) — cleaning up the old file is
        // best-effort housekeeping, not something that should turn a
        // successful upload into an error response if it fails.
        if ($oldPath) {
            try {
                if (Storage::disk('public')->exists($oldPath)) {
                    Storage::disk('public')->delete($oldPath);
                }
            } catch (Throwable $e) {
                Log::warning('Failed to delete old profile photo.', [
                    'employee_id' => $employee->id,
                    'old_path' => $oldPath,
                    'error' => $e->getMessage(),
                ]);
            }
        }

        return response()->json([
            'data' => [
                'photo_url' => Storage::disk('public')->url($path),
            ],
        ]);
    }
}
