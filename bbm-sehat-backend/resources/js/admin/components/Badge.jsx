/**
 * Color-per-category badges reused across the employee table (Tahap 2) and
 * this tab's preview. Colors are intentionally distinct per role/status so
 * they stay scannable in a dense table — not tied to any single tab.
 */
const ROLE_STYLES = {
    SUPER_ADMIN: 'bg-purple-500/15 text-purple-300 ring-1 ring-purple-500/30',
    MANAGEMENT: 'bg-blue-500/15 text-blue-300 ring-1 ring-blue-500/30',
    ADMIN_UMUM_SDM: 'bg-amber-500/15 text-amber-300 ring-1 ring-amber-500/30',
    DIVISION_ADMIN: 'bg-cyan-500/15 text-cyan-300 ring-1 ring-cyan-500/30',
    EMPLOYEE: 'bg-bbm-border/60 text-bbm-text-muted ring-1 ring-bbm-border',
};

const ROLE_LABELS = {
    SUPER_ADMIN: 'Super Admin',
    MANAGEMENT: 'Manajemen',
    ADMIN_UMUM_SDM: 'Admin Umum & SDM',
    DIVISION_ADMIN: 'Admin Divisi',
    EMPLOYEE: 'Karyawan',
};

const STATUS_STYLES = {
    active: 'bg-bbm-accent/15 text-bbm-accent ring-1 ring-bbm-accent/30',
    inactive: 'bg-zinc-500/15 text-zinc-300 ring-1 ring-zinc-500/30',
    archived: 'bg-red-500/15 text-red-300 ring-1 ring-red-500/30',
};

const STATUS_LABELS = {
    active: 'Aktif',
    inactive: 'Nonaktif',
    archived: 'Diarsipkan',
};

function BadgeBase({ className, children }) {
    return (
        <span
            className={`inline-flex items-center rounded-full px-2.5 py-1 text-xs font-medium whitespace-nowrap ${className}`}
        >
            {children}
        </span>
    );
}

export function RoleBadge({ role }) {
    return (
        <BadgeBase className={ROLE_STYLES[role] ?? ROLE_STYLES.EMPLOYEE}>
            {ROLE_LABELS[role] ?? role}
        </BadgeBase>
    );
}

export function StatusBadge({ status }) {
    return (
        <BadgeBase className={STATUS_STYLES[status] ?? STATUS_STYLES.inactive}>
            {STATUS_LABELS[status] ?? status}
        </BadgeBase>
    );
}
