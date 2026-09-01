import { useCallback, useEffect, useState } from 'react';
import { Users, ShieldCheck, History } from 'lucide-react';
import DashboardLayout from '../components/DashboardLayout';
import StatPill from '../components/StatPill';
import ManajemenPengguna from '../components/ManajemenPengguna';
import HakAksesPerRole from '../components/HakAksesPerRole';
import LogAktivitas from '../components/LogAktivitas';
import { apiFetch } from '../api';

const TABS = [
    { key: 'manajemen-pengguna', label: 'Manajemen Pengguna', icon: Users },
    { key: 'hak-akses', label: 'Hak Akses per Role', icon: ShieldCheck },
    { key: 'log-aktivitas', label: 'Log Aktivitas', icon: History },
];

/**
 * EmployeeController::index() paginates at 25/page with no way to request
 * a larger page — loop through every page instead of adding a backend
 * query param, since the whole company is a few dozen people (well under
 * what a couple of sequential requests can't handle).
 */
async function fetchAllEmployees() {
    const all = [];
    let page = 1;
    let lastPage = 1;

    do {
        const result = await apiFetch(`/api/admin/user-settings/employees?page=${page}`);
        all.push(...result.data);
        lastPage = result.meta.last_page;
        page += 1;
    } while (page <= lastPage);

    return all;
}

export default function PengaturanPengguna({ employee }) {
    const [activeTab, setActiveTab] = useState(TABS[0].key);
    const [employees, setEmployees] = useState([]);
    const [divisions, setDivisions] = useState([]);
    const [roles, setRoles] = useState([]);
    const [rbacMatrix, setRbacMatrix] = useState([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);

    const refetchEmployees = useCallback(async () => {
        try {
            setEmployees(await fetchAllEmployees());
        } catch (err) {
            setError(err.message);
        }
    }, []);

    useEffect(() => {
        (async () => {
            setLoading(true);
            setError(null);
            try {
                const [emps, divs, rls, matrix] = await Promise.all([
                    fetchAllEmployees(),
                    apiFetch('/api/admin/user-settings/divisions'),
                    apiFetch('/api/admin/user-settings/roles'),
                    apiFetch('/api/admin/user-settings/rbac-matrix'),
                ]);
                setEmployees(emps);
                setDivisions(divs.data);
                setRoles(rls.data);
                setRbacMatrix(matrix.data);
            } catch (err) {
                setError(err.message);
            } finally {
                setLoading(false);
            }
        })();
    }, []);

    const activeCount = employees.filter((e) => e.account_status === 'active').length;

    return (
        <DashboardLayout employee={employee}>
            <div className="mb-8 flex flex-wrap items-center justify-between gap-4">
                <div>
                    <h1 className="text-3xl font-bold tracking-tight text-bbm-text">Pengaturan Pengguna</h1>
                    <p className="mt-1.5 text-sm text-bbm-text-muted">
                        Khusus Super Admin — kelola akun, role, dan pantau log aktivitas.
                    </p>
                </div>

                <div className="flex gap-2">
                    <StatPill icon={Users} label="Total Pengguna" value={loading ? undefined : employees.length} />
                    <StatPill icon={ShieldCheck} label="Akun Aktif" value={loading ? undefined : activeCount} />
                </div>
            </div>

            <div className="mb-6 flex gap-2 border-b border-bbm-border">
                {TABS.map(({ key, label, icon: Icon }) => (
                    <button
                        key={key}
                        onClick={() => setActiveTab(key)}
                        className={`flex items-center gap-2 border-b-2 px-4 py-2.5 text-sm font-medium transition ${
                            activeTab === key
                                ? 'border-bbm-accent text-bbm-accent'
                                : 'border-transparent text-bbm-text-muted hover:text-bbm-text'
                        }`}
                    >
                        <Icon size={15} />
                        {label}
                    </button>
                ))}
            </div>

            {activeTab === 'manajemen-pengguna' && (
                <ManajemenPengguna
                    employees={employees}
                    divisions={divisions}
                    roles={roles}
                    currentEmployeeId={employee.id}
                    loading={loading}
                    error={error}
                    onRefetch={refetchEmployees}
                />
            )}

            {activeTab === 'hak-akses' && (
                <HakAksesPerRole roles={roles} matrix={rbacMatrix} loading={loading} error={error} />
            )}

            {activeTab === 'log-aktivitas' && <LogAktivitas />}
        </DashboardLayout>
    );
}
