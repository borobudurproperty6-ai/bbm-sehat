import Modal from './Modal';

export default function ConfirmDialog({ title, message, confirmLabel, onConfirm, onCancel, busy }) {
    return (
        <Modal title={title} onClose={onCancel}>
            <p className="mb-6 text-sm text-bbm-text-muted">{message}</p>

            <div className="flex justify-end gap-3">
                <button
                    onClick={onCancel}
                    className="rounded-xl border border-bbm-border px-4 py-2 text-sm text-bbm-text-muted transition hover:text-bbm-text"
                >
                    Batal
                </button>
                <button
                    onClick={onConfirm}
                    disabled={busy}
                    className="rounded-xl bg-bbm-accent px-5 py-2 text-sm font-semibold text-white transition hover:bg-bbm-accent-hover disabled:opacity-60"
                >
                    {busy ? 'Memproses...' : confirmLabel}
                </button>
            </div>
        </Modal>
    );
}
