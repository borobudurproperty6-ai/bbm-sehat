import { useState } from 'react';
import { Copy, Check, FileDown } from 'lucide-react';
import Modal from './Modal';
import { apiDownload } from '../api';

/**
 * Shown right after "Tambah Pengguna" or "Reset Password" — the only
 * moment this password is ever visible. Matches the existing backend
 * pattern (EmployeeController::sendProvisioningNotification): relay it to
 * the employee directly (WhatsApp/phone), it is not emailed reliably.
 *
 * "Cetak Slip" downloads a real PDF generated server-side
 * (CredentialSlipController) — the endpoint sits behind the exact same
 * whitelisted-SUPER_ADMIN gate as every other Pengaturan Pengguna
 * endpoint, so there's nothing extra to protect here on the frontend.
 */
export default function TemporaryPasswordModal({ employeeId, employeeName, employeeCode, password, onClose }) {
    const [copied, setCopied] = useState(false);
    const [downloading, setDownloading] = useState(false);
    const [downloadError, setDownloadError] = useState(null);

    async function handleCopy() {
        try {
            await navigator.clipboard.writeText(password);
            setCopied(true);
            setTimeout(() => setCopied(false), 2000);
        } catch {
            // Clipboard API can be unavailable (permissions, insecure
            // context) — the password is still selectable/visible as text.
        }
    }

    async function handleDownloadSlip() {
        setDownloadError(null);
        setDownloading(true);
        try {
            await apiDownload(`/api/admin/user-settings/employees/${employeeId}/credential-slip`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ password }),
            });
        } catch (err) {
            setDownloadError(err.message);
        } finally {
            setDownloading(false);
        }
    }

    return (
        <Modal title="Password Sementara" onClose={onClose}>
            <p className="mb-4 text-sm text-bbm-text-muted">
                Sampaikan password ini ke <span className="font-medium text-bbm-text">{employeeName}</span> secara
                langsung (telepon/WhatsApp), atau unduh slipnya — halaman ini tidak akan menampilkannya lagi.
            </p>

            <div className="mb-6 flex items-center justify-between gap-3 rounded-xl border border-bbm-border bg-bbm-bg/80 px-4 py-3">
                <code className="font-mono text-lg tracking-wide text-bbm-accent">{password}</code>
                <button
                    onClick={handleCopy}
                    className="flex items-center gap-1.5 rounded-lg border border-bbm-border px-3 py-1.5 text-xs text-bbm-text-muted transition hover:text-bbm-text"
                >
                    {copied ? <Check size={13} /> : <Copy size={13} />}
                    {copied ? 'Tersalin' : 'Salin'}
                </button>
            </div>

            {downloadError && (
                <div className="mb-4 rounded-xl border border-red-900/60 bg-red-950/40 px-4 py-3 text-sm text-red-300">
                    {downloadError}
                </div>
            )}

            <div className="flex gap-3">
                <button
                    onClick={handleDownloadSlip}
                    disabled={downloading}
                    className="flex flex-1 items-center justify-center gap-2 rounded-xl border border-bbm-border px-4 py-2.5 text-sm font-medium text-bbm-text transition hover:border-bbm-accent/50 disabled:opacity-60"
                >
                    <FileDown size={15} />
                    {downloading ? 'Membuat PDF...' : 'Unduh Slip (PDF)'}
                </button>
                <button
                    onClick={onClose}
                    className="flex-1 rounded-xl bg-bbm-accent px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-bbm-accent-hover"
                >
                    Selesai
                </button>
            </div>
        </Modal>
    );
}
