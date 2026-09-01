<!DOCTYPE html>
<html lang="id">
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Perlu Masuk — BBM Sehat</title>
        <style>
            body {
                margin: 0;
                min-height: 100vh;
                display: flex;
                align-items: center;
                justify-content: center;
                background: #0d0d0d;
                color: #ededec;
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            }
            .card {
                max-width: 26rem;
                padding: 2rem;
                border: 1px solid #2c2c2a;
                border-radius: 0.5rem;
                background: #161615;
                text-align: center;
            }
            .code { color: #a1a09a; font-size: 0.875rem; letter-spacing: 0.05em; }
            h1 { margin: 0.5rem 0 0.75rem; font-size: 1.25rem; }
            p { margin: 0; color: #a1a09a; font-size: 0.9rem; }
            a { display: inline-block; margin-top: 1.5rem; color: #639922; text-decoration: none; font-weight: 500; }
            a:hover { color: #75b428; }
        </style>
    </head>
    <body>
        <div class="card">
            <p class="code">401</p>
            <h1>Perlu Masuk</h1>
            <p>Anda harus masuk terlebih dahulu untuk membuka halaman ini.</p>
            <a href="{{ url('/dashboard/login') }}">Ke halaman masuk</a>
        </div>
    </body>
</html>
