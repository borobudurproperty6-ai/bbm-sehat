import { useEffect, useState } from 'react';
import { Building2 } from 'lucide-react';
import DashboardLayout from '../components/DashboardLayout';
import { apiFetch } from '../api';

function formatNumber(n) {
    return new Intl.NumberFormat('id-ID').format(n);
}

function formatDate(dateString) {
    return new Date(`${dateString}T00:00:00`).toLocaleDateString('id-ID', { day: 'numeric', month: 'long' });
}

export default function MonitoringPerDivisi({ employee }) {
    const [period, setPeriod] = useState(null);
    const [divisions, setDivisions] = useState([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);

    useEffect(() => {
        (async () => {
            setLoading(true);
            setError(null);
            try {
                const result = await apiFetch('/api/monitoring/per-divisi');
                setPeriod(result.data.period);
                setDivisions(result.data.divisions);
            } catch (err) {
                setError(err.message);
            } finally {
                setLoading(false);
            }
        })();
    }, []);

    return (
        <DashboardLayout employee={employee}>
            <div className="mb-8">
                <h1 className="text-3xl font-bold tracking-tight text-bbm-text">Per Divisi</h1>
                <p className="mt-1.5 text-sm text-bbm-text-muted">
                    {period
                        ? `Perbandingan divisi periode ${formatDate(period.start)} – ${formatDate(period.end)}, diurutkan berdasarkan rata-rata poin.`
                        : 'Perbandingan statistik antar divisi.'}
                </p>
            </div>

            <div className="rounded-2xl border border-bbm-border bg-bbm-card shadow-[0_12px_40px_-20px_rgba(0,0,0,0.7)]">
                {error ? (
                    <div className="px-6 py-4 text-sm text-red-400">{error}</div>
                ) : loading ? (
                    <div className="p-10 text-center text-sm text-bbm-text-muted">Memuat data divisi...</div>
                ) : divisions.length === 0 ? (
                    <div className="p-10 text-center text-sm text-bbm-text-muted">Belum ada divisi aktif.</div>
                ) : (
                    <div className="overflow-x-auto">
                        <table className="w-full text-left text-sm">
                            <thead>
                                <tr className="text-xs text-bbm-text-muted">
                                    <th className="px-6 py-3 font-medium">Peringkat</th>
                                    <th className="px-6 py-3 font-medium">Divisi</th>
                                    <th className="px-6 py-3 font-medium">Jumlah Karyawan</th>
                                    <th className="px-6 py-3 font-medium">Rata-rata Poin</th>
                                    <th className="px-6 py-3 font-medium">Rata-rata Langkah</th>
                                </tr>
                            </thead>
                            <tbody>
                                {divisions.map((division) => (
                                    <tr
                                        key={division.division_id}
                                        className="border-t border-bbm-border transition hover:bg-white/5"
                                    >
                                        <td className="px-6 py-3.5 text-bbm-text-muted">#{division.rank}</td>
                                        <td className="px-6 py-3.5 font-medium text-bbm-text">
                                            <div className="flex items-center gap-2">
                                                <Building2 size={15} className="text-bbm-accent" />
                                                {division.division_name}
                                            </div>
                                        </td>
                                        <td className="px-6 py-3.5 text-bbm-text-muted">{division.employee_count}</td>
                                        <td className="px-6 py-3.5 text-bbm-text-muted">{division.avg_points}</td>
                                        <td className="px-6 py-3.5 text-bbm-text-muted">
                                            {formatNumber(division.avg_steps)}
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
