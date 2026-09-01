import { useMemo, useState } from 'react';
import { UserPlus, KeyRound, Pencil, Search } from 'lucide-react';
import { RoleBadge, StatusBadge } from './Badge';
import EmployeeFormModal from './EmployeeFormModal';
import TemporaryPasswordModal from './TemporaryPasswordModal';
import ConfirmDialog from './ConfirmDialog';
import Toast from './Toast';
import { apiFetch } from '../api';

const STATUS_OPTIONS = [
    { value: 'active', label: 'Aktif' },
    { value: 'inactive', label: 'Nonaktif' },
    { value: 'archived', label: 'Diarsipkan' },
];

export default function ManajemenPengguna({ employees, divisions, roles, currentEmployeeId, loading, error, onRefetch }) {
    const [formModal, setFormModal] = useState(null); // { mode: 'create' | 'edit', employee? }
    const [resetTarget, setResetTarget] = useState(null);
    const [resetting, setResetting] = useState(false);
    const [tempPassword, setTempPassword] = useState(null); // { name, password }
    const [statusChangingId, setStatusChangingId] = useState(null);
    const [toast, setToast] = useState(null);

    const [search, setSearch] = useState('');
    const [roleFilter, setRoleFilter] = useState('');
    const [divisionFilter, setDivisionFilter] = useState('');

    function showToast(type, message) {
        setToast({ type, message });
    }

    // Client-side — all 48 employees are already loaded in full (see
    // fetchAllEmployees in PengaturanPengguna.jsx), and at that scale
    // filtering in the browser is instant. Worth moving server-side (query
    // params + re-fetch) if the roster grows enough that loading everyone
    // up front stops being cheap — not the case today.
    const filteredEmployees = useMemo(() => {
        const query = search.trim().toLowerCase();

        return employees.filter((employee) => {
            if (roleFilter && employee.role?.code !== roleFilter) return false;
            if (divisionFilter && String(employee.division?.id) !== divisionFilter) return false;

            if (query) {
                const haystack = `${employee.full_name} ${employee.employee_code ?? ''}`.toLowerCase();
                if (!haystack.includes(query)) return false;
            }

            return true;
        });
    }, [employees, search, roleFilter, divisionFilter]);

    async function handleStatusChange(employee, newStatus) {
        if (newStatus === employee.account_status) return;

        setStatusChangingId(employee.id);
        try {
            await apiFetch(`/api/admin/user-settings/employees/${employee.id}/account-status`, {
                method: 'PATCH',
                body: JSON.stringify({ account_status: newStatus }),
            });
            showToast('success', `Status ${employee.full_name} berhasil diubah.`);
            onRefetch();
        } catch (err) {
            showToast('error', err.message);
        } finally {
            setStatusChangingId(null);
        }
    }

    async function handleConfirmReset() {
        setResetting(true);
        try {
            const result = await apiFetch(`/api/admin/user-settings/employees/${resetTarget.id}/reset-password`, {
                method: 'POST',
            });
            setTempPassword({
                id: resetTarget.id,
                name: resetTarget.full_name,
                code: resetTarget.employee_code,
                password: result.temporary_password,
            });
            setResetTarget(null);
        } catch (err) {
            showToast('error', err.message);
        } finally {
            setResetting(false);
        }
    }

    function handleSaved(_employee, temporaryPassword) {
        const wasCreate = formModal.mode === 'create';
        setFormModal(null);
        onRefetch();

        if (wasCreate && temporaryPassword) {
            setTempPassword({
                id: _employee.id,
                name: _employee.full_name,
                code: _employee.employee_code,
                password: temporaryPassword,
            });
        } else {
            showToast('success', wasCreate ? 'Pengguna berhasil ditambahkan.' : 'Perubahan berhasil disimpan.');
        }
    }

    return (
        <div className="rounded-2xl border border-bbm-border bg-bbm-card shadow-[0_12px_40px_-20px_rgba(0,0,0,0.7)]">
            <div className="flex items-center justify-between border-b border-bbm-border px-6 py-4">
                <div>
                    <p className="text-sm font-medium text-bbm-text">Daftar Pengguna</p>
                    <p className="text-xs text-bbm-text-muted">
                        {filteredEmployees.length} dari {employees.length} pengguna
                    </p>
                </div>
                <button
                    onClick={() => setFormModal({ mode: 'create' })}
                    className="flex items-center gap-2 rounded-xl bg-bbm-accent px-4 py-2 text-sm font-semibold text-white shadow-[0_8px_20px_-6px_rgba(99,153,34,0.55)] transition hover:bg-bbm-accent-hover"
                >
                    <UserPlus size={15} />
                    Tambah Pengguna
                </button>
            </div>

            <div className="flex flex-wrap items-center gap-3 border-b border-bbm-border px-6 py-4">
                <div className="relative flex-1 min-w-[200px]">
                    <Search size={14} className="pointer-events-none absolute top-1/2 left-3 -translate-y-1/2 text-bbm-text-muted" />
                    <input
                        value={search}
                        onChange={(e) => setSearch(e.target.value)}
                        placeholder="Cari nama atau ID karyawan..."
                        className="w-full rounded-xl border border-bbm-border bg-bbm-bg/80 py-2 pr-3 pl-9 text-sm text-bbm-text outline-none transition focus:border-bbm-accent focus:ring-4 focus:ring-bbm-accent/15"
                    />
                </div>

                <select
                    value={roleFilter}
                    onChange={(e) => setRoleFilter(e.target.value)}
                    className="rounded-xl border border-bbm-border bg-bbm-bg/80 px-3 py-2 text-sm text-bbm-text outline-none"
                >
                    <option value="">Semua Role</option>
                    {roles.map((role) => (
                        <option key={role.id} value={role.code}>
                            {role.name}
                        </option>
                    ))}
                </select>

                <select
                    value={divisionFilter}
                    onChange={(e) => setDivisionFilter(e.target.value)}
                    className="rounded-xl border border-bbm-border bg-bbm-bg/80 px-3 py-2 text-sm text-bbm-text outline-none"
                >
                    <option value="">Semua Divisi</option>
                    {divisions.map((division) => (
                        <option key={division.id} value={division.id}>
                            {division.name}
                        </option>
                    ))}
                </select>
            </div>

            {error ? (
                <div className="px-6 py-4 text-sm text-red-400">{error}</div>
            ) : loading ? (
                <div className="p-10 text-center text-sm text-bbm-text-muted">Memuat data pengguna...</div>
            ) : filteredEmployees.length === 0 ? (
                <div className="p-10 text-center text-sm text-bbm-text-muted">
                    Tidak ada pengguna yang cocok dengan filter ini.
                </div>
            ) : (
                <div className="overflow-x-auto">
                    <table className="w-full text-left text-sm">
                        <thead>
                            <tr className="text-xs text-bbm-text-muted">
                                <th className="px-6 py-3 font-medium">ID Karyawan</th>
                                <th className="px-6 py-3 font-medium">Nama</th>
                                <th className="px-6 py-3 font-medium">Role</th>
                                <th className="px-6 py-3 font-medium">Status</th>
                                <th className="px-6 py-3 font-medium">Aksi</th>
                            </tr>
                        </thead>
                        <tbody>
                            {filteredEmployees.map((employee) => {
                                const isSelf = employee.id === currentEmployeeId;

                                return (
                                    <tr key={employee.id} className="border-t border-bbm-border transition hover:bg-white/5">
                                        <td className="px-6 py-3.5 text-bbm-text-muted">{employee.employee_code}</td>
                                        <td className="px-6 py-3.5 font-medium text-bbm-text">
                                            {employee.full_name}
                                            {isSelf && <span className="ml-2 text-xs text-bbm-text-muted">(Anda)</span>}
                                        </td>
                                        <td className="px-6 py-3.5">
                                            <RoleBadge role={employee.role?.code} />
                                        </td>
                                        <td className="px-6 py-3.5">
                                            <div className="flex items-center gap-2">
                                                <StatusBadge status={employee.account_status} />
                                                {!isSelf && (
                                                    <select
                                                        value={employee.account_status}
                                                        disabled={statusChangingId === employee.id}
                                                        onChange={(e) => handleStatusChange(employee, e.target.value)}
                                                        className="rounded-lg border border-bbm-border bg-bbm-bg/80 px-2 py-1 text-xs text-bbm-text-muted outline-none disabled:opacity-50"
                                                        title="Ubah status akun"
                                                    >
                                                        {STATUS_OPTIONS.map((opt) => (
                                                            <option key={opt.value} value={opt.value}>
                                                                {opt.label}
                                                            </option>
                                                        ))}
                                                    </select>
                                                )}
                                            </div>
                                        </td>
                                        <td className="px-6 py-3.5">
                                            <div className="flex items-center gap-3">
                                                <button
                                                    onClick={() => setFormModal({ mode: 'edit', employee })}
                                                    className="flex items-center gap-1.5 text-xs text-bbm-text-muted transition hover:text-bbm-accent"
                                                >
                                                    <Pencil size={13} />
                                                    Edit
                                                </button>
                                                {!isSelf && (
                                                    <button
                                                        onClick={() => setResetTarget(employee)}
                                                        className="flex items-center gap-1.5 text-xs text-bbm-text-muted transition hover:text-bbm-accent"
                                                    >
                                                        <KeyRound size={13} />
                                                        Reset Password
                                                    </button>
                                                )}
                                            </div>
                                        </td>
                                    </tr>
                                );
                            })}
                        </tbody>
                    </table>
                </div>
            )}

            {formModal && (
                <EmployeeFormModal
                    mode={formModal.mode}
                    employee={formModal.employee}
                    divisions={divisions}
                    roles={roles}
                    currentEmployeeId={currentEmployeeId}
                    onClose={() => setFormModal(null)}
                    onSaved={handleSaved}
                />
            )}

            {resetTarget && (
                <ConfirmDialog
                    title="Reset Password"
                    message={`Reset password untuk ${resetTarget.full_name}? Password lama akan langsung tidak berlaku.`}
                    confirmLabel="Ya, Reset"
                    busy={resetting}
                    onConfirm={handleConfirmReset}
                    onCancel={() => setResetTarget(null)}
                />
            )}

            {tempPassword && (
                <TemporaryPasswordModal
                    employeeId={tempPassword.id}
                    employeeName={tempPassword.name}
                    employeeCode={tempPassword.code}
                    password={tempPassword.password}
                    onClose={() => setTempPassword(null)}
                />
            )}

            <Toast toast={toast} onDismiss={() => setToast(null)} />
        </div>
    );
}
