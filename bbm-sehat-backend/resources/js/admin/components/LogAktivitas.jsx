import { useEffect, useState } from 'react';
import { ChevronLeft, ChevronRight } from 'lucide-react';
import { apiFetch } from '../api';

// Matches App\Models\AuditLog::ACTION_* exactly (checked against the model,
// not guessed) — this list only needs to change if a new ACTION_* constant
// is ever added there.
const ACTION_OPTIONS = [
    { value: 'USER_CREATED', label: 'Pengguna Dibuat' },
    { value: 'PASSWORD_RESET', label: 'Password Direset' },
    { value: 'ROLE_CHANGED', label: 'Role Diubah' },
    { value: 'ACCOUNT_STATUS_CHANGED', label: 'Status Akun Diubah' },
    { value: 'LOGIN_SUCCESS', label: 'Login Berhasil' },
    { value: 'LOGIN_FAILED', label: 'Login Gagal' },
];

const ACTION_LABELS = Object.fromEntries(ACTION_OPTIONS.map((o) => [o.value, o.label]));

function formatWhen(iso) {
    return new Date(iso).toLocaleString('id-ID', {
        day: 'numeric',
        month: 'short',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
    });
}

function formatDetails(details) {
    if (!details) return '—';

    return Object.entries(details)
        .map(([key, value]) => `${key}: ${value}`)
        .join(', ');
}

function PersonCell({ person }) {
    if (!person) return <span className="text-bbm-text-muted">—</span>;

    return (
        <div>
            <p className="text-bbm-text">{person.full_name}</p>
            <p className="text-xs text-bbm-text-muted">{person.employee_code}</p>
        </div>
    );
}

export default function LogAktivitas() {
    const [logs, setLogs] = useState([]);
    const [meta, setMeta] = useState(null);
    const [page, setPage] = useState(1);
    const [action, setAction] = useState('');
    const [dateFrom, setDateFrom] = useState('');
    const [dateTo, setDateTo] = useState('');
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);

    useEffect(() => {
        (async () => {
            setLoading(true);
            setError(null);
            try {
                const params = new URLSearchParams({ page: String(page) });
                if (action) params.set('action', action);
                if (dateFrom) params.set('date_from', dateFrom);
                if (dateTo) params.set('date_to', dateTo);

                const result = await apiFetch(`/api/admin/user-settings/audit-logs?${params.toString()}`);
                setLogs(result.data);
                setMeta(result.meta);
            } catch (err) {
                setError(err.message);
            } finally {
                setLoading(false);
            }
        })();
    }, [page, action, dateFrom, dateTo]);

    function handleFilterChange(setter) {
        return (event) => {
            setPage(1);
            setter(event.target.value);
        };
    }

    return (
        <div className="rounded-2xl border border-bbm-border bg-bbm-card shadow-[0_12px_40px_-20px_rgba(0,0,0,0.7)]">
            <div className="flex flex-wrap items-center gap-3 border-b border-bbm-border px-6 py-4">
                <input
                    type="date"
                    value={dateFrom}
                    onChange={handleFilterChange(setDateFrom)}
                    className="rounded-xl border border-bbm-border bg-bbm-bg/80 px-3 py-2 text-sm text-bbm-text outline-none"
                />
                <span className="text-xs text-bbm-text-muted">s/d</span>
                <input
                    type="date"
                    value={dateTo}
                    onChange={handleFilterChange(setDateTo)}
                    className="rounded-xl border border-bbm-border bg-bbm-bg/80 px-3 py-2 text-sm text-bbm-text outline-none"
                />

                <select
                    value={action}
                    onChange={handleFilterChange(setAction)}
                    className="rounded-xl border border-bbm-border bg-bbm-bg/80 px-3 py-2 text-sm text-bbm-text outline-none"
                >
                    <option value="">Semua Jenis Aksi</option>
                    {ACTION_OPTIONS.map((opt) => (
                        <option key={opt.value} value={opt.value}>
                            {opt.label}
                        </option>
                    ))}
                </select>

                {meta && <span className="ml-auto text-xs text-bbm-text-muted">{meta.total} entri</span>}
            </div>

            {error ? (
                <div className="px-6 py-4 text-sm text-red-400">{error}</div>
            ) : loading ? (
                <div className="p-10 text-center text-sm text-bbm-text-muted">Memuat log aktivitas...</div>
            ) : logs.length === 0 ? (
                <div className="p-10 text-center text-sm text-bbm-text-muted">
                    Tidak ada log aktivitas yang cocok dengan filter ini.
                </div>
            ) : (
                <div className="overflow-x-auto">
                    <table className="w-full text-left text-sm">
                        <thead>
                            <tr className="text-xs text-bbm-text-muted">
                                <th className="px-6 py-3 font-medium">Waktu</th>
                                <th className="px-6 py-3 font-medium">Aksi</th>
                                <th className="px-6 py-3 font-medium">Pelaku</th>
                                <th className="px-6 py-3 font-medium">Target</th>
                                <th className="px-6 py-3 font-medium">Detail</th>
                            </tr>
                        </thead>
                        <tbody>
                            {logs.map((log) => (
                                <tr key={log.id} className="border-t border-bbm-border transition hover:bg-white/5">
                                    <td className="px-6 py-3.5 whitespace-nowrap text-bbm-text-muted">
                                        {formatWhen(log.created_at)}
                                    </td>
                                    <td className="px-6 py-3.5">
                                        <span className="inline-flex items-center rounded-full bg-bbm-accent/10 px-2.5 py-1 text-xs font-medium text-bbm-accent">
                                            {ACTION_LABELS[log.action] ?? log.action}
                                        </span>
                                    </td>
                                    <td className="px-6 py-3.5">
                                        <PersonCell person={log.actor} />
                                    </td>
                                    <td className="px-6 py-3.5">
                                        <PersonCell person={log.target} />
                                    </td>
                                    <td className="px-6 py-3.5 text-xs text-bbm-text-muted">
                                        {formatDetails(log.details)}
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                </div>
            )}

            {meta && meta.last_page > 1 && (
                <div className="flex items-center justify-between border-t border-bbm-border px-6 py-4">
                    <button
                        onClick={() => setPage((p) => Math.max(1, p - 1))}
                        disabled={meta.current_page <= 1}
                        className="flex items-center gap-1 rounded-lg border border-bbm-border px-3 py-1.5 text-xs text-bbm-text-muted transition hover:text-bbm-text disabled:opacity-40"
                    >
                        <ChevronLeft size={14} />
                        Sebelumnya
                    </button>
                    <span className="text-xs text-bbm-text-muted">
                        Halaman {meta.current_page} dari {meta.last_page}
                    </span>
                    <button
                        onClick={() => setPage((p) => Math.min(meta.last_page, p + 1))}
                        disabled={meta.current_page >= meta.last_page}
                        className="flex items-center gap-1 rounded-lg border border-bbm-border px-3 py-1.5 text-xs text-bbm-text-muted transition hover:text-bbm-text disabled:opacity-40"
                    >
                        Berikutnya
                        <ChevronRight size={14} />
                    </button>
                </div>
            )}
        </div>
    );
}
