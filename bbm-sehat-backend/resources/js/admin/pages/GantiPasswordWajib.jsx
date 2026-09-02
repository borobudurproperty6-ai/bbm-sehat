import { useState } from 'react';
import { apiFetch } from '../api';

export default function GantiPasswordWajib({ employee, redirectTo }) {
    const [currentPassword, setCurrentPassword] = useState('');
    const [password, setPassword] = useState('');
    const [passwordConfirmation, setPasswordConfirmation] = useState('');
    const [errors, setErrors] = useState({});
    const [generalError, setGeneralError] = useState(null);
    const [submitting, setSubmitting] = useState(false);

    async function handleSubmit(event) {
        event.preventDefault();
        setErrors({});
        setGeneralError(null);
        setSubmitting(true);

        try {
            await apiFetch('/api/change-password', {
                method: 'POST',
                body: JSON.stringify({
                    current_password: currentPassword,
                    password,
                    password_confirmation: passwordConfirmation,
                }),
            });

            window.location.href = redirectTo;
        } catch (err) {
            if (err.status === 422 && err.body?.errors) {
                setErrors(err.body.errors);
            } else {
                setGeneralError(err.message);
            }
            setSubmitting(false);
        }
    }

    async function handleLogout() {
        try {
            await apiFetch('/api/logout', { method: 'POST' });
        } finally {
            window.location.href = '/dashboard/login';
        }
    }

    return (
        <div className="flex min-h-screen items-center justify-center bg-bbm-bg px-6 py-12">
            <form
                onSubmit={handleSubmit}
                className="w-full max-w-sm rounded-[20px] border border-white/10 bg-bbm-card/60 p-10 shadow-[0_20px_60px_-15px_rgba(0,0,0,0.6)] backdrop-blur-xl"
            >
                <h2 className="text-2xl font-bold text-bbm-text">Ganti Kata Sandi</h2>
                <p className="mt-1.5 mb-8 text-sm text-bbm-text-muted">
                    Halo, {employee.full_name}. Untuk keamanan akun, silakan ganti kata
                    sandi sementara Anda sebelum melanjutkan.
                </p>

                {generalError && (
                    <div className="mb-5 rounded-xl border border-red-900/60 bg-red-950/40 px-4 py-3 text-sm text-red-300">
                        {generalError}
                    </div>
                )}

                <label
                    className="mb-2 block text-xs font-medium tracking-wide text-bbm-text-muted uppercase"
                    htmlFor="current_password"
                >
                    Kata Sandi Saat Ini
                </label>
                <input
                    id="current_password"
                    type="password"
                    required
                    autoComplete="current-password"
                    value={currentPassword}
                    onChange={(e) => setCurrentPassword(e.target.value)}
                    className="mb-1 w-full rounded-xl border border-bbm-border bg-bbm-bg/80 px-4 py-2.5 text-bbm-text outline-none transition focus:border-bbm-accent focus:ring-4 focus:ring-bbm-accent/15"
                />
                {errors.current_password && (
                    <p className="mb-4 text-xs text-red-400">{errors.current_password[0]}</p>
                )}

                <label
                    className="mt-4 mb-2 block text-xs font-medium tracking-wide text-bbm-text-muted uppercase"
                    htmlFor="password"
                >
                    Kata Sandi Baru
                </label>
                <input
                    id="password"
                    type="password"
                    required
                    minLength={8}
                    autoComplete="new-password"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    className="mb-1 w-full rounded-xl border border-bbm-border bg-bbm-bg/80 px-4 py-2.5 text-bbm-text outline-none transition focus:border-bbm-accent focus:ring-4 focus:ring-bbm-accent/15"
                />
                {errors.password && (
                    <p className="mb-4 text-xs text-red-400">{errors.password[0]}</p>
                )}

                <label
                    className="mt-4 mb-2 block text-xs font-medium tracking-wide text-bbm-text-muted uppercase"
                    htmlFor="password_confirmation"
                >
                    Ulangi Kata Sandi Baru
                </label>
                <input
                    id="password_confirmation"
                    type="password"
                    required
                    minLength={8}
                    autoComplete="new-password"
                    value={passwordConfirmation}
                    onChange={(e) => setPasswordConfirmation(e.target.value)}
                    className="mb-8 w-full rounded-xl border border-bbm-border bg-bbm-bg/80 px-4 py-2.5 text-bbm-text outline-none transition focus:border-bbm-accent focus:ring-4 focus:ring-bbm-accent/15"
                />

                <button
                    type="submit"
                    disabled={submitting}
                    className="w-full rounded-xl bg-bbm-accent px-4 py-3 font-semibold text-white shadow-[0_8px_24px_-6px_rgba(99,153,34,0.55)] transition hover:bg-bbm-accent-hover disabled:opacity-60"
                >
                    {submitting ? 'Memproses...' : 'Ganti Kata Sandi'}
                </button>

                <button
                    type="button"
                    onClick={handleLogout}
                    className="mt-4 w-full text-center text-xs text-bbm-text-muted underline decoration-dotted hover:text-bbm-text"
                >
                    Keluar
                </button>
            </form>
        </div>
    );
}
