import { useState } from 'react';
import { apiFetch } from '../api';
import LoginHero from '../components/LoginHero';

export default function Login() {
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [error, setError] = useState(null);
    const [submitting, setSubmitting] = useState(false);

    async function handleSubmit(event) {
        event.preventDefault();
        setError(null);
        setSubmitting(true);

        try {
            // Landing page depends on role + whitelist — only the backend
            // knows both (see Employee::dashboardHomeRoute()), so it decides
            // the destination, not a hardcoded value here. must_change_password
            // overrides that destination: the mandatory password change page
            // always comes first, regardless of role.
            const result = await apiFetch('/api/admin/login', {
                method: 'POST',
                body: JSON.stringify({ email, password }),
            });

            window.location.href = result.must_change_password
                ? '/dashboard/ganti-password-wajib'
                : result.redirect_to;
        } catch (err) {
            setError(err.message);
            setSubmitting(false);
        }
    }

    return (
        <div className="flex min-h-screen flex-col bg-bbm-bg md:flex-row">
            <LoginHero />

            <div className="flex w-full flex-1 items-center justify-center px-6 py-12 md:w-2/5 md:px-10">
                <form
                    onSubmit={handleSubmit}
                    className="w-full max-w-sm rounded-[20px] border border-white/10 bg-bbm-card/60 p-10 shadow-[0_20px_60px_-15px_rgba(0,0,0,0.6)] backdrop-blur-xl"
                >
                    <h2 className="text-2xl font-bold text-bbm-text">Masuk</h2>
                    <p className="mt-1.5 mb-8 text-sm text-bbm-text-muted">
                        Gunakan akun admin Anda untuk melanjutkan.
                    </p>

                    {error && (
                        <div className="mb-5 rounded-xl border border-red-900/60 bg-red-950/40 px-4 py-3 text-sm text-red-300">
                            {error}
                        </div>
                    )}

                    <label
                        className="mb-2 block text-xs font-medium tracking-wide text-bbm-text-muted uppercase"
                        htmlFor="email"
                    >
                        Email
                    </label>
                    <input
                        id="email"
                        type="email"
                        required
                        autoComplete="username"
                        value={email}
                        onChange={(e) => setEmail(e.target.value)}
                        className="mb-5 w-full rounded-xl border border-bbm-border bg-bbm-bg/80 px-4 py-2.5 text-bbm-text outline-none transition focus:border-bbm-accent focus:ring-4 focus:ring-bbm-accent/15"
                    />

                    <label
                        className="mb-2 block text-xs font-medium tracking-wide text-bbm-text-muted uppercase"
                        htmlFor="password"
                    >
                        Kata Sandi
                    </label>
                    <input
                        id="password"
                        type="password"
                        required
                        autoComplete="current-password"
                        value={password}
                        onChange={(e) => setPassword(e.target.value)}
                        className="mb-8 w-full rounded-xl border border-bbm-border bg-bbm-bg/80 px-4 py-2.5 text-bbm-text outline-none transition focus:border-bbm-accent focus:ring-4 focus:ring-bbm-accent/15"
                    />

                    <button
                        type="submit"
                        disabled={submitting}
                        className="w-full rounded-xl bg-bbm-accent px-4 py-3 font-semibold text-white shadow-[0_8px_24px_-6px_rgba(99,153,34,0.55)] transition hover:bg-bbm-accent-hover disabled:opacity-60"
                    >
                        {submitting ? 'Memproses...' : 'Masuk'}
                    </button>
                </form>
            </div>
        </div>
    );
}
