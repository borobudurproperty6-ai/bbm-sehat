<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class UploadProfilePhotoRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            // max is in kilobytes — 2048 KB = 2 MB.
            'photo' => ['required', 'image', 'mimes:jpg,jpeg,png', 'max:2048'],
        ];
    }

    // No other FormRequest in this codebase overrides messages() (every
    // other validation error in the app is Laravel's default English) —
    // added here specifically because the user explicitly asked for a
    // clear error message on this feature. Worth revisiting app-wide later
    // for consistency, not just this one endpoint.
    public function messages(): array
    {
        return [
            'photo.required' => 'Pilih foto terlebih dahulu.',
            'photo.image' => 'File yang dipilih harus berupa gambar.',
            'photo.mimes' => 'Format gambar harus JPG atau PNG.',
            'photo.max' => 'Ukuran gambar maksimal 2MB.',
            // Fires instead of photo.max whenever the file exceeds PHP's
            // own upload_max_filesize ini setting (2M on this server,
            // same as the max:2048 rule above) — PHP rejects it before
            // Laravel's own size rule ever gets a chance to run, so this
            // is the message real-world oversized uploads actually hit.
            'photo.uploaded' => 'Ukuran gambar terlalu besar. Maksimal 2MB.',
        ];
    }
}
