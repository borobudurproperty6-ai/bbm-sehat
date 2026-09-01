<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Employee;
use Barryvdh\DomPDF\Facade\Pdf;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Renders the same credential slip the "Password Sementara" modal shows
 * (Tambah Pengguna / Reset Password) as an actual PDF — see
 * resources/views/pdf/credential-slip.blade.php, ported from the frontend's
 * PrintableSlip.jsx layout.
 *
 * The password itself is never stored in plaintext anywhere (only its
 * bcrypt hash) or re-derivable from the database, so it must be passed in
 * by the caller — this only ever makes sense as the very next request
 * after the dashboard just displayed that exact string to the same
 * SUPER_ADMIN who generated it a moment ago (route access is identical to
 * every other "Pengaturan Pengguna" endpoint — see routes/api.php).
 */
class CredentialSlipController extends Controller
{
    public function generate(Request $request, Employee $employee): Response
    {
        $validated = $request->validate([
            'password' => ['required', 'string', 'max:100'],
        ]);

        $pdf = Pdf::loadView('pdf.credential-slip', [
            'employeeName' => $employee->full_name,
            'employeeCode' => $employee->employee_code,
            'password' => $validated['password'],
            // Explicit 'id' locale rather than relying on config('app.locale')
            // (which defaults to 'en') — every other date in this UI is
            // already Indonesian (see PrintableSlip.jsx's toLocaleDateString).
            'printedAt' => now()->locale('id')->translatedFormat('d F Y'),
        ]);

        $filename = 'slip-kredensial-'.$employee->employee_code.'.pdf';

        return $pdf->download($filename);
    }
}
