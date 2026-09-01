import { useEffect, useState } from 'react';
import { Search, ChevronLeft, ChevronRight, Flame } from 'lucide-react';
import DashboardLayout from '../components/DashboardLayout';
import { apiFetch } from '../api';

const SORT_OPTIONS = [
    { value: 'poin', label: 'Poin' },
    { value: 'langkah_minggu_ini', label: 'Langkah Minggu Ini' },
    { value: 'nama', label: 'Nama' },
    { value: 'divisi', label: 'Divisi' },
];

function formatNumber(n) {
    return new Intl.NumberFormat('id-ID').format(n);
}

export default function MonitoringProgresKaryawan({ employee }) {
    const [search, setSearch] = useState('');
    const [debouncedSearch, setDebouncedSearch] = useState('');
    const [sortBy, setSortBy] = useState('poin');
    const [divisionId, setDivisionId] = useState('');
    const [divisions, setDivisions] = useState([]);
    const [page, setPage] = useState(1);

    const [employees, setEmployees] = useState([]);
    const [meta, setMeta] = useState(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);

    // /api/monitoring/per-divisi already lists every active division —
    // reused here for the filter dropdown instead of adding a new endpoint.
    useEffect(() => {
        (async () => {
            try {
                const result = await apiFetch('/api/monitoring/per-divisi');
                setDivisions(result.data.divisions);
            } catch {
                // Non-fatal — the division filter just stays empty; the main table fetch below surfaces real errors.
            }
        })();
    }, []);

    useEffect(() => {
        const timer = setTimeout(() => {
            setDebouncedSearch(search);
            setPage(1);
        }, 300);

        return () => clearTimeout(timer);
    }, [search]);

    useEffect(() => {
        setPage(1);
    }, [sortBy, divisionId]);

    useEffect(() => {
        (async () => {
            setLoading(true);
            setError(null);
            try {
                const params = new URLSearchParams({ sort_by: sortBy, page: String(page), per_page: '20' });
                if (debouncedSearch) params.set('search', debouncedSearch);
                if (divisionId) params.set('divisi', divisionId);

                const result = await apiFetch(`/api/monitoring/employees?${params.toString()}`);
                setEmployees(result.data);
                setMeta(result.meta);
            } catch (err) {
                setError(err.message);
            } finally {
                setLoading(false);
            }
        })();
    }, [debouncedSearch, sortBy, divisionId, page]);

    return (
        <DashboardLayout employee={employee}>
            <div className="mb-8">
                <h1 className="text-3xl font-bold tracking-tight text-bbm-text">Progres Karyawan</h1>
                <p className="mt-1.5 text-sm text-bbm-text-muted">
                    Daftar lengkap poin dan aktivitas seluruh karyawan aktif.
                </p>
            </div>

            <div className="rounded-2xl border border-bbm-border bg-bbm-card shadow-[0_12px_40px_-20px_rgba(0,0,0,0.7)]">
                <div className="flex flex-wrap items-center gap-3 border-b border-bbm-border px-6 py-4">
                    <div className="relative min-w-[200px] flex-1">
                        <Search
                            size={14}
                            className="pointer-events-none absolute top-1/2 left-3 -translate-y-1/2 text-bbm-text-muted"
                        />
                        <input
                            value={search}
                            onChange={(e) => setSearch(e.target.value)}
                            placeholder="Cari nama karyawan..."
                            className="w-full rounded-xl border border-bbm-border bg-bbm-bg/80 py-2 pr-3 pl-9 text-sm text-bbm-text outline-none transition focus:border-bbm-accent focus:ring-4 focus:ring-bbm-accent/15"
                        />
                    </div>

                    <select
                        value={sortBy}
                        onChange={(e) => setSortBy(e.target.value)}
                        className="rounded-xl border border-bbm-border bg-bbm-bg/80 px-3 py-2 text-sm text-bbm-text outline-none"
                    >
                        {SORT_OPTIONS.map((opt) => (
                            <option key={opt.value} value={opt.value}>
                                Urutkan: {opt.label}
                            </option>
                        ))}
                    </select>

                    <select
                        value={divisionId}
                        onChange={(e) => setDivisionId(e.target.value)}
                        className="rounded-xl border border-bbm-border bg-bbm-bg/80 px-3 py-2 text-sm text-bbm-text outline-none"
                    >
                        <option value="">Semua Divisi</option>
                        {divisions.map((division) => (
                            <option key={division.division_id} value={division.division_id}>
                                {division.division_name}
                            </option>
                        ))}
                    </select>
                </div>

                {error ? (
                    <div className="px-6 py-4 text-sm text-red-400">{error}</div>
                ) : loading ? (
                    <div className="p-10 text-center text-sm text-bbm-text-muted">Memuat data karyawan...</div>
                ) : employees.length === 0 ? (
                    <div className="p-10 text-center text-sm text-bbm-text-muted">
                        Tidak ada karyawan yang cocok dengan filter ini.
                    </div>
                ) : (
                    <div className="overflow-x-auto">
                        <table className="w-full text-left text-sm">
                            <thead>
                                <tr className="text-xs text-bbm-text-muted">
                                    <th className="px-6 py-3 font-medium">Karyawan</th>
                                    <th className="px-6 py-3 font-medium">ID Karyawan</th>
                                    <th className="px-6 py-3 font-medium">Divisi</th>
                                    <th className="px-6 py-3 font-medium">Poin</th>
                                    <th className="px-6 py-3 font-medium">Langkah Minggu Ini</th>
                                    <th className="px-6 py-3 font-medium">Streak</th>
                                    <th className="px-6 py-3 font-medium">Status</th>
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
                                        <td className="px-6 py-3.5 font-semibold text-bbm-text">
                                            {formatNumber(emp.total_points)}
                                        </td>
                                        <td className="px-6 py-3.5 text-bbm-text-muted">
                                            {formatNumber(emp.steps_this_week)}
                                        </td>
                                        <td className="px-6 py-3.5 text-bbm-text-muted">
                                            {emp.current_streak_days > 0 ? (
                                                <span className="inline-flex items-center gap-1">
                                                    <Flame size={13} className="text-amber-400" />
                                                    {emp.current_streak_days} hari
                                                </span>
                                            ) : (
                                                '–'
                                            )}
                                        </td>
                                        <td className="px-6 py-3.5">
                                            <span
                                                className={`inline-flex items-center rounded-full px-2.5 py-1 text-xs font-medium ${
                                                    emp.is_active_recently
                                                        ? 'bg-bbm-accent/15 text-bbm-accent ring-1 ring-bbm-accent/30'
                                                        : 'bg-zinc-500/15 text-zinc-300 ring-1 ring-zinc-500/30'
                                                }`}
                                            >
                                                {emp.is_active_recently ? 'Aktif' : 'Tidak Aktif'}
                                            </span>
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </div>
                )}

                {meta && meta.last_page > 1 && (
                    <div className="flex items-center justify-between border-t border-bbm-border px-6 py-4">
                        <p className="text-xs text-bbm-text-muted">
                            Halaman {meta.current_page} dari {meta.last_page} ({meta.total} karyawan)
                        </p>
                        <div className="flex gap-2">
                            <button
                                onClick={() => setPage((p) => Math.max(1, p - 1))}
                                disabled={meta.current_page <= 1}
                                className="flex items-center gap-1 rounded-xl border border-bbm-border px-3 py-1.5 text-xs text-bbm-text-muted transition hover:text-bbm-text disabled:cursor-not-allowed disabled:opacity-40"
                            >
                                <ChevronLeft size={14} />
                                Sebelumnya
                            </button>
                            <button
                                onClick={() => setPage((p) => Math.min(meta.last_page, p + 1))}
                                disabled={meta.current_page >= meta.last_page}
                                className="flex items-center gap-1 rounded-xl border border-bbm-border px-3 py-1.5 text-xs text-bbm-text-muted transition hover:text-bbm-text disabled:cursor-not-allowed disabled:opacity-40"
                            >
                                Selanjutnya
                                <ChevronRight size={14} />
                            </button>
                        </div>
                    </div>
                )}
            </div>
        </DashboardLayout>
    );
}
