<?php

namespace App\Console\Commands;

use App\Enums\AccountStatus;
use App\Models\Division;
use App\Models\Employee;
use App\Models\Role;
use App\Support\TemporaryPasswordGenerator;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\File;
use PhpOffice\PhpSpreadsheet\IOFactory;

/**
 * Imports the real PT BBM employee roster from an .xlsx file.
 *
 * Column order (A-G), no sample row — real data starts on row 2:
 *   Nama Lengkap | Email | No Telepon | Kode Divisi | Kode Karyawan/NIP | Peran | Jabatan
 *
 * Reads via phpoffice/phpspreadsheet directly rather than the
 * maatwebsite/excel wrapper — that wrapper's latest release still pins an
 * old phpspreadsheet version capped below PHP 8.5, which is what this
 * project runs; phpspreadsheet itself has no such cap.
 */
class ImportEmployees extends Command
{
    protected $signature = 'employees:import {path : Path to the .xlsx file}';

    protected $description = 'Import the real PT BBM employee roster from an .xlsx file';

    private const COL_NAME = 0;
    private const COL_EMAIL = 1;
    private const COL_PHONE = 2;
    private const COL_DIVISION_CODE = 3;
    private const COL_EMPLOYEE_CODE = 4;
    private const COL_ROLE_CODE = 5;
    private const COL_POSITION_TITLE = 6;

    public function handle(): int
    {
        $path = $this->argument('path');

        if (! File::exists($path)) {
            $this->error("File tidak ditemukan: {$path}");

            return self::FAILURE;
        }

        $rows = IOFactory::load($path)->getActiveSheet()->toArray(null, true, true, false);
        array_shift($rows); // drop the header row — data starts at row 2.

        $divisionsByCode = Division::query()->pluck('id', 'code');
        $rolesByCode = Role::query()->pluck('id', 'code');
        $employeeRoleId = $rolesByCode->get('EMPLOYEE');

        $imported = [];
        $skipped = [];
        $rowNumber = 1; // header was row 1.

        foreach ($rows as $row) {
            $rowNumber++;

            $fullName = trim((string) ($row[self::COL_NAME] ?? ''));
            $email = trim((string) ($row[self::COL_EMAIL] ?? ''));
            $phone = trim((string) ($row[self::COL_PHONE] ?? '')) ?: null;
            $divisionCode = strtoupper(trim((string) ($row[self::COL_DIVISION_CODE] ?? '')));
            $employeeCode = trim((string) ($row[self::COL_EMPLOYEE_CODE] ?? '')) ?: null;
            $roleCode = strtoupper(trim((string) ($row[self::COL_ROLE_CODE] ?? '')));
            $positionTitle = trim((string) ($row[self::COL_POSITION_TITLE] ?? '')) ?: null;

            if ($fullName === '' && $email === '' && $divisionCode === '') {
                continue; // fully blank row — not worth reporting as skipped.
            }

            if ($fullName === '' || $email === '' || $divisionCode === '') {
                $skipped[] = [$rowNumber, $fullName ?: '(tanpa nama)', 'Nama Lengkap, Email, atau Kode Divisi kosong'];

                continue;
            }

            $divisionId = $divisionsByCode->get($divisionCode);
            if (! $divisionId) {
                $skipped[] = [$rowNumber, $fullName, "Kode Divisi tidak ditemukan: {$divisionCode}"];

                continue;
            }

            if ($roleCode === '') {
                $roleId = $employeeRoleId;
            } else {
                $roleId = $rolesByCode->get($roleCode);
                if (! $roleId) {
                    $skipped[] = [$rowNumber, $fullName, "Kode Peran tidak ditemukan: {$roleCode}"];

                    continue;
                }
            }

            $duplicate = Employee::query()
                ->where('email', $email)
                ->when($employeeCode, fn ($q) => $q->orWhere('employee_code', $employeeCode))
                ->exists();

            if ($duplicate) {
                $skipped[] = [$rowNumber, $fullName, 'Sudah ada (email atau kode karyawan duplikat)'];

                continue;
            }

            $temporaryPassword = TemporaryPasswordGenerator::generate();

            $isManagement = in_array($divisionCode, ['DIREKTUR', 'KOMISARIS'], true) || $roleCode === 'MANAGEMENT';

            try {
                Employee::create([
                    'employee_code' => $employeeCode,
                    'full_name' => $fullName,
                    'email' => $email,
                    'phone' => $phone,
                    'division_id' => $divisionId,
                    'role_id' => $roleId,
                    'position_title' => $positionTitle,
                    'is_management' => $isManagement,
                    'account_status' => AccountStatus::Active,
                    'password' => $temporaryPassword,
                    'must_change_password' => true,
                ]);
            } catch (\Throwable $e) {
                $skipped[] = [$rowNumber, $fullName, 'Gagal disimpan: '.$e->getMessage()];

                continue;
            }

            $imported[] = [$fullName, $email, $temporaryPassword];
        }

        $this->writePasswordCsv($imported);

        $this->newLine();
        $this->info('Berhasil diimpor: '.count($imported));
        $this->warn('Dilewati: '.count($skipped));

        if ($skipped) {
            $this->table(['Baris', 'Nama', 'Alasan'], $skipped);
        }

        if ($imported) {
            $this->newLine();
            $this->comment(
                'PENTING: email di atas adalah placeholder (@bbm-sehat.local), bukan email asli '.
                'karyawan — ganti dengan email asli sebelum fitur lupa-password bisa dipakai '.
                'sungguhan. Password sementara tiap karyawan ada di file CSV yang baru ditulis, '.
                'tidak ditampilkan di sini.'
            );
        }

        return self::SUCCESS;
    }

    /**
     * @param  array<int, array{0: string, 1: string, 2: string}>  $imported
     */
    private function writePasswordCsv(array $imported): void
    {
        if (! $imported) {
            return;
        }

        $dir = storage_path('app/import');
        File::ensureDirectoryExists($dir);

        $filePath = $dir.'/hasil_password_sementara_'.now()->format('Y-m-d_His').'.csv';

        $handle = fopen($filePath, 'w');
        fputcsv($handle, ['full_name', 'email', 'temporary_password']);
        foreach ($imported as $row) {
            fputcsv($handle, $row);
        }
        fclose($handle);

        $this->info('Password sementara disimpan di: '.$filePath);
    }
}
