import { useEffect } from 'react';
import { X } from 'lucide-react';

export default function Modal({ title, onClose, children, wide = false }) {
    useEffect(() => {
        function handleKeyDown(event) {
            if (event.key === 'Escape') onClose();
        }

        document.addEventListener('keydown', handleKeyDown);
        return () => document.removeEventListener('keydown', handleKeyDown);
    }, [onClose]);

    return (
        <div
            className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4 backdrop-blur-sm"
            onClick={onClose}
        >
            <div
                onClick={(e) => e.stopPropagation()}
                className={`w-full ${wide ? 'max-w-2xl' : 'max-w-md'} rounded-[20px] border border-white/10 bg-bbm-card p-8 shadow-[0_20px_60px_-15px_rgba(0,0,0,0.7)]`}
            >
                <div className="mb-6 flex items-center justify-between">
                    <h2 className="text-xl font-bold text-bbm-text">{title}</h2>
                    <button
                        onClick={onClose}
                        className="rounded-lg p-1.5 text-bbm-text-muted transition hover:bg-white/5 hover:text-bbm-text"
                        aria-label="Tutup"
                    >
                        <X size={18} />
                    </button>
                </div>

                {children}
            </div>
        </div>
    );
}
