import { useState } from 'react';
import Modal from './Modal';
import { apiFetch } from '../api';

const inputClass =
    'w-full rounded-xl border border-bbm-border bg-bbm-bg/80 px-4 py-2.5 text-sm text-bbm-text outline-none transition focus:border-bbm-accent focus:ring-4 focus:ring-bbm-accent/15';
const labelClass = 'mb-1.5 block text-xs font-medium tracking-wide text-bbm-text-muted uppercase';

function Field({ label, error, children }) {
    return (
        <div>
            <label className={labelClass}>{label}</label>
            {children}
            {error && <p className="mt-1 text-xs text-red-400">{error}</p>}
        </div>
    );
}

/**
 * Shared by "Tambah Pengguna" and "Edit Pengguna" — the backend endpoints
 * behind them (store/update) accept the same field set (see
 * StoreEmployeeRequest / UpdateEmployeeRequest). Neither accepts a
 * password or account_status field: password is always server-generated
 * (surfaced via onCreated's temporaryPassword, same pattern as the
 * dedicated Reset Password action) and status is changed through its own
 * dedicated action — see StatusMenu in ManajemenPengguna.jsx.
 */
export default function EmployeeFormModal({ mode, employee, divisions, roles, currentEmployeeId, onClose, onSaved }) {
    const isEdit = mode === 'edit';
    const isSelf = isEdit && employee.id === currentEmployeeId;

    const [form, setForm] = useState({
        employee_code: employee?.employee_code ?? '',
        full_name: employee?.full_name ?? '',
        email: employee?.email ?? '',
        phone: employee?.phone ?? '',
        division_id: employee?.division?.id ?? '',
        role_id: employee?.role?.id ?? '',
        joined_at: employee?.joined_at ?? '',
    });
    const [errors, setErrors] = useState({});
    const [generalError, setGeneralError] = useState(null);
    const [submitting, setSubmitting] = useState(false);

    function update(field, value) {
        setForm((prev) => ({ ...prev, [field]: value }));
    }

    async function handleSubmit(event) {
        event.preventDefault();
        setErrors({});
        setGeneralError(null);
        setSubmitting(true);

        const payload = {
            employee_code: form.employee_code || null,
            full_name: form.full_name,
            email: form.email,
            phone: form.phone || null,
            division_id: form.division_id ? Number(form.division_id) : null,
            joined_at: form.joined_at || null,
        };

        // role_id is validated as SUPER_ADMIN-only server-side and self
        // role-changes are rejected outright — don't even send it when
        // editing your own record, so an empty/no-op field can't trip that
        // guard by accident.
        if (!isSelf) {
            payload.role_id = form.role_id ? Number(form.role_id) : null;
        }

        try {
            const path = isEdit ? `/api/admin/user-settings/employees/${employee.id}` : '/api/admin/user-settings/employees';
            const method = isEdit ? 'PATCH' : 'POST';

            const result = await apiFetch(path, { method, body: JSON.stringify(payload) });

            onSaved(result.data, result.temporary_password ?? null);
        } catch (err) {
            if (err.status === 422 && err.body?.errors) {
                setErrors(err.body.errors);
            } else {
                setGeneralError(err.message);
            }
            setSubmitting(false);
        }
    }

    return (
        <Modal title={isEdit ? 'Edit Pengguna' : 'Tambah Pengguna'} onClose={onClose} wide>
            <form onSubmit={handleSubmit} className="space-y-4">
                {generalError && (
                    <div className="rounded-xl border border-red-900/60 bg-red-950/40 px-4 py-3 text-sm text-red-300">
                        {generalError}
                    </div>
                )}

                <div className="grid grid-cols-2 gap-4">
                    <Field label="ID Karyawan (opsional)" error={errors.employee_code?.[0]}>
                        <input
                            className={inputClass}
                            placeholder="Auto-generate jika kosong"
                            value={form.employee_code}
                            onChange={(e) => update('employee_code', e.target.value)}
                        />
                    </Field>

                    <Field label="Nama Lengkap" error={errors.full_name?.[0]}>
                        <input
                            className={inputClass}
                            required
                            value={form.full_name}
                            onChange={(e) => update('full_name', e.target.value)}
                        />
                    </Field>
                </div>

                <div className="grid grid-cols-2 gap-4">
                    <Field label="Email" error={errors.email?.[0]}>
                        <input
                            type="email"
                            className={inputClass}
                            required
                            value={form.email}
                            onChange={(e) => update('email', e.target.value)}
                        />
                    </Field>

                    <Field label="Telepon (opsional)" error={errors.phone?.[0]}>
                        <input
                            className={inputClass}
                            value={form.phone}
                            onChange={(e) => update('phone', e.target.value)}
                        />
                    </Field>
                </div>

                <div className="grid grid-cols-2 gap-4">
                    <Field label="Divisi" error={errors.division_id?.[0]}>
                        <select
                            className={inputClass}
                            required
                            value={form.division_id}
                            onChange={(e) => update('division_id', e.target.value)}
                        >
                            <option value="" disabled>
                                Pilih divisi
                            </option>
                            {divisions.map((division) => (
                                <option key={division.id} value={division.id}>
                                    {division.name}
                                </option>
                            ))}
                        </select>
                    </Field>

                    <Field
                        label={isSelf ? 'Role (tidak dapat diubah sendiri)' : 'Role'}
                        error={errors.role_id?.[0]}
                    >
                        <select
                            className={`${inputClass} disabled:cursor-not-allowed disabled:opacity-50`}
                            value={form.role_id}
                            disabled={isSelf}
                            onChange={(e) => update('role_id', e.target.value)}
                        >
                            <option value="">Karyawan (default)</option>
                            {roles.map((role) => (
                                <option key={role.id} value={role.id}>
                                    {role.name}
                                </option>
                            ))}
                        </select>
                    </Field>
                </div>

                <Field label="Tanggal Bergabung (opsional)" error={errors.joined_at?.[0]}>
                    <input
                        type="date"
                        className={inputClass}
                        value={form.joined_at ?? ''}
                        onChange={(e) => update('joined_at', e.target.value)}
                    />
                </Field>

                {!isEdit && (
                    <p className="text-xs text-bbm-text-muted">
                        Password sementara akan dibuat otomatis dan ditampilkan setelah akun berhasil dibuat.
                    </p>
                )}

                <div className="flex justify-end gap-3 pt-2">
                    <button
                        type="button"
                        onClick={onClose}
                        className="rounded-xl border border-bbm-border px-4 py-2 text-sm text-bbm-text-muted transition hover:text-bbm-text"
                    >
                        Batal
                    </button>
                    <button
                        type="submit"
                        disabled={submitting}
                        className="rounded-xl bg-bbm-accent px-5 py-2 text-sm font-semibold text-white shadow-[0_8px_24px_-6px_rgba(99,153,34,0.55)] transition hover:bg-bbm-accent-hover disabled:opacity-60"
                    >
                        {submitting ? 'Menyimpan...' : isEdit ? 'Simpan Perubahan' : 'Tambah Pengguna'}
                    </button>
                </div>
            </form>
        </Modal>
    );
}
