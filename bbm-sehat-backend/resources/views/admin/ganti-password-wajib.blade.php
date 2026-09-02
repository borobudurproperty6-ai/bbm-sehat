<!DOCTYPE html>
<html lang="id">
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Ganti Kata Sandi — BBM Sehat Dashboard</title>
        @vite(['resources/css/admin.css', 'resources/js/admin/main.jsx'])
    </head>
    <body>
        <div
            id="admin-root"
            data-page="ganti-password-wajib"
            data-employee='@json($employee)'
            data-redirect-to="{{ $redirectTo }}"
        ></div>
    </body>
</html>
