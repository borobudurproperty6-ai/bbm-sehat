<?php

namespace App\Http\Requests\Concerns;

/**
 * Scoped fix for validation errors leaking raw English ("The full name
 * field is required.") into the otherwise fully Indonesian dashboard UI —
 * see StoreEmployeeRequest/UpdateEmployeeRequest/UpdateAccountStatusRequest/
 * AdminLoginRequest. Deliberately per-FormRequest rather than
 * config('app.locale')/lang/id: that setting is shared with the Flutter
 * mobile app's own FormRequests, so flipping it would translate (and risk
 * breaking) error parsing there too — out of scope here.
 *
 * Only covers the validation rules these four dashboard forms actually use;
 * add a key here if a form starts using a rule not yet listed rather than
 * letting it silently fall back to English.
 *
 * Gotcha: Illuminate\Validation\Rules\Enum ignores this array entirely —
 * its message() asks the translator for 'validation.enum' directly, so it
 * can never be localized this way. Use Rule::in(...) over the enum's own
 * values instead (see UpdateAccountStatusRequest) if a rule set needs to
 * validate against an enum and also get a localized message here.
 */
trait HasIndonesianMessages
{
    public function messages(): array
    {
        return [
            'required' => 'Kolom :attribute wajib diisi.',
            'string' => 'Kolom :attribute harus berupa teks.',
            'max' => 'Kolom :attribute tidak boleh lebih dari :max karakter.',
            'email' => 'Kolom :attribute harus berupa alamat email yang valid.',
            'unique' => ':attribute ini sudah terdaftar.',
            'integer' => 'Kolom :attribute harus berupa angka.',
            'exists' => ':attribute yang dipilih tidak valid.',
            'in' => ':attribute yang dipilih tidak valid.',
            'boolean' => 'Kolom :attribute harus bernilai benar atau salah.',
            'date' => 'Kolom :attribute harus berupa tanggal yang valid.',
        ];
    }

    public function attributes(): array
    {
        return [
            'employee_code' => 'ID karyawan',
            'full_name' => 'nama lengkap',
            'email' => 'email',
            'phone' => 'telepon',
            'division_id' => 'divisi',
            'role_id' => 'role',
            'is_management' => 'status manajemen',
            'joined_at' => 'tanggal bergabung',
            'account_status' => 'status akun',
            'password' => 'kata sandi',
        ];
    }
}
