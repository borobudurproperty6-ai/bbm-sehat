import { Settings, LogOut, LayoutDashboard, Building2, UserX, TrendingUp } from 'lucide-react';
import { apiFetch } from '../api';

/**
 * Sidebar only ever lists links to pages the current employee is actually
 * allowed to open — each item's `roles` mirrors that page's route
 * middleware exactly (see routes/web.php), so this is a display filter on
 * top of a gate that already holds server-side, never a substitute for it.
 * "Pengaturan Pengguna" additionally requires the whitelist
 * (EnsureEmployeeIsWhitelistedForUserSettings) that isn't visible from
 * role_code alone, so a non-whitelisted SUPER_ADMIN can still see the link
 * here and get a 403 from the route itself — same as before this file had
 * any role filtering.
 */
const NAV_GROUPS = [
    {
        section: 'Monitoring',
        items: [
            {
                href: '/dashboard/monitoring/ringkasan',
                label: 'Ringkasan',
                icon: LayoutDashboard,
                roles: ['MANAGEMENT', 'SUPER_ADMIN', 'ADMIN_UMUM_SDM'],
            },
            {
                href: '/dashboard/monitoring/per-divisi',
                label: 'Per Divisi',
                icon: Building2,
                roles: ['MANAGEMENT', 'SUPER_ADMIN', 'ADMIN_UMUM_SDM'],
            },
            {
                href: '/dashboard/monitoring/tidak-aktif',
                label: 'Karyawan Tidak Aktif',
                icon: UserX,
                roles: ['MANAGEMENT', 'SUPER_ADMIN', 'ADMIN_UMUM_SDM'],
            },
            {
                href: '/dashboard/monitoring/progres-karyawan',
                label: 'Progres Karyawan',
                icon: TrendingUp,
                roles: ['MANAGEMENT', 'SUPER_ADMIN', 'ADMIN_UMUM_SDM'],
            },
        ],
    },
    {
        section: 'Administrasi',
        items: [
            {
                href: '/dashboard/pengaturan-pengguna',
                label: 'Pengaturan Pengguna',
                icon: Settings,
                roles: ['SUPER_ADMIN'],
            },
        ],
    },
];

export default function DashboardLayout({ employee, children }) {
    async function handleLogout() {
        try {
            await apiFetch('/api/logout', { method: 'POST' });
        } finally {
            window.location.href = '/dashboard/login';
        }
    }

    return (
        <div className="flex min-h-screen bg-bbm-bg text-bbm-text">
            <aside className="flex w-72 shrink-0 flex-col border-r border-bbm-border bg-bbm-card">
                <div className="border-b border-bbm-border px-6 py-6">
                    <p className="text-lg font-bold tracking-tight text-bbm-text">BBM Sehat</p>
                    <p className="text-xs text-bbm-text-muted">Dashboard Admin</p>
                </div>

                <nav className="flex-1 space-y-6 px-4 py-6">
                    {NAV_GROUPS.map(({ section, items }) => {
                        const visibleItems = items.filter((item) => item.roles.includes(employee.role_code));
                        if (visibleItems.length === 0) return null;

                        return (
                            <div key={section} className="space-y-1">
                                <p className="px-3.5 pb-1.5 text-[11px] font-semibold tracking-wider text-bbm-text-muted uppercase">
                                    {section}
                                </p>
                                {visibleItems.map(({ href, label, icon: Icon }) => {
                                    const active = window.location.pathname === href;

                                    return (
                                        <a
                                            key={href}
                                            href={href}
                                            className={`flex items-center gap-3 rounded-xl px-3.5 py-2.5 text-sm font-medium transition ${
                                                active
                                                    ? 'bg-bbm-accent text-white shadow-[0_8px_20px_-6px_rgba(99,153,34,0.55)]'
                                                    : 'text-bbm-text-muted hover:bg-white/5 hover:text-bbm-text'
                                            }`}
                                        >
                                            <Icon size={17} strokeWidth={2} />
                                            {label}
                                        </a>
                                    );
                                })}
                            </div>
                        );
                    })}
                </nav>

                <div className="border-t border-bbm-border px-4 py-5">
                    <div className="rounded-xl bg-white/5 px-3.5 py-3">
                        <p className="truncate text-sm font-semibold text-bbm-text">{employee.full_name}</p>
                        <p className="truncate text-xs text-bbm-text-muted">{employee.role_name}</p>
                    </div>
                    <button
                        onClick={handleLogout}
                        className="mt-3 flex w-full items-center justify-center gap-2 rounded-xl border border-bbm-border px-3 py-2 text-sm text-bbm-text-muted transition hover:border-bbm-accent/50 hover:text-bbm-text"
                    >
                        <LogOut size={15} />
                        Keluar
                    </button>
                </div>
            </aside>

            <main className="flex-1 overflow-y-auto p-10">{children}</main>
        </div>
    );
}
