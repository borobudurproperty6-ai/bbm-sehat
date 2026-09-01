/**
 * Purely decorative — the left panel of the login split layout. No state,
 * no data, no behavior; safe to redesign freely without touching Login.jsx
 * logic. Blob shapes are hand-authored SVG paths (not photos), gradient-
 * filled in brand green fading into the dark background.
 */
export default function LoginHero() {
    return (
        <div className="relative flex w-full shrink-0 flex-col justify-between overflow-hidden bg-bbm-bg px-8 py-10 md:min-h-screen md:w-3/5 md:px-16 md:py-16">
            <svg
                className="pointer-events-none absolute inset-0 h-full w-full"
                viewBox="0 0 800 800"
                preserveAspectRatio="xMidYMid slice"
                aria-hidden="true"
            >
                <defs>
                    <linearGradient id="blob-a" x1="0%" y1="0%" x2="100%" y2="100%">
                        <stop offset="0%" stopColor="#639922" stopOpacity="0.55" />
                        <stop offset="100%" stopColor="#0d0d0d" stopOpacity="0.1" />
                    </linearGradient>
                    <linearGradient id="blob-b" x1="100%" y1="0%" x2="0%" y2="100%">
                        <stop offset="0%" stopColor="#75b428" stopOpacity="0.35" />
                        <stop offset="100%" stopColor="#0d0d0d" stopOpacity="0" />
                    </linearGradient>
                </defs>

                <g transform="translate(180 220) scale(2.6)" opacity="0.9">
                    <path
                        fill="url(#blob-a)"
                        d="M42.7,-73.4C54.4,-67.3,62,-54.4,69.5,-41.2C77,-28,84.4,-14,84.6,0.2C84.8,14.4,77.8,28.8,69.5,41.5C61.2,54.2,51.6,65.2,39.4,71.8C27.2,78.4,13.6,80.6,-0.6,81.6C-14.8,82.6,-29.6,82.4,-42.1,76.5C-54.6,70.6,-64.8,59,-71.9,45.9C-79,32.8,-83,18.2,-83.6,3.3C-84.2,-11.6,-81.4,-23.2,-75.1,-33.7C-68.8,-44.2,-59,-53.6,-47.6,-60.1C-36.2,-66.6,-23.2,-70.2,-9.8,-71.9C3.6,-73.6,17.9,-73.4,42.7,-73.4Z"
                    />
                </g>

                <g transform="translate(560 520) scale(3.1) rotate(35)" opacity="0.7">
                    <path
                        fill="url(#blob-b)"
                        d="M42.7,-73.4C54.4,-67.3,62,-54.4,69.5,-41.2C77,-28,84.4,-14,84.6,0.2C84.8,14.4,77.8,28.8,69.5,41.5C61.2,54.2,51.6,65.2,39.4,71.8C27.2,78.4,13.6,80.6,-0.6,81.6C-14.8,82.6,-29.6,82.4,-42.1,76.5C-54.6,70.6,-64.8,59,-71.9,45.9C-79,32.8,-83,18.2,-83.6,3.3C-84.2,-11.6,-81.4,-23.2,-75.1,-33.7C-68.8,-44.2,-59,-53.6,-47.6,-60.1C-36.2,-66.6,-23.2,-70.2,-9.8,-71.9C3.6,-73.6,17.9,-73.4,42.7,-73.4Z"
                    />
                </g>
            </svg>

            <div className="relative z-10">
                <p className="text-sm font-medium tracking-wide text-bbm-accent">BBM SEHAT</p>
                <h1 className="mt-3 max-w-md text-4xl font-bold tracking-tight text-bbm-text md:text-5xl">
                    Dashboard Admin
                </h1>
                <p className="mt-4 max-w-sm text-sm leading-relaxed text-bbm-text-muted md:text-base">
                    Pantau aktivitas, poin, dan kesehatan karyawan dalam satu tempat.
                </p>
            </div>

            <p className="relative z-10 hidden text-xs text-bbm-text-muted/70 md:block">
                &copy; {new Date().getFullYear()} BBM Sehat
            </p>
        </div>
    );
}
