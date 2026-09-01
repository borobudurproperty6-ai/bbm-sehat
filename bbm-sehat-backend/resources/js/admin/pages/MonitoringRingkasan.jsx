import { useEffect, useState } from 'react';
import { Users, Activity, Footprints, Route } from 'lucide-react';
import DashboardLayout from '../components/DashboardLayout';
import StatPill from '../components/StatPill';
import { apiFetch } from '../api';

function formatNumber(n) {
    return new Intl.NumberFormat('id-ID').format(n);
}

function formatDate(dateString) {
    return new Date(`${dateString}T00:00:00`).toLocaleDateString('id-ID', { day: 'numeric', month: 'long' });
}

export default function MonitoringRingkasan({ employee }) {
    const [overview, setOverview] = useState(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);

    useEffect(() => {
        (async () => {
            setLoading(true);
            setError(null);
            try {
                const result = await apiFetch('/api/monitoring/overview');
                setOverview(result.data);
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
                <h1 className="text-3xl font-bold tracking-tight text-bbm-text">Ringkasan</h1>
                <p className="mt-1.5 text-sm text-bbm-text-muted">
                    {overview
                        ? `Periode minggu ini: ${formatDate(overview.period.start)} – ${formatDate(overview.period.end)}`
                        : 'Statistik perusahaan minggu ini.'}
                </p>
            </div>

            {error && <div className="mb-6 text-sm text-red-400">{error}</div>}

            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
                <StatPill
                    variant="card"
                    icon={Users}
                    label="Karyawan Aktif"
                    value={overview ? formatNumber(overview.total_employees_active) : undefined}
                    description="Total akun berstatus aktif"
                />
                <StatPill
                    variant="card"
                    icon={Activity}
                    label="Partisipasi Minggu Ini"
                    value={overview ? `${overview.participation_rate_this_week}%` : undefined}
                    description="Karyawan aktif dengan aktivitas tercatat"
                />
                <StatPill
                    variant="card"
                    icon={Footprints}
                    label="Total Langkah Minggu Ini"
                    value={overview ? formatNumber(overview.total_steps_this_week) : undefined}
                    description="Akumulasi seluruh karyawan"
                />
                <StatPill
                    variant="card"
                    icon={Route}
                    label="Total Jarak Minggu Ini"
                    value={overview ? `${overview.total_km_this_week} km` : undefined}
                    description="Langkah + sesi jalan kaki"
                />
            </div>
        </DashboardLayout>
    );
}
