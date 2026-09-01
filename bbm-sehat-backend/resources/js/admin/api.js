/**
 * Fetch wrapper for the dashboard's Sanctum SPA session auth (cookie-based,
 * not bearer token — see AdminAuthController). Every state-changing request
 * needs the XSRF-TOKEN cookie echoed back as a header, and that cookie is
 * only set after GET /sanctum/csrf-cookie has been called at least once.
 */
function readCookie(name) {
    const match = document.cookie.match(new RegExp('(^|; )' + name + '=([^;]*)'));
    return match ? decodeURIComponent(match[2]) : null;
}

async function ensureCsrfCookie() {
    if (readCookie('XSRF-TOKEN')) return;

    await fetch('/sanctum/csrf-cookie', { credentials: 'include' });
}

export async function apiFetch(path, options = {}) {
    await ensureCsrfCookie();

    const response = await fetch(path, {
        ...options,
        credentials: 'include',
        headers: {
            Accept: 'application/json',
            'Content-Type': 'application/json',
            'X-XSRF-TOKEN': readCookie('XSRF-TOKEN'),
            ...options.headers,
        },
    });

    let body = null;
    try {
        body = await response.json();
    } catch {
        // No JSON body (e.g. 204 responses) — leave body null.
    }

    if (!response.ok) {
        const error = new Error(body?.message || `Request gagal (${response.status})`);
        error.status = response.status;
        error.body = body;
        throw error;
    }

    return body;
}

/**
 * Like apiFetch, but for endpoints that return a binary file (e.g. the
 * credential-slip PDF) instead of JSON — triggers a browser download
 * directly rather than returning parsed data.
 */
export async function apiDownload(path, options = {}) {
    await ensureCsrfCookie();

    const response = await fetch(path, {
        ...options,
        credentials: 'include',
        headers: {
            'X-XSRF-TOKEN': readCookie('XSRF-TOKEN'),
            ...options.headers,
        },
    });

    if (!response.ok) {
        let body = null;
        try {
            body = await response.json();
        } catch {
            // Error response wasn't JSON either — fall through to the generic message.
        }

        const error = new Error(body?.message || `Gagal membuat berkas (${response.status})`);
        error.status = response.status;
        error.body = body;
        throw error;
    }

    const disposition = response.headers.get('content-disposition') || '';
    const match = disposition.match(/filename="?([^"]+)"?/);
    const filename = match ? match[1] : 'download';

    const blob = await response.blob();
    const url = URL.createObjectURL(blob);

    const link = document.createElement('a');
    link.href = url;
    link.download = filename;
    document.body.appendChild(link);
    link.click();
    link.remove();
    URL.revokeObjectURL(url);
}
