/**
 * Small badge/pill for the page header (e.g. "48 Pengguna", "45 Aktif").
 * Renders a "–" placeholder when `value` is undefined — this page doesn't
 * fetch employee data yet (that's Tahap 2), so there is nothing real to
 * show here until then. Deliberately does NOT fetch anything itself.
 *
 * `variant="card"` reuses the same component for the larger stat tiles on
 * the Monitoring "Ringkasan" page instead of introducing a separate stat
 * card component — same value/label semantics, just bigger and with room
 * for a `description` line.
 */
export default function StatPill({ icon: Icon, label, value, description, variant = 'pill' }) {
    if (variant === 'card') {
        return (
            <div className="rounded-2xl border border-bbm-border bg-bbm-card p-5 shadow-[0_12px_40px_-20px_rgba(0,0,0,0.7)]">
                <div className="flex items-center gap-2 text-xs font-medium text-bbm-text-muted">
                    {Icon && <Icon size={14} className="text-bbm-accent" />}
                    {label}
                </div>
                <p className="mt-2 text-3xl font-bold tracking-tight text-bbm-text">{value ?? '–'}</p>
                {description && <p className="mt-1 text-xs text-bbm-text-muted">{description}</p>}
            </div>
        );
    }

    return (
        <span className="inline-flex items-center gap-1.5 rounded-full border border-bbm-border bg-bbm-card px-3 py-1.5 text-xs text-bbm-text-muted">
            {Icon && <Icon size={13} className="text-bbm-accent" />}
            <span className="font-semibold text-bbm-text">{value ?? '–'}</span>
            {label}
        </span>
    );
}
