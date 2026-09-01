import { useEffect, useState } from 'react';
import { UserX } from 'lucide-react';
import DashboardLayout from '../components/DashboardLayout';
import StatPill from '../components/StatPill';
import { apiFetch } from '../api';

const DAYS_OPTIONS = [7, 14, 30];

function formatDate(dateString) {
    if (!dateString) return 'Belum pernah aktif';
    return new Date(`${dateString}T00:00:00`).toLocaleDateString('id-ID', { day: 'numeric', month: 'long', year: 'numeric' });
}

export default function MonitoringTidakAktif({ employee }) {
    const [days, setDays] = useState(7);
    const [employees, setEmployees] = useState([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);

    useEffect(() => {
        (async () => {
            setLoading(true);
            setError(null);
            try {
                const result = await apiFetch(`/api/monitoring/tidak-aktif?days=${days}`);
                setEmployees(result.data.employees);
            } catch (err) {
                setError(err.message);
            } finally {
                setLoading(false);
            }
        })();
    }, [days]);

    return (
        <DashboardLayout employee={employee}>
            <div className="mb-8 flex flex-wrap items-center justify-between gap-4">
                <div>
                    <h1 className="text-3xl font-bold tracking-tight text-bbm-text">Karyawan Tidak Aktif</h1>
                    <p className="mt-1.5 text-sm text-bbm-text-muted">
                        Karyawan aktif tanpa aktivitas tercatat dalam periode berikut.
                    </p>
                </div>
                <StatPill icon={UserX} label="Tidak Aktif" value={loading ? undefined : employees.length} />
            </div>

            <div className="mb-6 flex gap-2">
                {DAYS_OPTIONS.map((option) => (
                    <button
                        key={option}
                        onClick={() => setDays(option)}
                        className={`rounded-xl border px-4 py-2 text-sm font-medium transition ${
                            days === option
                                ? 'border-bbm-accent bg-bbm-accent/15 text-bbm-accent'
                                : 'border-bbm-border text-bbm-text-muted hover:text-bbm-text'
                        }`}
                    >
                        {option} hari terakhir
                    </button>
                ))}
            </div>

            <div className="rounded-2xl border border-bbm-border bg-bbm-card shadow-[0_12px_40px_-20px_rgba(0,0,0,0.7)]">
                {error ? (
                    <div className="px-6 py-4 text-sm text-red-400">{error}</div>
                ) : loading ? (
                    <div className="p-10 text-center text-sm text-bbm-text-muted">Memuat data...</div>
                ) : employees.length === 0 ? (
                    <div className="p-10 text-center text-sm text-bbm-text-muted">
                        Tidak ada karyawan yang tidak aktif dalam {days} hari terakhir.
                    </div>
                ) : (
                    <div className="overflow-x-auto">
                        <table className="w-full text-left text-sm">
                            <thead>
                                <tr className="text-xs text-bbm-text-muted">
                                    <th className="px-6 py-3 font-medium">Karyawan</th>
                                    <th className="px-6 py-3 font-medium">ID Karyawan</th>
                                    <th className="px-6 py-3 font-medium">Divisi</th>
                                    <th className="px-6 py-3 font-medium">Terakhir Aktif</th>
                                </tr>
                            </thead>
                            <tbody>
                                {employees.map((emp) => (
                                    <tr key={emp.id} className="border-t border-bbm-border transition hover:bg-white/5">
                                        <td className="px-6 py-3.5">
                                            <div className="flex items-center gap-3">
                                                {emp.photo_url ? (
                                                    <img
                                                        src={emp.photo_url}
                                                        alt={emp.full_name}
                                                        className="h-8 w-8 rounded-full object-cover"
                                                    />
                                                ) : (
                                                    <div className="flex h-8 w-8 items-center justify-center rounded-full bg-bbm-border text-xs font-semibold text-bbm-text-muted">
                                                        {emp.full_name.charAt(0)}
                                                    </div>
                                                )}
                                                <span className="font-medium text-bbm-text">{emp.full_name}</span>
                                            </div>
                                        </td>
                                        <td className="px-6 py-3.5 text-bbm-text-muted">{emp.employee_code}</td>
                                        <td className="px-6 py-3.5 text-bbm-text-muted">{emp.division_name}</td>
                                        <td className="px-6 py-3.5 text-bbm-text-muted">
                                            {formatDate(emp.last_activity_date)}
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </div>
                )}
            </div>
        </DashboardLayout>
    );
}
