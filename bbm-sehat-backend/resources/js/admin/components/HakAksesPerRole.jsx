import { Check, X, Info } from 'lucide-react';

/**
 * Read-only — this tab never writes anything. `matrix` comes straight from
 * GET /api/admin/user-settings/rbac-matrix (RbacMatrixBuilder), which
 * reads the actual `role:` middleware off the live routes rather than a
 * hardcoded table — see that class's docblock for the one piece of it that
 * IS still a maintained mapping (which routes count as which module).
 */
export default function HakAksesPerRole({ roles, matrix, loading, error }) {
    if (loading) {
        return (
            <div className="rounded-2xl border border-bbm-border bg-bbm-card p-10 text-center text-sm text-bbm-text-muted shadow-[0_12px_40px_-20px_rgba(0,0,0,0.7)]">
                Memuat matriks hak akses...
            </div>
        );
    }

    if (error) {
        return (
            <div className="rounded-2xl border border-bbm-border bg-bbm-card p-10 text-center text-sm text-red-400 shadow-[0_12px_40px_-20px_rgba(0,0,0,0.7)]">
                {error}
            </div>
        );
    }

    const hasWhitelistedModule = matrix.some((m) => m.whitelist_only);

    return (
        <div className="rounded-2xl border border-bbm-border bg-bbm-card shadow-[0_12px_40px_-20px_rgba(0,0,0,0.7)]">
            <div className="flex items-start gap-2.5 border-b border-bbm-border px-6 py-4">
                <Info size={15} className="mt-0.5 shrink-0 text-bbm-text-muted" />
                <p className="text-xs text-bbm-text-muted">
                    Matriks ini dibaca langsung dari aturan akses (middleware) di backend saat halaman dimuat —
                    bukan tabel yang diketik manual. Kalau aturan akses berubah di kode, matriks ini otomatis
                    berubah mengikuti.
                </p>
            </div>

            <div className="overflow-x-auto">
                <table className="w-full text-left text-sm">
                    <thead>
                        <tr className="text-xs text-bbm-text-muted">
                            <th className="sticky left-0 bg-bbm-card px-6 py-3 font-medium">Role</th>
                            {matrix.map((module) => (
                                <th key={module.label} className="px-4 py-3 text-center font-medium whitespace-nowrap">
                                    {module.label}
                                    {module.whitelist_only && <span className="text-bbm-accent">*</span>}
                                </th>
                            ))}
                        </tr>
                    </thead>
                    <tbody>
                        {roles.map((role) => (
                            <tr key={role.id} className="border-t border-bbm-border transition hover:bg-white/5">
                                <td className="sticky left-0 bg-bbm-card px-6 py-3 font-medium text-bbm-text">
                                    {role.name}
                                </td>
                                {matrix.map((module) => {
                                    const allowed = module.roles.includes(role.code);

                                    return (
                                        <td key={module.label} className="px-4 py-3 text-center">
                                            {allowed ? (
                                                <Check size={16} className="mx-auto text-bbm-accent" />
                                            ) : (
                                                <X size={16} className="mx-auto text-bbm-text-muted/40" />
                                            )}
                                        </td>
                                    );
                                })}
                            </tr>
                        ))}
                    </tbody>
                </table>
            </div>

            {hasWhitelistedModule && (
                <p className="border-t border-bbm-border px-6 py-3 text-xs text-bbm-text-muted">
                    <span className="text-bbm-accent">*</span> Selain role, kolom ini juga dibatasi ke akun
                    SUPER_ADMIN tertentu yang terdaftar (whitelist), bukan berlaku untuk seluruh SUPER_ADMIN.
                </p>
            )}
        </div>
    );
}
