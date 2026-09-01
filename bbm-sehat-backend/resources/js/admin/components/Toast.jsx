import { useEffect } from 'react';
import { CheckCircle2, AlertCircle } from 'lucide-react';

export default function Toast({ toast, onDismiss }) {
    useEffect(() => {
        if (!toast) return;
        const timer = setTimeout(onDismiss, 4000);
        return () => clearTimeout(timer);
    }, [toast, onDismiss]);

    if (!toast) return null;

    const isError = toast.type === 'error';

    return (
        <div
            className={`fixed right-6 bottom-6 z-50 flex items-center gap-2.5 rounded-xl border px-4 py-3 text-sm shadow-[0_12px_40px_-12px_rgba(0,0,0,0.6)] ${
                isError
                    ? 'border-red-900/60 bg-red-950/90 text-red-200'
                    : 'border-bbm-accent/30 bg-bbm-card text-bbm-text'
            }`}
        >
            {isError ? <AlertCircle size={16} className="shrink-0" /> : <CheckCircle2 size={16} className="shrink-0 text-bbm-accent" />}
            {toast.message}
        </div>
    );
}
