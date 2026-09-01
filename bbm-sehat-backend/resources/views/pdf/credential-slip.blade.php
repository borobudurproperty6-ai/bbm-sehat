<!DOCTYPE html>
<html lang="id">
    <head>
        <meta charset="utf-8">
        <title>Slip Kredensial — {{ $employeeName }}</title>
        <style>
            body {
                font-family: 'Helvetica', sans-serif;
                color: #111827;
                font-size: 12px;
                padding: 24px;
            }
            h1 {
                font-size: 20px;
                font-weight: bold;
                margin: 0;
            }
            .subtitle {
                margin: 2px 0 28px;
                font-size: 13px;
            }
            table {
                width: 100%;
                border-collapse: collapse;
                margin-bottom: 28px;
            }
            td {
                padding: 5px 0;
                vertical-align: top;
            }
            td.label {
                width: 160px;
                color: #4b5563;
            }
            td.value {
                font-weight: bold;
            }
            td.value.password {
                font-family: 'Courier New', monospace;
                font-size: 15px;
            }
            .instructions-title {
                font-weight: bold;
                margin-bottom: 6px;
            }
            ol {
                margin: 0 0 28px;
                padding-left: 20px;
            }
            ol li {
                margin-bottom: 4px;
            }
            .footer {
                font-size: 10px;
                color: #6b7280;
            }
        </style>
    </head>
    <body>
        <h1>PT BBM</h1>
        <p class="subtitle">Slip Kredensial Akun — BBM Sehat</p>

        <table>
            <tr>
                <td class="label">Nama Karyawan</td>
                <td class="value">: {{ $employeeName }}</td>
            </tr>
            <tr>
                <td class="label">ID Karyawan</td>
                <td class="value">: {{ $employeeCode }}</td>
            </tr>
            <tr>
                <td class="label">Password Sementara</td>
                <td class="value password">: {{ $password }}</td>
            </tr>
            <tr>
                <td class="label">Tanggal Cetak</td>
                <td class="value">: {{ $printedAt }}</td>
            </tr>
        </table>

        <p class="instructions-title">Cara masuk pertama kali:</p>
        <ol>
            <li>Buka aplikasi BBM Sehat di ponsel Anda.</li>
            <li>Masuk menggunakan ID Karyawan dan password sementara di atas.</li>
            <li>
                Anda akan diminta membuat password baru saat itu juga — password sementara ini hanya berlaku untuk
                login pertama.
            </li>
        </ol>

        <p class="footer">
            Dokumen ini bersifat rahasia. Simpan dengan aman atau musnahkan setelah password berhasil diganti.
        </p>
    </body>
</html>
